<?php

// Read-only benchmark using fictional destinations and the active local road graph.
use App\Models\Depot;
use App\Services\DeliveryArea;
use App\Services\DeliveryPolicy;
use App\Services\RoadRouting;
use App\Services\TripRouteOptimizer;
use Carbon\CarbonImmutable;
use Illuminate\Contracts\Console\Kernel;

require __DIR__.'/../backend/vendor/autoload.php';
$app = require __DIR__.'/../backend/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

try {
    $depot = Depot::findOrFail(1);
    $coordinates = [
        [-7.278, 112.790], [-7.282, 112.760], [-7.264, 112.810], [-7.298, 112.770],
        [-7.258, 112.790], [-7.295, 112.812], [-7.271, 112.775], [-7.304, 112.800],
        [-7.252, 112.805], [-7.285, 112.782], [-7.260, 112.765], [-7.300, 112.785],
        [-7.275, 112.812], [-7.290, 112.760], [-7.255, 112.780], [-7.305, 112.810],
        [-7.265, 112.795], [-7.295, 112.775], [-7.280, 112.805], [-7.270, 112.760],
    ];
    [$opens, $closes] = app(DeliveryPolicy::class)->bounds($depot, now($depot->timezone)->toDateString());
    $results = [];
    foreach ([10, 20] as $count) {
        $points = [['latitude' => $depot->latitude, 'longitude' => $depot->longitude]];
        $orders = [];
        foreach (array_slice($coordinates, 0, $count) as $index => [$latitude, $longitude]) {
            if (app(DeliveryArea::class)->distance($depot, $latitude, $longitude) > $depot->service_radius_m) {
                throw new RuntimeException('Titik benchmark Surabaya berada di luar radius depot saat ini. Sesuaikan fixture sebelum mengulang benchmark.');
            }
            $point = ['latitude' => $latitude, 'longitude' => $longitude];
            $points[] = $point;
            $orders[] = [
                'id' => (string) ($index + 1),
                'created_at' => $opens->subHour()->addMinutes($index)->toISOString(),
                'delivery_type' => $count === 20 && $index % 5 === 0 ? 'express' : 'regular',
                'window_start_at' => $opens->toISOString(),
                'window_end_at' => $closes->toISOString(),
                'address' => $point,
            ];
        }
        $snapshot = [
            'depot' => ['timezone' => $depot->timezone, 'default_service_seconds' => $depot->default_service_seconds],
            'departure_at' => $opens->addMinutes(15)->toISOString(),
            'operating_hours' => ['opens_at' => $opens->toISOString(), 'closes_at' => $closes->toISOString()],
            'orders' => $orders,
        ];
        $matrix = app(RoadRouting::class)->matrix($points, 'motorcycle');
        $started = hrtime(true);
        $result = app(TripRouteOptimizer::class)->optimize($snapshot, $matrix['seconds']);
        $elapsedMs = round((hrtime(true) - $started) / 1000000, 2);
        $selected = $result['selected'];
        $baseline = $result['baseline'];
        if ($selected === null || $baseline === null || $selected['score'] > $baseline['score']) {
            throw new RuntimeException('Rute benchmark belum layak atau skor rute terpilih lebih buruk daripada baseline.');
        }
        $actualIds = $selected['order_ids'];
        $expectedIds = array_column($orders, 'id');
        sort($actualIds);
        sort($expectedIds);
        if ($actualIds !== $expectedIds || count(array_unique($actualIds)) !== $count) {
            throw new RuntimeException('Rute benchmark kehilangan atau menggandakan tujuan.');
        }
        $baseTravel = $baseline['schedule']['travel_seconds'];
        $selectedTravel = $selected['schedule']['travel_seconds'];
        $selectedPoints = [$points[0]];
        foreach ($selected['order_ids'] as $id) {
            $selectedPoints[] = $points[(int) $id];
        }
        $selectedPoints[] = $points[0];
        $roadPreview = app(RoadRouting::class)->route($selectedPoints, 'motorcycle');
        if (count($roadPreview['trip']['legs']) !== $count + 1) {
            throw new RuntimeException('Pratinjau jalan tidak mencakup seluruh tujuan dan kepulangan ke depot.');
        }
        $results[] = [
            'stops' => $count,
            'express_stops' => count(array_filter($orders, fn ($order) => $order['delivery_type'] === 'express')),
            'road_source' => $matrix['road_source'],
            'baseline_travel_seconds' => $baseTravel,
            'selected_travel_seconds' => $selectedTravel,
            'travel_saving_percent' => round(($baseTravel - $selectedTravel) / max(1, $baseTravel) * 100, 2),
            'baseline_express_completion_seconds' => $baseline['express_completion_seconds'],
            'selected_express_completion_seconds' => $selected['express_completion_seconds'],
            'selected_from' => $result['selected_from'],
            'order_ids' => $selected['order_ids'],
            'estimated_return_at' => $selected['schedule']['estimated_return_at'],
            'optimizer_ms' => $elapsedMs,
            'road_preview_distance_m' => (int) round($roadPreview['trip']['summary']['length'] * 1000),
        ];
        echo "PASS: $count tujuan, optimasi {$elapsedMs} ms, perjalanan {$baseTravel}s menjadi {$selectedTravel}s.\n";
    }
    $report = [
        'generated_at' => CarbonImmutable::now()->toISOString(),
        'description' => 'Fictional Surabaya destinations, directed Valhalla matrix, simulated schedule; physical travel time remains unverified.',
        'algorithm' => $result['algorithm'],
        'results' => $results,
    ];
    $directory = base_path('work/demo-verification');
    if (! is_dir($directory)) {
        mkdir($directory, 0777, true);
    }
    file_put_contents($directory.'/route-benchmark.json', json_encode($report, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR));
    echo "PASS: laporan disimpan di backend/work/demo-verification/route-benchmark.json.\n";
} catch (Throwable $error) {
    fwrite(STDERR, 'FAIL: '.$error->getMessage().PHP_EOL);
    exit(1);
}
