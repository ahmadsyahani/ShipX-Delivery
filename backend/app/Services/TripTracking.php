<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use App\Models\Order;
use App\Models\Trip;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class TripTracking
{
    public function monitor(): array
    {
        $trips = Trip::where('depot_id', 1)->whereIn('status', ['assigned', 'in_progress', 'awaiting_reconciliation'])
            ->with('selectedRoute')->orderBy('planned_departure_at')->get();
        $couriers = \App\Models\User::whereIn('id', $trips->pluck('courier_id'))->get()->keyBy('id');
        $stops = DB::table('trip_stops')->join('trips', 'trips.id', '=', 'trip_stops.trip_id')
            ->whereIn('trip_stops.trip_id', $trips->modelKeys())->whereColumn('trip_stops.route_version_id', 'trips.selected_route_version_id')
            ->orderBy('trip_stops.sequence_no')->get(['trip_stops.*'])->groupBy('trip_id');

        return $trips->map(function (Trip $trip) use ($couriers, $stops) {
            $courier = $couriers->get($trip->courier_id);
            $rows = $stops->get($trip->id, collect());
            $pending = $rows->firstWhere('status', 'pending');
            $snapshot = $trip->selectedRoute->input_snapshot;
            $order = $pending ? collect($snapshot['orders'])->firstWhere('id', (string) $pending->order_id) : null;
            $last = $trip->status === 'in_progress' ? Cache::get($this->key($trip->id, $trip->selected_route_version_id)) : null;
            $valid = $courier && $courier->is_active && $courier->role === 'courier';
            if ($last && (! $valid || $last['courier_id'] !== $trip->courier_id || ! $this->tokenActive($last, $trip->courier_id))) $last = null;
            $fresh = $last && CarbonImmutable::parse($last['recorded_at']) >= now()->subSeconds(60) && CarbonImmutable::parse($last['received_at']) >= now()->subSeconds(60);

            return ['id' => (string) $trip->id, 'trip_number' => $trip->trip_number, 'status' => $trip->status,
                'courier_name' => $courier?->name ?? 'Kurir', 'courier_active' => (bool) $valid,
                'plate_number' => $snapshot['vehicle']['plate_number'], 'total_stops' => $rows->count(),
                'finished_stops' => $rows->whereIn('status', ['delivered', 'failed'])->count(),
                'tracking_status' => $last ? ($fresh ? 'live' : 'stale') : 'waiting',
                'location' => $last ? array_intersect_key($last, array_flip(['latitude', 'longitude', 'accuracy_m', 'recorded_at', 'received_at'])) : null,
                'next_stop' => $order ? ['recipient_name' => $order['address']['recipient_name'], 'address_text' => $order['address']['address_text'], 'sequence_no' => $pending->sequence_no] : null];
        })->all();
    }

    private function key(int $trip, int $route): string
    {
        return 'shipx.tracking.'.$trip.'.'.$route;
    }

    public function publish(int $courier, int $id, array $data, bool $stop = false): array
    {
        return Cache::lock('shipx.tracking.lock.'.$id, 10)->block(3, function () use ($courier, $id, $data, $stop) {
            return DB::transaction(function () use ($courier, $id, $data, $stop) {
                $trip = Trip::where('courier_id', $courier)->lockForUpdate()->findOrFail($id);
                $sessionKey = 'shipx.tracking.stopped.'.$id.'.'.$data['session_id'];
                $key = $this->key($id, $data['route_version_id']);
                if ($stop) {
                    Cache::put($sessionKey, true, 180);
                    if ((Cache::get($key)['session_id'] ?? null) === $data['session_id']) {
                        Cache::forget($key);
                    }

                    return ['accepted' => true];
                }
                if ($trip->status !== 'in_progress' || $trip->selected_route_version_id !== $data['route_version_id'] || Cache::has($sessionKey)) {
                    throw new BusinessFailure('TRACKING_STOPPED', 'Pelacakan untuk sesi atau rute ini sudah berakhir.', 409);
                }
                $recorded = CarbonImmutable::parse($data['recorded_at']);
                if ($recorded < now()->subMinutes(2) || $recorded > now()->addSeconds(30)) {
                    throw new BusinessFailure('LOCATION_EXPIRED', 'Waktu lokasi sudah kedaluwarsa. Periksa jam otomatis HP dan tunggu GPS terbaru.', 422);
                }
                $last = Cache::get($key);
                if ($last && CarbonImmutable::parse($last['recorded_at']) >= $recorded) {
                    return ['accepted' => false];
                }
                Cache::put($key, [...$data, 'courier_id' => $courier, 'received_at' => now()->toISOString()], 120);

                return ['accepted' => true];
            });
        });
    }

    private function assignment(Order $order): ?object
    {
        if ($order->fresh()->status !== 'out_for_delivery') {
            return null;
        }

        return DB::table('active_order_allocations as allocations')
            ->join('trips', 'trips.id', '=', 'allocations.trip_id')
            ->join('users', 'users.id', '=', 'trips.courier_id')
            ->join('trip_stops as stops', function ($join) {
                $join->on('stops.trip_id', '=', 'trips.id')->on('stops.order_id', '=', 'allocations.order_id')
                    ->on('stops.route_version_id', '=', 'trips.selected_route_version_id');
            })
            ->where('allocations.order_id', $order->id)->where('trips.status', 'in_progress')
            ->where('users.is_active', true)->where('users.role', 'courier')->where('stops.status', 'pending')
            ->select(['trips.id', 'trips.selected_route_version_id', 'trips.courier_id', 'stops.sequence_no'])->first();
    }

    private function tokenActive(array $fix, int $courier): bool
    {
        return isset($fix['token_id']) && DB::table('personal_access_tokens')->where('id', $fix['token_id'])
            ->where('tokenable_id', $courier)->where('tokenable_type', (new \App\Models\User)->getMorphClass())
            ->where(fn ($query) => $query->whereNull('expires_at')->orWhere('expires_at', '>', now()))->exists();
    }

    public function customer(int $customer, int $orderId): array
    {
        $order = Order::where('customer_id', $customer)->findOrFail($orderId);
        $assignment = $this->assignment($order);
        $unavailable = ['status' => 'unavailable', 'location' => null, 'route' => null];
        if (! $assignment) {
            return $unavailable;
        }
        $last = Cache::get($this->key($assignment->id, $assignment->selected_route_version_id));
        if (! $last || $last['courier_id'] !== $assignment->courier_id) {
            return ['status' => 'waiting', 'location' => null, 'route' => null];
        }
        if (! $this->tokenActive($last, $assignment->courier_id)) {
            return ['status' => 'waiting', 'location' => null, 'route' => null];
        }
        $fresh = CarbonImmutable::parse($last['recorded_at']) >= now()->subSeconds(60)
            && CarbonImmutable::parse($last['received_at']) >= now()->subSeconds(60);
        $next = DB::table('trip_stops')->where('trip_id', $assignment->id)->where('route_version_id', $assignment->selected_route_version_id)
            ->where('status', 'pending')->min('sequence_no');
        $direct = (int) $next === (int) $assignment->sequence_no;
        $route = null;
        if ($fresh && $direct) {
            try {
                $mode = Trip::findOrFail($assignment->id)->selectedRoute->input_snapshot['vehicle']['travel_mode'];
                $road = app(RoadRouting::class)->route([$last, ['latitude' => $order->latitude, 'longitude' => $order->longitude]], $mode);
                $route = ['shape' => $road['trip']['legs'][0]['shape'], 'distance_m' => (int) round($road['trip']['summary']['length'] * 1000), 'duration_seconds' => (int) ceil($road['trip']['summary']['time'])];
            } catch (BusinessFailure) {
                // Position remains available while the road service recovers.
            }
        }
        $current = $this->assignment($order);
        if (! $current || $current->id !== $assignment->id || $current->selected_route_version_id !== $assignment->selected_route_version_id || $current->courier_id !== $assignment->courier_id) {
            return $unavailable;
        }
        $shared = Cache::get($this->key($assignment->id, $assignment->selected_route_version_id));
        if (! $shared || $shared['session_id'] !== $last['session_id'] || ! $this->tokenActive($last, $assignment->courier_id)) {
            return ['status' => 'waiting', 'location' => null, 'route' => null];
        }
        $fresh = $fresh && CarbonImmutable::parse($last['recorded_at']) >= now()->subSeconds(60);
        if (! $fresh) {
            $route = null;
        }

        return ['status' => $fresh ? 'live' : 'stale', 'is_next_stop' => $direct,
            'location' => array_intersect_key($last, array_flip(['latitude', 'longitude', 'heading', 'accuracy_m', 'recorded_at', 'received_at'])),
            'destination' => ['latitude' => $order->latitude, 'longitude' => $order->longitude, 'address_text' => $order->address_text], 'route' => $route];
    }
}
