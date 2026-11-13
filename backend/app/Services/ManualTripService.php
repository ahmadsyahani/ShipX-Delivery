<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use App\Http\Resources\OrderResource;
use App\Models\Depot;
use App\Models\InventoryAccount;
use App\Models\Order;
use App\Models\RouteVersion;
use App\Models\StockReservation;
use App\Models\Trip;
use App\Models\User;
use App\Models\Vehicle;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class ManualTripService
{
    // The depot mutex is also used by checkout, cancellation and stock decisions.
    // No road API, dispatch, reservation consumption or inventory movement here.
    public function save(int $actor, array $plan, ?int $id = null, ?array $optimization = null): array
    {
        return DB::transaction(function () use ($actor, $plan, $id, $optimization) {
            $depot = Depot::lockForUpdate()->findOrFail(1);
            $snapshot = $this->validatePlan($depot, $plan);
            $trip = $id ? Trip::where('depot_id', 1)->lockForUpdate()->findOrFail($id) : new Trip;
            if ($id) {
                $this->guard($trip, $plan['lock_version'], ['draft']);
            }
            $vehicle = $snapshot['vehicle'];
            $trip->fill([
                'depot_id' => 1, 'courier_id' => $plan['courier_id'], 'vehicle_id' => $plan['vehicle_id'],
                'planned_departure_at' => $snapshot['departure_at'], 'timezone_snapshot' => $depot->timezone,
                'capacity_weight_g_snapshot' => $vehicle['max_load_weight_g'], 'capacity_volume_cm3_snapshot' => $vehicle['max_load_volume_cm3'],
                'planned_weight_g' => array_sum(array_column($snapshot['orders'], 'total_weight_g')),
                'planned_volume_cm3' => array_sum(array_column($snapshot['orders'], 'total_volume_cm3')),
            ]);
            if (! $id) {
                $trip->trip_number = 'TR-'.now()->format('Ymd').'-'.Str::ulid();
                $trip->created_by = $actor;
                $trip->status = 'draft';
            } else {
                $trip->lock_version++;
            }
            $trip->save();
            if ($optimization !== null) {
                $snapshot['optimization'] = $optimization;
            }
            $this->appendRoute($trip, $actor, $snapshot);
            $this->event($trip, $actor, $id ? 'updated' : 'created');

            return $this->response($trip->refresh());
        });
    }

    public function prepareOptimization(int $id, int $version): array
    {
        $depot = Depot::lockForUpdate()->findOrFail(1);
        $trip = Trip::where('depot_id', 1)->findOrFail($id);
        $snapshot = $this->validatePlan($depot, $trip->selectedRoute->input_snapshot['plan']);
        $trip = Trip::lockForUpdate()->findOrFail($id);
        $this->guard($trip, $version, ['draft']);

        return [$trip, $snapshot];
    }

    private function validatePlan(Depot $depot, array $plan): array
    {
        if (! $depot->configured()) {
            $this->fail('DEPOT_NOT_CONFIGURED', 'Lengkapi pengaturan depot terlebih dahulu.');
        }
        $courier = User::where('role', 'courier')->where('is_active', true)->lockForUpdate()->find($plan['courier_id']);
        $vehicle = Vehicle::where('depot_id', 1)->where('is_active', true)->lockForUpdate()->find($plan['vehicle_id']);
        if (! $courier || ! $vehicle) {
            $this->fail('FLEET_UNAVAILABLE', 'Kurir atau kendaraan tidak tersedia/aktif.');
        }
        if (DB::table('courier_trip_locks')->where('courier_id', $courier->id)->exists() || DB::table('vehicle_trip_locks')->where('vehicle_id', $vehicle->id)->exists()) {
            $this->fail('FLEET_BUSY', 'Kurir atau kendaraan sudah ditugaskan. Buka ulang trip sebelumnya atau pilih armada lain.');
        }
        $ids = array_column($plan['orders'], 'id');
        $accountIds = DB::table('stock_reservations')->join('order_items', 'order_items.id', '=', 'stock_reservations.order_item_id')->whereIn('order_items.order_id', $ids)->pluck('inventory_account_id');
        $accounts = InventoryAccount::whereIn('id', $accountIds)->orderBy('id')->lockForUpdate()->get()->keyBy('id');
        $orders = Order::with('items')->where('depot_id', 1)->whereIn('id', $ids)->orderBy('id')->lockForUpdate()->get()->keyBy('id');
        if ($orders->count() !== count($ids) || count(array_unique($ids)) !== count($ids) || count($ids) < 1 || count($ids) > 20) {
            $this->fail('INVALID_ORDERS', 'Pilih 1–20 pesanan berbeda dari depot ini.');
        }
        $departure = CarbonImmutable::createFromFormat('!Y-m-d\TH:i', $plan['departure_local'], $depot->timezone)->utc();
        // Evaluated after waiting on locks, rather than at request arrival.
        if ($departure <= now() || $departure >= $orders->min('window_end_at')) {
            $this->fail('INVALID_DEPARTURE', 'Keberangkatan harus di masa depan dan sebelum akhir jendela layanan.');
        }
        if ($orders->pluck('delivery_slot_id')->unique()->count() !== 1) {
            $this->fail('DIFFERENT_WAVES', 'Semua pesanan harus berasal dari gelombang/slot yang sama.');
        }
        foreach ($plan['orders'] as $candidate) {
            $order = $orders[$candidate['id']];
            if ($order->status !== 'confirmed' || $order->lock_version !== (int) $candidate['lock_version'] || DB::table('active_order_allocations')->where('order_id', $order->id)->exists()) {
                $this->fail('ORDER_CHANGED', 'Pesanan telah berubah atau sudah ditugaskan. Muat ulang dan tinjau pilihan.');
            }
            $reservations = StockReservation::whereIn('order_item_id', $order->items->pluck('id'))->get()->keyBy('order_item_id');
            if ($order->items->isEmpty()) {
                $this->fail('RESERVATION_CONFLICT', 'Pesanan tidak memiliki barang.');
            }
            foreach ($order->items as $item) {
                $r = $reservations->get($item->id);
                $a = $r ? $accounts->get($r->inventory_account_id) : null;
                if (! $r || $r->status !== 'active' || $r->quantity !== $item->quantity || ! $a || (int) $a->product_id !== (int) $item->product_id || (int) $a->depot_id !== 1 || $a->owner_key !== 'depot' || $a->stock_state !== 'available' || $a->balance_quantity < (int) StockReservation::where('inventory_account_id', $a->id)->where('status', 'active')->sum('quantity')) {
                    $this->fail('RESERVATION_CONFLICT', 'Reservasi atau saldo stok tidak sesuai. Periksa pesanan dan stok.');
                }
            }
        }
        if ($orders->sum('total_weight_g') > $vehicle->max_load_weight_g || $orders->sum('total_volume_cm3') > $vehicle->max_load_volume_cm3) {
            $this->fail('CAPACITY_EXCEEDED', 'Total berat atau volume melebihi kapasitas kendaraan.');
        }

        $date = $orders->first()->window_start_at->setTimezone($depot->timezone)->toDateString();
        [$opens, $closes] = app(DeliveryPolicy::class)->bounds($depot, $date);
        if ($departure < $opens || $departure >= $closes) {
            $this->fail('INVALID_DEPARTURE', 'Keberangkatan harus di dalam jam layanan tanggal tersebut.');
        }

        return [
            'operating_hours' => ['opens_at' => $opens->toISOString(), 'closes_at' => $closes->toISOString()],
            'plan' => array_diff_key($plan, array_flip(['idempotency_key', 'lock_version'])),
            'departure_at' => $departure->toISOString(),
            'depot' => $depot->only(['id', 'name', 'address_text', 'latitude', 'longitude', 'timezone', 'default_service_seconds', 'delivery_prep_minutes', 'lock_version']),
            'courier' => $courier->only(['id', 'name', 'lock_version']),
            'vehicle' => $vehicle->only(['id', 'code', 'name', 'plate_number', 'travel_mode', 'max_load_weight_g', 'max_load_volume_cm3', 'lock_version']),
            'orders' => array_map(fn ($id) => (new OrderResource($orders[$id]))->resolve(), $ids),
        ];
    }

    public function act(int $actor, int $id, int $version, string $action, ?string $reason = null): array
    {
        return DB::transaction(function () use ($actor, $id, $version, $action, $reason) {
            $depot = Depot::lockForUpdate()->findOrFail(1);
            $trip = Trip::where('depot_id', 1)->findOrFail($id);
            if ($action === 'assign') {
                $old = $trip->selectedRoute->input_snapshot;
                $snapshot = $this->validatePlan($depot, $old['plan']);
                $trip = Trip::lockForUpdate()->findOrFail($id);
                $this->guard($trip, $version, ['draft']);
                foreach (['depot', 'courier', 'vehicle'] as $master) {
                    if ($snapshot[$master]['lock_version'] !== $old[$master]['lock_version']) {
                        $this->fail('PLAN_CHANGED', 'Data master berubah. Edit dan tinjau ulang draft sebelum menetapkan.');
                    }
                }
                foreach ($old['plan']['orders'] as $index => $candidate) {
                    $stop = DB::table('trip_stops')->insertGetId(['trip_id' => $id, 'route_version_id' => $trip->selected_route_version_id, 'order_id' => $candidate['id'], 'sequence_no' => $index + 1, 'status' => 'pending', 'planned_service_seconds' => $old['depot']['default_service_seconds'], 'created_at' => now(), 'updated_at' => now()]);
                    DB::table('active_order_allocations')->insert(['order_id' => $candidate['id'], 'trip_id' => $id, 'trip_stop_id' => $stop]);
                    Order::whereKey($candidate['id'])->update(['status' => 'assigned', 'lock_version' => DB::raw('lock_version + 1'), 'updated_at' => now()]);
                }
                DB::table('courier_trip_locks')->insert(['courier_id' => $trip->courier_id, 'trip_id' => $id]);
                DB::table('vehicle_trip_locks')->insert(['vehicle_id' => $trip->vehicle_id, 'trip_id' => $id]);
                $trip->status = 'assigned';
            } else {
                // Same master/order/trip lock order; no inventory changes on release.
                User::whereKey($trip->courier_id)->lockForUpdate()->firstOrFail();
                Vehicle::whereKey($trip->vehicle_id)->lockForUpdate()->firstOrFail();
                $allocated = DB::table('active_order_allocations')->where('trip_id', $id)->orderBy('order_id')->pluck('order_id');
                $orders = Order::whereIn('id', $allocated)->orderBy('id')->lockForUpdate()->get();
                $trip = Trip::lockForUpdate()->findOrFail($id);
                $this->guard($trip, $version, $action === 'reopen' ? ['assigned'] : ['draft', 'assigned']);
                if ($trip->status === 'assigned' && $orders->count() !== count($trip->selectedRoute->input_snapshot['plan']['orders'])) {
                    $this->fail('ALLOCATION_CONFLICT', 'Alokasi pesanan trip tidak lengkap. Periksa data sebelum melanjutkan.');
                }
                if (! in_array($action, ['reopen', 'cancel'], true) || ! filled($reason)) {
                    $this->fail('INVALID_ACTION', 'Alasan perubahan wajib diisi.');
                }
                foreach ($orders as $order) {
                    if ($order->status !== 'assigned') {
                        $this->fail('ORDER_CHANGED', 'Status pesanan tidak sesuai dengan trip.');
                    }
                    $order->status = 'confirmed';
                    $order->lock_version++;
                    $order->save();
                }
                DB::table('active_order_allocations')->where('trip_id', $id)->delete();
                DB::table('courier_trip_locks')->where('trip_id', $id)->delete();
                DB::table('vehicle_trip_locks')->where('trip_id', $id)->delete();
                DB::table('trip_stops')->where('trip_id', $id)->where('status', 'pending')->update(['status' => 'voided', 'voided_at' => now(), 'void_reason' => $reason, 'updated_at' => now()]);
                $trip->status = $action === 'reopen' ? 'draft' : 'cancelled';
                if ($action === 'reopen') {
                    // Preserve the assigned route and snapshot a new draft for review.
                    $snapshot = $trip->selectedRoute->input_snapshot;
                    foreach ($snapshot['plan']['orders'] as &$candidate) {
                        $candidate['lock_version'] = $orders->firstWhere('id', $candidate['id'])->lock_version;
                    }
                    unset($candidate);
                    $snapshot['orders'] = array_map(fn ($candidate) => (new OrderResource($orders->firstWhere('id', $candidate['id'])->load('items')))->resolve(), $snapshot['plan']['orders']);
                    $this->appendRoute($trip, $actor, $snapshot);
                }
            }
            $trip->lock_version++;
            $trip->save();
            $this->event($trip, $actor, $action, $reason);

            return $this->response($trip);
        });
    }

    private function appendRoute(Trip $trip, int $actor, array $snapshot): void
    {
        $route = RouteVersion::create(['trip_id' => $trip->id, 'version_number' => (int) $trip->routes()->max('version_number') + 1, 'input_snapshot' => $snapshot, 'selected_snapshot' => ['order_ids' => array_column($snapshot['plan']['orders'], 'id')], 'created_by' => $actor]);
        $trip->selected_route_version_id = $route->id;
        $trip->save();
    }

    private function guard(Trip $trip, int $version, array $states): void
    {
        if ($trip->lock_version !== $version) {
            $this->fail('STALE_VERSION', 'Trip telah berubah. Muat ulang sebelum melanjutkan.');
        }
        if (! in_array($trip->status, $states, true) || $trip->actual_departure_at !== null) {
            $this->fail('TRIP_LOCKED', 'Trip tidak dapat diubah pada status ini.');
        }
    }

    private function event(Trip $trip, int $actor, string $action, ?string $reason = null): void
    {
        DB::table('trip_events')->insert(['trip_id' => $trip->id, 'actor_id' => $actor, 'action' => $action, 'trip_version' => $trip->lock_version ?? 0, 'reason' => $reason, 'created_at' => now()]);
    }

    private function response(Trip $trip): array
    {
        return ['status' => 200, 'body' => ['data' => ['id' => (string) $trip->id, 'status' => $trip->status, 'lock_version' => $trip->lock_version]]];
    }

    private function fail(string $code, string $message): never
    {
        throw new BusinessFailure($code, $message);
    }
}
