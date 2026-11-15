<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use App\Models\Trip;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class TripOptimizationService
{
    public function preview(int $actor, int $tripId, array $data): array
    {
        $roads = null;
        if ($data['use_road_provider'] ?? false) {
            $read = Trip::with('selectedRoute')->findOrFail($tripId);
            if ($read->lock_version !== $data['lock_version'] || $read->status !== 'draft') {
                throw new BusinessFailure('STALE_VERSION', 'Trip berubah. Muat ulang sebelum menghitung rute.');
            }
            $input = $read->selectedRoute->input_snapshot;
            $signature = $this->roadPoints($input);
            $roads = app(RoadRouting::class)->matrix($signature['points'], $signature['mode']);
            $roads['signature'] = $signature;
        }

        return DB::transaction(function () use ($actor, $tripId, $data, $roads) {
            [$trip, $snapshot] = app(ManualTripService::class)->prepareOptimization($tripId, $data['lock_version']);
            if ($roads && $roads['signature'] !== $this->roadPoints($snapshot)) {
                throw new BusinessFailure('PLAN_CHANGED', 'Titik atau kendaraan berubah. Hitung ulang matriks jalan.');
            }
            $matrix = $roads['seconds'] ?? array_map(fn ($row) => array_map(fn ($minutes) => (int) $minutes * 60, $row), $data['matrix_minutes']);
            $source = $roads ? 'Valhalla lokal · '.$roads['road_source']['travel_mode'].' · '.$roads['road_source']['calculated_at'] : $data['source_reference'];
            $planning = $snapshot;
            $recommend = (bool) ($data['recommend_departure'] ?? false);
            if ($recommend) {
                $earliest = CarbonImmutable::instance(now())->addMinutes($snapshot['depot']['delivery_prep_minutes'] ?? 30)->ceilMinute()
                    ->max(CarbonImmutable::parse($snapshot['operating_hours']['opens_at']));
                $planning['departure_at'] = $earliest->toISOString();
            }
            $optimizer = app(TripRouteOptimizer::class);
            $result = $optimizer->optimize($planning, $matrix);
            if ($recommend && $result['selected'] !== null) {
                $firstId = $result['selected']['order_ids'][0];
                $first = collect($snapshot['orders'])->firstWhere('id', $firstId);
                $suggested = CarbonImmutable::parse($first['window_start_at'])->subSeconds($result['selected']['leg_seconds'][0])->max($earliest)->ceilMinute();
                $planning['departure_at'] = $suggested->toISOString();
                $result = $optimizer->optimize($planning, $matrix);
            }
            $result['departure_at'] = $planning['departure_at'];
            $result['departure_local'] = CarbonImmutable::parse($planning['departure_at'])->setTimezone($snapshot['depot']['timezone'])->format('Y-m-d\TH:i');
            $result['departure_recommended'] = $recommend;
            $result['road_source'] = $roads['road_source'] ?? null;
            $id = Str::uuid()->toString();
            $expires = now()->addMinutes(30);
            $input = ['matrix_seconds' => $matrix, 'source_reference' => $source, 'road_source' => $roads['road_source'] ?? null, 'snapshot' => $snapshot];
            DB::table('trip_optimizations')->insert(['id' => $id, 'trip_id' => $tripId, 'actor_id' => $actor, 'trip_version' => $trip->lock_version, 'route_version_id' => $trip->selected_route_version_id,
                'snapshot_hash' => hash('sha256', json_encode($snapshot, JSON_THROW_ON_ERROR)), 'input' => json_encode($input, JSON_THROW_ON_ERROR), 'result' => json_encode($result, JSON_THROW_ON_ERROR), 'expires_at' => $expires, 'created_at' => now(), 'updated_at' => now()]);

            return ['id' => $id, 'expires_at' => $expires->toISOString(), ...$result];
        });
    }

    public function apply(int $actor, int $tripId, array $data): array
    {
        return DB::transaction(function () use ($actor, $tripId, $data) {
            [$trip, $snapshot] = app(ManualTripService::class)->prepareOptimization($tripId, $data['lock_version']);
            $preview = DB::table('trip_optimizations')->where('id', $data['optimization_id'])->where('trip_id', $tripId)->where('actor_id', $actor)->first();
            abort_unless($preview, 404);
            if ((int) $preview->trip_version !== $trip->lock_version || (int) $preview->route_version_id !== (int) $trip->selected_route_version_id || CarbonImmutable::parse($preview->expires_at, 'UTC') <= now()
                || ! hash_equals($preview->snapshot_hash, hash('sha256', json_encode($snapshot, JSON_THROW_ON_ERROR)))) {
                throw new BusinessFailure('OPTIMIZATION_STALE', 'Trip, pesanan atau armada berubah, atau rekomendasi kedaluwarsa. Hitung ulang optimasi.');
            }
            $result = json_decode($preview->result, true, flags: JSON_THROW_ON_ERROR);
            $selected = $result['selected'];
            if ($selected === null) {
                throw new BusinessFailure('ROUTE_NOT_FOUND', 'Belum ditemukan rute yang memenuhi seluruh batas waktu. Tinjau waktu jalan atau pecah trip.');
            }
            $input = json_decode($preview->input, true, flags: JSON_THROW_ON_ERROR);
            $plan = $snapshot['plan'];
            $byId = collect($plan['orders'])->keyBy('id');
            $plan['orders'] = array_map(fn ($id) => $byId->get($id), $selected['order_ids']);
            $plan['lock_version'] = $trip->lock_version;
            $plan['departure_local'] = $result['departure_local'] ?? $plan['departure_local'];
            $metadata = ['id' => $preview->id, 'algorithm' => $result['algorithm'], 'source_reference' => $input['source_reference'], 'road_source' => $input['road_source'] ?? null, 'leg_seconds' => $selected['leg_seconds'], 'schedule' => $selected['schedule'],
                'matrix_order_ids' => array_column($snapshot['orders'], 'id'), 'matrix_seconds' => $input['matrix_seconds'], 'selected_from' => $result['selected_from'], 'baseline' => $result['baseline'], 'fifo' => $result['fifo'], 'reviewed_by' => $actor, 'reviewed_at' => now()->toISOString()];

            return app(ManualTripService::class)->save($actor, $plan, $tripId, $metadata);
        });
    }

    private function roadPoints(array $snapshot): array
    {
        $points = [$snapshot['depot'], ...array_column($snapshot['orders'], 'address')];

        return ['points' => array_map(fn ($point) => ['latitude' => (float) $point['latitude'], 'longitude' => (float) $point['longitude']], $points), 'mode' => $snapshot['vehicle']['travel_mode']];
    }
}
