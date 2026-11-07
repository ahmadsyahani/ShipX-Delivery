<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use App\Models\Depot;
use App\Models\InventoryAccount;
use App\Models\Order;
use App\Models\StockReservation;
use App\Models\Trip;
use App\Models\TripDepartureReview;
use App\Models\User;
use App\Models\Vehicle;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;

class TripDepartureService
{
    public function start(int $courierId, int $id, array $data): array
    {
        return DB::transaction(function () use ($courierId, $id, $data) {
            $depot = Depot::lockForUpdate()->findOrFail(1);
            $trip = Trip::where('depot_id', 1)->where('courier_id', $courierId)->whereIn('status', ['assigned', 'in_progress'])->findOrFail($id);
            $courier = User::lockForUpdate()->findOrFail($courierId);
            $vehicle = Vehicle::lockForUpdate()->findOrFail($trip->vehicle_id);
            $snapshot = $trip->selectedRoute->input_snapshot;
            $versions = app(TripDepartureReviewService::class)->assertMasters($snapshot, $depot, $courier, $vehicle);
            $expected = app(TripManifestService::class)->forTrip($trip);
            $manifest = array_map(fn ($row) => ['product_id' => (int) $row['product_id'], 'quantity' => $row['quantity']], $expected);
            if ($manifest !== $data['manifest']) {
                throw new BusinessFailure('LOAD_MISMATCH', 'Jumlah fisik setiap SKU harus sama dengan manifest. Periksa ulang; jika berbeda, hubungi admin sebelum berangkat.');
            }

            // Create empty trip accounts inside this transaction, then lock all
            // account IDs ascending before orders and trip. Failure rolls back all.
            foreach ($manifest as $row) {
                foreach (['available', 'quarantine'] as $state) {
                    InventoryAccount::firstOrCreate(['depot_id' => 1, 'owner_key' => 'trip:'.$id, 'product_id' => $row['product_id'], 'stock_state' => $state], ['trip_id' => $id, 'balance_quantity' => 0]);
                }
            }
            $accounts = InventoryAccount::where('depot_id', 1)->whereIn('owner_key', ['depot', 'trip:'.$id])->whereIn('product_id', array_column($manifest, 'product_id'))->orderBy('id')->lockForUpdate()->get();
            $orders = Order::with('items')->where('depot_id', 1)->whereIn('id', array_column($snapshot['plan']['orders'], 'id'))->orderBy('id')->lockForUpdate()->get()->keyBy('id');
            $trip = Trip::lockForUpdate()->findOrFail($id);
            if ($trip->lock_version !== $data['lock_version'] || (int) $trip->selected_route_version_id !== $data['route_version_id']) {
                throw new BusinessFailure('STALE_VERSION', 'Rencana atau tinjauan berubah. Muat ulang manifest sebelum mulai.');
            }
            if ($trip->status !== 'assigned' || $trip->actual_departure_at !== null || DB::table('trip_load_confirmations')->where('trip_id', $id)->exists()) {
                throw new BusinessFailure('TRIP_ALREADY_STARTED', 'Trip sudah berangkat atau tidak dapat dimulai.');
            }
            $now = CarbonImmutable::instance(now());
            if ($now < $trip->planned_departure_at) {
                throw new BusinessFailure('DEPARTURE_NOT_DUE', 'Belum waktunya berangkat. Tunggu rencana keberangkatan atau minta admin mengubah rencana.');
            }
            $review = TripDepartureReview::where('trip_id', $id)->where('route_version_id', $trip->selected_route_version_id)->where('trip_version', $trip->lock_version)->find($data['departure_review_id']);
            if (! $review || $review->source !== 'manual_road_estimate' || $review->master_versions != $versions || $review->expires_at <= $now) {
                throw new BusinessFailure('DEPARTURE_NOT_REVIEWED', 'Admin perlu meninjau estimasi jalan untuk rencana ini. Tinjauan berlaku 24 jam.');
            }
            $schedule = app(TripScheduleService::class)->evaluate($snapshot, $review->leg_seconds, $now);
            $allocations = DB::table('active_order_allocations')->where('trip_id', $id)->get()->keyBy('order_id');
            $stops = DB::table('trip_stops')->where('trip_id', $id)->where('route_version_id', $trip->selected_route_version_id)->where('status', 'pending')->orderBy('sequence_no')->get()->keyBy('order_id');
            if ($orders->count() !== count($snapshot['plan']['orders']) || $allocations->count() !== $orders->count() || $stops->count() !== $orders->count() || ! DB::table('courier_trip_locks')->where('courier_id', $courierId)->where('trip_id', $id)->exists() || ! DB::table('vehicle_trip_locks')->where('vehicle_id', $trip->vehicle_id)->where('trip_id', $id)->exists()) {
                throw new BusinessFailure('ALLOCATION_CONFLICT', 'Alokasi pesanan atau armada tidak lengkap. Hubungi admin.');
            }
            $reservations = StockReservation::whereIn('order_item_id', $orders->flatMap(fn ($o) => $o->items->pluck('id')))->lockForUpdate()->get()->keyBy('order_item_id');
            $actualManifest = [];
            $weight = 0;
            $volume = 0;
            foreach ($snapshot['plan']['orders'] as $index => $candidate) {
                $o = $orders[$candidate['id']];
                $claim = $allocations->get($o->id);
                $stop = $stops->get($o->id);
                if ($o->status !== 'assigned' || $o->lock_version !== (int) $candidate['lock_version'] + 1 || ! $claim || ! $stop || (int) $claim->trip_stop_id !== (int) $stop->id || (int) $stop->sequence_no !== $index + 1 || $o->items->isEmpty()) {
                    throw new BusinessFailure('ORDER_CHANGED', 'Pesanan atau urutan tujuan berubah. Hubungi admin sebelum berangkat.');
                }
                foreach ($o->items as $item) {
                    $r = $reservations->get($item->id);
                    $a = $r ? $accounts->firstWhere('id', $r->inventory_account_id) : null;
                    if (! $r || $r->status !== 'active' || $r->quantity !== $item->quantity || ! $a || $a->owner_key !== 'depot' || $a->trip_id !== null || $a->stock_state !== 'available' || (int) $a->product_id !== (int) $item->product_id) {
                        throw new BusinessFailure('RESERVATION_CONFLICT', 'Reservasi barang tidak sesuai. Muatan belum dipindahkan.');
                    }
                    $actualManifest[$item->product_id] = ($actualManifest[$item->product_id] ?? 0) + $item->quantity;
                    $weight += $item->quantity * $item->unit_weight_g;
                    $volume += $item->quantity * $item->unit_volume_cm3;
                }
            }
            if ($weight !== $trip->planned_weight_g || $volume !== $trip->planned_volume_cm3 || $weight > $trip->capacity_weight_g_snapshot || $volume > $trip->capacity_volume_cm3_snapshot || $weight > $vehicle->max_load_weight_g || $volume > $vehicle->max_load_volume_cm3) {
                throw new BusinessFailure('CAPACITY_CONFLICT', 'Berat/volume muatan tidak sesuai rencana atau melebihi kapasitas.');
            }
            foreach ($manifest as $row) {
                if (($actualManifest[$row['product_id']] ?? null) !== $row['quantity']) {
                    throw new BusinessFailure('LOAD_MISMATCH', 'Manifest tidak sesuai barang pesanan.');
                }
                $from = $accounts->first(fn ($a) => $a->owner_key === 'depot' && $a->stock_state === 'available' && (int) $a->product_id === $row['product_id']);
                $to = $accounts->first(fn ($a) => $a->owner_key === 'trip:'.$id && $a->stock_state === 'available' && (int) $a->product_id === $row['product_id']);
                $reserved = $from ? (int) StockReservation::where('inventory_account_id', $from->id)->where('status', 'active')->sum('quantity') : 0;
                if (! $from || ! $to || (int) $to->trip_id !== $id || $from->balance_quantity < $reserved || $from->balance_quantity < $row['quantity'] || $accounts->where('owner_key', 'trip:'.$id)->contains(fn ($a) => $a->balance_quantity !== 0 || (int) $a->trip_id !== $id)) {
                    throw new BusinessFailure('STOCK_CONFLICT', 'Saldo depot atau stok trip tidak sesuai. Tidak ada stok yang dipindahkan.');
                }
            }
            $transaction = DB::table('inventory_transactions')->insertGetId(['trip_id' => $id, 'event_key' => 'trip-load:'.$id, 'kind' => 'load', 'reason' => 'Konfirmasi muatan dan keberangkatan oleh kurir', 'created_by' => $courierId, 'occurred_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
            foreach ($manifest as $row) {
                foreach (['depot' => -1, 'trip:'.$id => 1] as $owner => $sign) {
                    $a = $accounts->first(fn ($a) => $a->owner_key === $owner && $a->stock_state === 'available' && (int) $a->product_id === $row['product_id']);
                    $delta = $sign * $row['quantity'];
                    DB::table('inventory_entries')->insert(['inventory_transaction_id' => $transaction, 'inventory_account_id' => $a->id, 'quantity_delta' => $delta, 'created_at' => $now, 'updated_at' => $now]);
                    $a->balance_quantity += $delta;
                    $a->lock_version++;
                    $a->save();
                }
            }
            StockReservation::whereIn('id', $reservations->pluck('id'))->update(['status' => 'consumed', 'consumed_at' => $now, 'updated_at' => $now]);
            foreach ($orders as $o) {
                $o->status = 'out_for_delivery';
                $o->lock_version++;
                $o->save();
            }
            foreach ($schedule['stops'] as $stop) {
                DB::table('trip_stops')->where('id', $stops[$stop['order_id']]->id)->update(['estimated_arrival_at' => CarbonImmutable::parse($stop['estimated_arrival_at']), 'estimated_service_start_at' => CarbonImmutable::parse($stop['estimated_service_start_at']), 'updated_at' => $now]);
            }
            DB::table('trip_load_confirmations')->insert(['trip_id' => $id, 'courier_id' => $courierId, 'route_version_id' => $trip->selected_route_version_id, 'departure_review_id' => $review->id, 'inventory_transaction_id' => $transaction, 'manifest' => json_encode($expected, JSON_THROW_ON_ERROR), 'departure_schedule' => json_encode($schedule, JSON_THROW_ON_ERROR), 'confirmed_at' => $now]);
            $trip->status = 'in_progress';
            $trip->actual_departure_at = $now;
            $trip->loaded_weight_g = $weight;
            $trip->loaded_volume_cm3 = $volume;
            $trip->lock_version++;
            $trip->save();
            DB::table('trip_events')->insert(['trip_id' => $id, 'actor_id' => $courierId, 'action' => 'started', 'trip_version' => $trip->lock_version, 'reason' => 'Muatan per SKU diperiksa sesuai manifest', 'created_at' => $now]);

            return ['status' => 200, 'body' => ['data' => ['id' => (string) $id, 'status' => 'in_progress', 'lock_version' => $trip->lock_version, 'actual_departure_at' => $now->toISOString()]]];
        });
    }
}
