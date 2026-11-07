<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use App\Models\Depot;
use App\Models\InventoryAccount;
use App\Models\Order;
use App\Models\Trip;
use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class DeliveryResultService
{
    public function record(int $courier, int $tripId, int $stopId, array $data): array
    {
        return DB::transaction(function () use ($courier, $tripId, $stopId, $data) {
            Depot::lockForUpdate()->findOrFail(1);
            $trip = Trip::where('courier_id', $courier)->where('depot_id', 1)->findOrFail($tripId);
            $actor = User::lockForUpdate()->findOrFail($courier);
            Vehicle::lockForUpdate()->findOrFail($trip->vehicle_id);
            abort_unless($actor->role === 'courier' && $actor->is_active, 403);
            $stop = DB::table('trip_stops')->where('trip_id', $tripId)->where('route_version_id', $trip->selected_route_version_id)->find($stopId);
            abort_unless($stop, 404);
            $order = Order::with('items')->findOrFail($stop->order_id);
            $accounts = InventoryAccount::where('depot_id', 1)->where('owner_key', 'trip:'.$tripId)->whereIn('product_id', $order->items->pluck('product_id'))->orderBy('id')->lockForUpdate()->get();
            $order = Order::with('items')->lockForUpdate()->findOrFail($stop->order_id);
            $trip = Trip::lockForUpdate()->findOrFail($tripId);
            if ($trip->lock_version !== $data['trip_version'] || $order->lock_version !== $data['order_version']) {
                throw new BusinessFailure('STALE_VERSION', 'Trip atau pesanan berubah. Perbarui tugas sebelum mencatat hasil.');
            }
            if ($trip->status !== 'in_progress' || ! $trip->actual_departure_at || $order->status !== 'out_for_delivery' || $stop->status !== 'pending' || DB::table('delivery_results')->where('order_id', $order->id)->exists()) {
                throw new BusinessFailure('RESULT_LOCKED', 'Hasil sudah tercatat atau tujuan tidak dapat diproses.');
            }
            $next = DB::table('trip_stops')->where('trip_id', $tripId)->where('route_version_id', $trip->selected_route_version_id)->where('status', 'pending')->orderBy('sequence_no')->value('id');
            if ((int) $next !== $stopId) {
                throw new BusinessFailure('STOP_OUT_OF_SEQUENCE', 'Selesaikan tujuan sebelumnya sesuai urutan trip.');
            }
            if (! DB::table('active_order_allocations')->where('order_id', $order->id)->where('trip_id', $tripId)->where('trip_stop_id', $stopId)->exists()
                || ! DB::table('courier_trip_locks')->where('courier_id', $courier)->where('trip_id', $tripId)->exists()
                || ! DB::table('vehicle_trip_locks')->where('vehicle_id', $trip->vehicle_id)->where('trip_id', $tripId)->exists()) {
                throw new BusinessFailure('ALLOCATION_CONFLICT', 'Alokasi trip tidak lengkap. Hubungi admin.');
            }
            $delivered = $data['outcome'] === 'delivered';
            if (($delivered && $data['cash_received_rp'] !== $order->total_rp) || (! $delivered && $data['cash_received_rp'] !== 0)) {
                throw new BusinessFailure('COD_MISMATCH', 'COD harus sesuai seluruh tagihan untuk kiriman berhasil dan nol untuk kiriman gagal.');
            }
            $upload = null;
            if ($data['proof_upload_id']) {
                $upload = DB::table('delivery_proof_uploads')->where('id', $data['proof_upload_id'])->where('uploaded_by', $courier)->where('trip_stop_id', $stopId)->lockForUpdate()->first();
                if (! $upload || $upload->status !== 'pending' || $upload->expires_at <= now()->format('Y-m-d H:i:s') || ! Storage::disk('local')->exists($upload->storage_key)) {
                    throw new BusinessFailure('PROOF_UNAVAILABLE', 'Foto belum tersedia atau kedaluwarsa. Unggah kembali sebelum mencatat hasil.');
                }
            }
            if ($delivered && ! $upload) {
                throw new BusinessFailure('PROOF_REQUIRED', 'Foto bukti wajib untuk kiriman berhasil.');
            }
            if (! $delivered && ! filled($data['failure_reason'])) {
                throw new BusinessFailure('FAILURE_REASON_REQUIRED', 'Alasan gagal wajib diisi.');
            }
            if ($order->items->isEmpty()) {
                throw new BusinessFailure('STOCK_CONFLICT', 'Pesanan tidak memiliki barang. Hubungi admin.');
            }
            foreach ($order->items as $item) {
                $account = $accounts->first(fn ($account) => $account->stock_state === 'available' && (int) $account->product_id === (int) $item->product_id);
                if (! $account || (int) $account->trip_id !== $tripId || $account->balance_quantity < $item->quantity) {
                    throw new BusinessFailure('STOCK_CONFLICT', 'Muatan trip tidak mencukupi. Hubungi admin sebelum mencatat hasil.');
                }
            }
            $now = now();
            $resultId = DB::table('delivery_results')->insertGetId(['trip_stop_id' => $stopId, 'order_id' => $order->id, 'recorded_by' => $courier, 'outcome' => $data['outcome'], 'failure_reason' => $delivered ? null : $data['failure_reason'], 'notes' => $data['notes'], 'occurred_at' => $now, 'recorded_at' => $now]);
            $transaction = $delivered ? DB::table('inventory_transactions')->insertGetId(['trip_id' => $tripId, 'order_id' => $order->id, 'event_key' => 'delivery:'.$order->id, 'kind' => 'delivery', 'reason' => 'Seluruh barang diserahkan kepada penerima', 'created_by' => $courier, 'occurred_at' => $now, 'created_at' => $now, 'updated_at' => $now]) : null;
            foreach ($order->items as $item) {
                DB::table('delivery_result_items')->insert(['delivery_result_id' => $resultId, 'order_item_id' => $item->id, 'delivered_quantity' => $delivered ? $item->quantity : 0]);
                if ($delivered) {
                    $account = $accounts->first(fn ($account) => $account->stock_state === 'available' && (int) $account->product_id === (int) $item->product_id);
                    DB::table('inventory_entries')->insert(['inventory_transaction_id' => $transaction, 'inventory_account_id' => $account->id, 'quantity_delta' => -$item->quantity, 'created_at' => $now, 'updated_at' => $now]);
                    $account->balance_quantity -= $item->quantity;
                    $account->lock_version++;
                    $account->save();
                }
            }
            if ($upload) {
                DB::table('delivery_proofs')->insert(['delivery_result_id' => $resultId, 'upload_id' => $upload->id, 'storage_key' => $upload->storage_key, 'mime_type' => $upload->mime_type, 'file_size_bytes' => $upload->file_size_bytes, 'checksum_sha256' => $upload->checksum_sha256, 'uploaded_by' => $courier]);
                DB::table('delivery_proof_uploads')->where('id', $upload->id)->update(['status' => 'attached', 'updated_at' => $now]);
            }
            if ($delivered) {
                DB::table('payment_collections')->insert(['delivery_result_id' => $resultId, 'collected_by' => $courier, 'amount_rp' => $order->total_rp, 'method' => 'cash', 'collected_at' => $now]);
            }
            $order->status = $data['outcome'];
            $order->payment_status = $delivered ? 'paid' : 'unpaid';
            $order->status_reason = $delivered ? null : $data['failure_reason'];
            $order->closed_at = $now;
            $order->lock_version++;
            $order->save();
            DB::table('trip_stops')->where('id', $stopId)->update(['status' => $data['outcome'], 'updated_at' => $now]);
            if (! DB::table('trip_stops')->where('trip_id', $tripId)->where('route_version_id', $trip->selected_route_version_id)->where('status', 'pending')->exists()) {
                $trip->status = 'awaiting_reconciliation';
            }
            $trip->lock_version++;
            $trip->save();
            DB::table('trip_events')->insert(['trip_id' => $tripId, 'actor_id' => $courier, 'action' => 'delivery_'.$data['outcome'], 'trip_version' => $trip->lock_version, 'reason' => $delivered ? 'COD diterima sesuai tagihan' : $data['failure_reason'], 'created_at' => $now]);

            return ['status' => 200, 'body' => ['data' => ['id' => (string) $resultId, 'order_id' => (string) $order->id, 'outcome' => $data['outcome'], 'trip_status' => $trip->status, 'trip_version' => $trip->lock_version, 'order_version' => $order->lock_version]]];
        });
    }
}
