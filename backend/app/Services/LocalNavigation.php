<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

class LocalNavigation
{
    public function route(array $trip, array $origin): array
    {
        $returning = $trip['status'] === 'awaiting_reconciliation';
        $next = collect($trip['stops'])->first(fn ($stop) => ! in_array($stop['status'], ['delivered', 'failed'], true));
        $address = $returning ? $trip['depot'] : ($next['address'] ?? null);
        $mode = $trip['vehicle']['travel_mode'] ?? null;
        if (! in_array($trip['status'], ['assigned', 'in_progress', 'awaiting_reconciliation'], true)
            || ! in_array($mode, ['motorcycle', 'car'], true) || ! $address
            || ! is_numeric($address['latitude'] ?? null) || ! is_numeric($address['longitude'] ?? null)) {
            throw new BusinessFailure('NAVIGATION_UNAVAILABLE', 'Tujuan atau kendaraan belum tersedia untuk navigasi.', 409);
        }
        try {
            $response = Http::connectTimeout(2)->timeout(12)->post(rtrim(config('navigation.url'), '/').'/route', [
                'locations' => [
                    ['lat' => (float) $origin['latitude'], 'lon' => (float) $origin['longitude']],
                    ['lat' => (float) $address['latitude'], 'lon' => (float) $address['longitude']],
                ],
                'costing' => $mode === 'motorcycle' ? 'motorcycle' : 'auto',
                'directions_options' => ['units' => 'kilometers', 'language' => 'id-ID'],
            ]);
        } catch (ConnectionException) {
            throw new BusinessFailure('ROUTING_OFFLINE', 'Mesin rute demo belum aktif. Jalankan routing lokal di laptop.', 503);
        }
        if ($response->status() === 422) {
            throw new BusinessFailure('ROUTE_NOT_FOUND', 'Rute belum ditemukan dalam area peta demo. Periksa lokasi awal dan tujuan.', 422);
        }
        $result = $response->json('trip');
        $leg = $result['legs'][0] ?? null;
        if (! $response->successful() || ! is_array($leg) || empty($leg['shape']) || ! isset($result['summary']['time'], $result['summary']['length'])) {
            throw new BusinessFailure('ROUTING_FAILED', 'Mesin rute belum dapat menghitung perjalanan. Coba lagi.', 503);
        }

        return [
            'provider' => 'valhalla-local',
            'route_version_id' => $trip['route_version_id'],
            'target_id' => $returning ? 'depot' : (string) $next['order_id'],
            'target' => [
                'name' => $returning ? $address['name'] : $address['recipient_name'],
                'address_text' => $address['address_text'],
                'latitude' => (float) $address['latitude'], 'longitude' => (float) $address['longitude'],
            ],
            'travel_mode' => $mode,
            'guidance' => $trip['status'] !== 'assigned',
            'shape' => $leg['shape'],
            'distance_m' => (int) round($result['summary']['length'] * 1000),
            'duration_seconds' => (int) round($result['summary']['time']),
            'maneuvers' => collect($leg['maneuvers'] ?? [])->map(fn ($step) => [
                'type' => $step['type'], 'instruction' => $this->instruction($step),
                'begin_shape_index' => $step['begin_shape_index'], 'end_shape_index' => $step['end_shape_index'],
                'distance_m' => (int) round(($step['length'] ?? 0) * 1000),
                'duration_seconds' => (int) round($step['time'] ?? 0),
            ])->all(),
            'attribution' => '© OpenStreetMap contributors · Valhalla',
        ];
    }

    private function instruction(array $step): string
    {
        $action = match ((int) $step['type']) {
            4, 5, 6 => 'Tiba di tujuan',
            9, 23 => 'Ambil kanan',
            10, 11, 18, 20 => 'Belok kanan',
            12 => 'Putar balik ke kanan',
            13 => 'Putar balik ke kiri',
            14, 15, 19, 21 => 'Belok kiri',
            16, 24 => 'Ambil kiri',
            25, 37, 38 => 'Bergabung ke jalan',
            26 => 'Masuk bundaran, ambil jalan keluar ke-'.($step['roundabout_exit_count'] ?? 1),
            27 => 'Keluar bundaran',
            28 => 'Naik kapal penyeberangan',
            29 => 'Keluar dari penyeberangan',
            default => 'Lanjutkan perjalanan',
        };
        $road = $step['street_names'][0] ?? null;

        return $action.($road && ! in_array((int) $step['type'], [4, 5, 6], true) ? ' menuju '.$road : '');
    }
}
