<?php

namespace Tests\Feature;

use App\Exceptions\BusinessFailure;
use App\Models\Depot;
use App\Models\User;
use App\Services\RoadRouting;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class RoadRoutingTest extends TestCase
{
    use RefreshDatabase;

    private array $points = [['latitude' => -7.25, 'longitude' => 112.75], ['latitude' => -7.26, 'longitude' => 112.76]];

    public function test_admin_coverage_uses_actual_graph_and_preserves_delivery_radius(): void
    {
        $depot = Depot::findOrFail(1);
        $depot->fill(['address_text' => 'Depot uji', 'latitude' => -7.2771739, 'longitude' => 112.7921963,
            'service_radius_m' => 10000, 'delivery_fee_rp' => 3000])->save();
        $this->actingAs(User::factory()->create(['role' => 'admin']));
        Cache::flush();
        Http::fake(['*/health' => Http::sequence()
            ->push(['status' => 'ok', 'bbox' => [-7.32, 112.75, -7.23, 112.84]])
            ->push(['status' => 'ok', 'bbox' => [-7.394, 112.674, -7.16, 112.91]])]);
        $this->getJson('/admin/routing/status')->assertOk()->assertJsonPath('data.service_area_covered', false);
        Cache::flush();
        $this->getJson('/admin/routing/status')->assertOk()->assertJsonPath('data.available', true)->assertJsonPath('data.service_area_covered', true);
        $this->assertSame(10000, $depot->fresh()->service_radius_m);
    }

    public function test_matrix_preserves_directions_rounds_up_and_caches_by_vehicle(): void
    {
        Cache::flush();
        Http::fake([
            '*/health' => Http::response(['status' => 'ok', 'bbox' => [-8, 112, -7, 113], 'dataset_id' => 'test-graph']),
            '*/matrix' => Http::response(['sources_to_targets' => [[['time' => 0], ['time' => 61]], [['time' => 59], ['time' => 0]]]]),
        ]);
        $service = app(RoadRouting::class);
        $result = $service->matrix($this->points, 'motorcycle');
        $this->assertSame([[0, 120], [60, 0]], $result['seconds']);
        $this->assertSame('test-graph', $result['road_source']['dataset_id']);
        $this->assertSame($result, $service->matrix($this->points, 'motorcycle'));
        Http::assertSentCount(2);
        $service->matrix($this->points, 'car');
        Http::assertSentCount(3);
        Http::assertSent(fn ($request) => $request->method() === 'POST' && $request['costing'] === 'auto' && $request['sources'] === $request['targets']);
    }

    public function test_outside_coverage_fails_before_route_request(): void
    {
        Cache::flush();
        Http::fake(['*/health' => Http::response(['status' => 'ok', 'bbox' => [-8, 112, -7, 113]])]);
        try {
            app(RoadRouting::class)->route([['latitude' => 1, 'longitude' => 1], $this->points[0]], 'motorcycle');
            $this->fail('Expected coverage failure');
        } catch (BusinessFailure $error) {
            $this->assertSame(422, $error->status);
            $this->assertSame('ROUTING_OUTSIDE_AREA', $error->body()['code']);
        }
        Http::assertSentCount(1);
    }

    public function test_unreachable_matrix_is_rejected(): void
    {
        Cache::flush();
        Http::fake([
            '*/health' => Http::response(['status' => 'ok', 'bbox' => [-8, 112, -7, 113]]),
            '*/matrix' => Http::response(['sources_to_targets' => [[['time' => 0], ['time' => null]], [['time' => 2], ['time' => 0]]]]),
        ]);
        $this->expectException(BusinessFailure::class);
        app(RoadRouting::class)->matrix($this->points, 'motorcycle');
    }
}
