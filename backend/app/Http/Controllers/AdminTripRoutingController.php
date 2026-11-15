<?php

namespace App\Http\Controllers;

use App\Exceptions\BusinessFailure;
use App\Models\Depot;
use App\Models\Trip;
use App\Services\RoadRouting;
use App\Services\TripScheduleService;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;

class AdminTripRoutingController extends Controller
{
    public function status(RoadRouting $routing)
    {
        $status = $routing->availability();
        $depot = Depot::findOrFail(1);
        $covered = false;
        if ($status['available'] && $depot->configured()) {
            [$south, $west, $north, $east] = $status['bbox'];
            $lat = $depot->service_radius_m / 111320;
            $lon = $lat / max(0.01, cos(deg2rad($depot->latitude)));
            $covered = $depot->latitude - $lat >= $south && $depot->latitude + $lat <= $north
                && $depot->longitude - $lon >= $west && $depot->longitude + $lon <= $east;
        }

        return response()->json(['data' => [...$status, 'service_area_covered' => $covered]]);
    }

    public function preview(Request $request, Trip $trip, RoadRouting $routing)
    {
        abort_unless($trip->depot_id === 1, 404);
        $data = $request->validate(['lock_version' => ['required', 'integer', 'min:0']]);
        try {
            if ($trip->lock_version !== (int) $data['lock_version']) {
                throw new BusinessFailure('STALE_VERSION', 'Trip berubah. Muat ulang pratinjau rute.');
            }
            $snapshot = $trip->selectedRoute->input_snapshot;
            $stops = [$snapshot['depot'], ...array_column($snapshot['orders'], 'address'), $snapshot['depot']];
            $road = $routing->route($stops, $snapshot['vehicle']['travel_mode']);
            $baseline = null;
            $original = $snapshot['optimization']['matrix_order_ids'] ?? null;
            if ($original) {
                $orders = collect($snapshot['orders'])->keyBy('id');
                $baselineStops = [$snapshot['depot'], ...array_map(fn ($id) => $orders->get($id)['address'], $original), $snapshot['depot']];
                $baseline = $routing->route($baselineStops, $snapshot['vehicle']['travel_mode']);
                if ($baseline['road_source']['dataset_id'] !== $road['road_source']['dataset_id']) {
                    throw new BusinessFailure('ROAD_DATA_CHANGED', 'Data jalan berubah. Hitung ulang perbandingan rute.');
                }
            }
            $version = $trip->selected_route_version_id;
            $fresh = $trip->fresh();
            if ($fresh->lock_version !== $trip->lock_version || $fresh->selected_route_version_id !== $version) {
                throw new BusinessFailure('STALE_VERSION', 'Trip berubah selama perhitungan. Muat ulang halaman.');
            }
            $legs = $road['trip']['legs'];
            if (count($legs) !== count($snapshot['orders']) + 1) {
                throw new BusinessFailure('ROAD_DATA_INCOMPLETE', 'Data ruas perjalanan belum lengkap.', 503);
            }
            $seconds = array_map(fn ($leg) => (int) ceil($leg['summary']['time'] / 60) * 60, $legs);
            $schedule = null;
            $warning = null;
            try {
                $schedule = app(TripScheduleService::class)->evaluate($snapshot, $seconds, CarbonImmutable::parse($snapshot['departure_at']));
            } catch (BusinessFailure $error) {
                $warning = $error->getMessage();
            }

            return response()->json(['data' => ['route_version_id' => (string) $version,
                'road_source' => $road['road_source'], 'source_reference' => 'Valhalla lokal · '.$road['road_source']['travel_mode'].' · '.$road['road_source']['calculated_at'],
                'distance_m' => (int) round($road['trip']['summary']['length'] * 1000), 'duration_seconds' => (int) ceil($road['trip']['summary']['time']),
                'shapes' => array_column($legs, 'shape'), 'baseline_shapes' => $baseline ? array_column($baseline['trip']['legs'], 'shape') : [],
                'baseline_distance_m' => $baseline ? (int) round($baseline['trip']['summary']['length'] * 1000) : null,
                'baseline_duration_seconds' => $baseline ? (int) ceil($baseline['trip']['summary']['time']) : null,
                'leg_seconds' => $seconds, 'schedule' => $schedule, 'schedule_warning' => $warning,
                'points' => array_map(fn ($point, $i) => ['latitude' => (float) $point['latitude'], 'longitude' => (float) $point['longitude'], 'label' => $i === 0 || $i === count($stops) - 1 ? $snapshot['depot']['name'] : 'Tujuan '.$i], $stops, array_keys($stops))]]);
        } catch (BusinessFailure $error) {
            return response()->json($error->body(), $error->status);
        }
    }
}
