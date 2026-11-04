<?php

namespace App\Http\Controllers;

use App\Models\DeliverySlot;
use App\Models\Depot;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;

class DepotController extends Controller
{
    public function edit()
    {
        $depot = Depot::findOrFail(1);

        return Inertia::render('Admin/Depot', ['depot' => $depot, 'configured' => $depot->configured(), 'timezoneLocked' => DeliverySlot::where('depot_id', 1)->exists()]);
    }

    public function update(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:160'], 'address_text' => ['required', 'string', 'max:2000'],
            'latitude' => ['required', 'numeric', 'between:-90,90'], 'longitude' => ['required', 'numeric', 'between:-180,180'],
            'timezone' => ['required', Rule::in(['Asia/Jakarta', 'Asia/Makassar', 'Asia/Jayapura'])],
            'service_radius_m' => ['required', 'integer', 'min:1', 'max:200000'],
            'delivery_fee_rp' => ['required', 'integer', 'min:0', 'max:1000000000'],
            'pending_ttl_minutes' => ['required', 'integer', 'min:1', 'max:1440'],
            'default_service_seconds' => ['required', 'integer', 'min:1', 'max:7200'],
            'lock_version' => ['required', 'integer', 'min:0'],
        ]);

        return DB::transaction(function () use ($data, $request) {
            $depot = Depot::lockForUpdate()->findOrFail(1);
            if ($depot->lock_version !== (int) $data['lock_version']) {
                return Inertia::render('Admin/Conflict', ['message' => 'Konfigurasi depot telah berubah. Muat versi terbaru sebelum menyimpan kembali.', 'reloadUrl' => route('admin.depot.edit')])->toResponse($request)->setStatusCode(409);
            }
            if ($data['timezone'] !== $depot->timezone && DeliverySlot::where('depot_id', 1)->exists()) {
                throw ValidationException::withMessages(['timezone' => 'Zona waktu tidak dapat diubah setelah slot dibuat.']);
            }
            $data['latitude'] = round((float) $data['latitude'], 7);
            $data['longitude'] = round((float) $data['longitude'], 7);
            unset($data['lock_version']);
            $depot->fill($data);
            $depot->lock_version++;
            $depot->save();

            return redirect()->route('admin.depot.edit')->with('status', 'Konfigurasi depot disimpan. Alamat lama akan diperiksa terhadap radius terbaru.');
        });
    }
}
