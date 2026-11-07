<?php

namespace App\Http\Controllers;

use App\Models\Depot;
use App\Models\Trip;
use Carbon\CarbonImmutable;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class DeliveryProofController extends Controller
{
    public function store(Request $request, string $id, string $stop)
    {
        $key = strtolower(Validator::make(['key' => $request->header('Idempotency-Key')], ['key' => ['required', 'uuid']])->validate()['key']);
        $request->validate(['photo' => ['required', 'file', 'image', 'mimes:jpg,jpeg,png', 'max:2048', 'dimensions:max_width=4096,max_height=4096']]);
        $trip = Trip::where('courier_id', $request->user()->id)->findOrFail($id);
        $target = DB::table('trip_stops')->where('trip_id', $trip->id)->where('route_version_id', $trip->selected_route_version_id)->find($stop);
        abort_unless($target, 404);
        $file = $request->file('photo');
        $checksum = hash_file('sha256', $file->getRealPath());
        $existing = DB::table('delivery_proof_uploads')->where('uploaded_by', $request->user()->id)->where('idempotency_key', $key)->first();
        if ($existing) {
            return $this->replay($existing, (int) $stop, $checksum);
        }
        abort_unless($trip->status === 'in_progress' && $target->status === 'pending', 409, 'Tujuan sudah selesai atau trip belum berangkat.');
        $uuid = strtolower(Str::uuid()->toString());
        $extension = $file->getMimeType() === 'image/png' ? 'png' : 'jpg';
        $path = 'delivery-proofs/'.$uuid.'.'.$extension;
        if (! Storage::disk('local')->put($path, fopen($file->getRealPath(), 'rb'))) {
            abort(503, 'Foto belum dapat disimpan. Coba ulang.');
        }
        try {
            $upload = DB::transaction(function () use ($request, $key, $path, $uuid, $file, $checksum, $trip, $stop) {
                Depot::lockForUpdate()->findOrFail(1);
                $fresh = Trip::where('courier_id', $request->user()->id)->findOrFail($trip->id);
                $target = DB::table('trip_stops')->where('trip_id', $fresh->id)->where('route_version_id', $fresh->selected_route_version_id)->find($stop);
                abort_unless($fresh->status === 'in_progress' && $target?->status === 'pending', 409, 'Tujuan sudah selesai atau trip berubah.');
                DB::table('delivery_proof_uploads')->insert(['id' => $uuid, 'trip_stop_id' => $stop, 'uploaded_by' => $request->user()->id, 'idempotency_key' => $key, 'storage_key' => $path, 'mime_type' => $file->getMimeType(), 'file_size_bytes' => $file->getSize(), 'checksum_sha256' => $checksum, 'status' => 'pending', 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);

                return DB::table('delivery_proof_uploads')->find($uuid);
            });
        } catch (UniqueConstraintViolationException) {
            Storage::disk('local')->delete($path);

            return $this->replay(DB::table('delivery_proof_uploads')->where('uploaded_by', $request->user()->id)->where('idempotency_key', $key)->firstOrFail(), (int) $stop, $checksum);
        } catch (\Throwable $error) {
            Storage::disk('local')->delete($path);
            throw $error;
        }

        return response()->json(['data' => ['id' => $upload->id, 'expires_at' => CarbonImmutable::parse($upload->expires_at, 'UTC')->toISOString()]], 201);
    }

    private function replay(object $upload, int $stop, string $checksum)
    {
        if ((int) $upload->trip_stop_id !== $stop || $upload->checksum_sha256 !== $checksum) {
            return response()->json(['code' => 'IDEMPOTENCY_CONFLICT', 'message' => 'Key unggahan sudah dipakai untuk foto atau tujuan lain.'], 409);
        }
        if ($upload->status === 'expired' || ($upload->status === 'pending' && $upload->expires_at <= now()->format('Y-m-d H:i:s'))) {
            return response()->json(['code' => 'PROOF_EXPIRED', 'message' => 'Unggahan kedaluwarsa. Pilih foto dan unggah kembali.'], 409);
        }

        return response()->json(['data' => ['id' => $upload->id, 'expires_at' => CarbonImmutable::parse($upload->expires_at, 'UTC')->toISOString()]]);
    }

    public function show(Request $request, string $proof)
    {
        $record = DB::table('delivery_proofs')->join('delivery_results', 'delivery_results.id', '=', 'delivery_proofs.delivery_result_id')->join('orders', 'orders.id', '=', 'delivery_results.order_id')->join('trip_stops', 'trip_stops.id', '=', 'delivery_results.trip_stop_id')->join('trips', 'trips.id', '=', 'trip_stops.trip_id')->where('delivery_proofs.id', $proof)->select('delivery_proofs.*', 'orders.customer_id', 'trips.courier_id')->first();
        $user = $request->user();
        abort_unless($record && ($user->role === 'admin' || ($user->role === 'customer' && (int) $record->customer_id === $user->id) || ($user->role === 'courier' && (int) $record->courier_id === $user->id)), 404);
        abort_unless(Storage::disk('local')->exists($record->storage_key), 404);

        return Storage::disk('local')->response($record->storage_key, 'bukti-'.$proof.($record->mime_type === 'image/png' ? '.png' : '.jpg'), ['Content-Type' => $record->mime_type, 'Cache-Control' => 'private, no-store', 'X-Content-Type-Options' => 'nosniff']);
    }
}
