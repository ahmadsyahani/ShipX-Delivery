<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

class RoadRouting
{
    public function status(): array
    {
        return Cache::remember('shipx.routing.health.'.sha1(config('navigation.url')), 5, function () {
            try {
                $response = Http::connectTimeout(2)->timeout(3)->get(rtrim(config('navigation.url'), '/').'/health');
            } catch (ConnectionException) {
                throw new BusinessFailure('ROUTING_OFFLINE', 'Mesin rute demo belum aktif. Jalankan routing lokal di laptop.', 503);
            }
            $status = $response->json();
            if (! $response->successful() || ! is_array($status) || ($status['status'] ?? null) !== 'ok' || ! is_array($status['bbox'] ?? null) || count($status['bbox']) !== 4) {
                throw new BusinessFailure('ROUTING_OFFLINE', 'Mesin rute demo belum siap. Periksa layanan routing di laptop.', 503);
            }

            return ['available' => true, 'provider' => 'valhalla-local', 'bbox' => $status['bbox'], 'dataset_id' => $status['dataset_id'] ?? 'local'];
        });
    }

    public function availability(): array
    {
        try {
            return $this->status();
        } catch (BusinessFailure $error) {
            return ['available' => false, 'provider' => 'valhalla-local', 'message' => $error->getMessage()];
        }
    }

    public function route(array $points, string $mode): array
    {
        return $this->request('route', $points, $mode);
    }

    public function matrix(array $points, string $mode): array
    {
        $result = $this->request('matrix', $points, $mode);
        $size = count($points);
        $rows = $result['sources_to_targets'] ?? [];
        if (! is_array($rows) || ! array_is_list($rows) || count($rows) !== $size) {
            throw new BusinessFailure('ROAD_DATA_INCOMPLETE', 'Matriks jalan belum lengkap. Periksa semua tujuan.', 422);
        }
        $matrix = [];
        foreach ($rows as $row) {
            if (! is_array($row) || ! array_is_list($row) || count($row) !== $size) {
                throw new BusinessFailure('ROAD_DATA_INCOMPLETE', 'Matriks jalan belum lengkap. Periksa semua tujuan.', 422);
            }
            $seconds = [];
            foreach ($row as $cell) {
                if (! is_array($cell) || ! is_numeric($cell['time'] ?? null) || $cell['time'] < 0 || $cell['time'] > 86400) {
                    throw new BusinessFailure('ROUTE_NOT_FOUND', 'Salah satu ruas jalan belum dapat dilalui kendaraan ini.', 422);
                }
                $seconds[] = (int) ceil($cell['time'] / 60) * 60;
            }
            $matrix[] = $seconds;
        }

        return ['seconds' => $matrix, 'road_source' => [...$result['road_source'], 'rounding' => 'ceil_minute']];
    }

    private function request(string $endpoint, array $points, string $mode): array
    {
        $maximum = $endpoint === 'matrix' ? 21 : 22;
        if (! in_array($mode, ['motorcycle', 'car'], true) || count($points) < 2 || count($points) > $maximum) {
            throw new BusinessFailure('ROUTING_INPUT_INVALID', 'Jenis kendaraan atau jumlah titik rute tidak sesuai.', 422);
        }
        $status = $this->status();
        [$south, $west, $north, $east] = $status['bbox'];
        $locations = [];
        foreach ($points as $point) {
            $lat = (float) $point['latitude'];
            $lon = (float) $point['longitude'];
            if (! is_finite($lat) || ! is_finite($lon) || $lat < $south || $lat > $north || $lon < $west || $lon > $east) {
                throw new BusinessFailure('ROUTING_OUTSIDE_AREA', 'Lokasi berada di luar cakupan peta demo. Pilih alamat dalam area depot.', 422);
            }
            $locations[] = ['lat' => round($lat, 7), 'lon' => round($lon, 7)];
        }
        $key = 'shipx.routing.'.hash('sha256', json_encode([config('navigation.url'), $status['dataset_id'], $endpoint, $mode, $locations]));

        return Cache::remember($key, 1800, function () use ($endpoint, $locations, $mode, $status) {
            $payload = ['costing' => $mode === 'motorcycle' ? 'motorcycle' : 'auto'];
            $payload += $endpoint === 'matrix' ? ['sources' => $locations, 'targets' => $locations] : ['locations' => $locations];
            try {
                $response = Http::connectTimeout(2)->timeout(12)->post(rtrim(config('navigation.url'), '/').'/'.$endpoint, $payload);
            } catch (ConnectionException) {
                throw new BusinessFailure('ROUTING_OFFLINE', 'Mesin rute demo belum aktif. Jalankan routing lokal di laptop.', 503);
            }
            if ($response->status() === 422) {
                throw new BusinessFailure('ROUTE_NOT_FOUND', 'Rute belum ditemukan dalam area peta demo. Periksa lokasi dan jenis kendaraan.', 422);
            }
            $result = $response->json();
            if (! $response->successful() || ! is_array($result) || ($endpoint === 'route' && ! isset($result['trip']['summary']['time'], $result['trip']['summary']['length'], $result['trip']['legs'][0]['shape']))) {
                throw new BusinessFailure('ROUTING_FAILED', 'Mesin rute belum dapat menghitung perjalanan. Coba lagi.', 503);
            }
            $result['road_source'] = ['provider' => 'valhalla-local', 'dataset_id' => $status['dataset_id'], 'travel_mode' => $mode, 'calculated_at' => now()->toISOString()];

            return $result;
        });
    }
}
