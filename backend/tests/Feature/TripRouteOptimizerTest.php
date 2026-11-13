<?php

namespace Tests\Feature;

use App\Exceptions\BusinessFailure;
use App\Services\TripRouteOptimizer;
use App\Services\TripScheduleService;
use Carbon\CarbonImmutable;
use Tests\TestCase;

class TripRouteOptimizerTest extends TestCase
{
    private function snapshot(int $count = 3): array
    {
        return ['departure_at' => '2026-11-05T02:00:00Z', 'operating_hours' => ['opens_at' => '2026-11-05T01:00:00Z', 'closes_at' => '2026-11-05T10:00:00Z'], 'depot' => ['default_service_seconds' => 300],
            'orders' => array_map(fn ($i) => ['id' => (string) $i, 'delivery_type' => 'regular', 'created_at' => '2026-11-04T01:00:00Z', 'window_start_at' => '2026-11-05T02:00:00Z', 'window_end_at' => '2026-11-05T06:00:00Z'], range(1, $count))];
    }

    private function seconds(array $matrix): array
    {
        return array_map(fn ($row) => array_map(fn ($minutes) => $minutes * 60, $row), $matrix);
    }

    public function test_directed_matrix_improves_route_and_recalculates_every_arc(): void
    {
        $snapshot = $this->snapshot();
        $matrix = $this->seconds([[0, 9, 1, 9], [1, 0, 8, 1], [9, 1, 0, 9], [1, 9, 1, 0]]);
        $result = app(TripRouteOptimizer::class)->optimize($snapshot, $matrix);
        $this->assertSame(27 * 60, $result['baseline']['schedule']['travel_seconds']);
        $this->assertSame(['2', '1', '3'], $result['selected']['order_ids']);
        $this->assertSame(4 * 60, $result['selected']['schedule']['travel_seconds']);
        $this->assertSame([60, 60, 60, 60], $result['selected']['leg_seconds']);
        $this->assertSame($result, app(TripRouteOptimizer::class)->optimize($snapshot, $matrix));
    }

    public function test_express_completion_precedes_travel_cost_and_all_deadlines_stay_hard(): void
    {
        $snapshot = $this->snapshot(2);
        $snapshot['orders'][1]['delivery_type'] = 'express';
        $matrix = $this->seconds([[0, 1, 10], [1, 0, 10], [1, 10, 0]]);
        $result = app(TripRouteOptimizer::class)->optimize($snapshot, $matrix);
        $this->assertSame(['2', '1'], $result['selected']['order_ids']);
        $this->assertLessThan($result['baseline']['express_completion_seconds'], $result['selected']['express_completion_seconds']);
        $snapshot['orders'][0]['window_end_at'] = '2026-11-05T02:06:00Z';
        $result = app(TripRouteOptimizer::class)->optimize($snapshot, $matrix);
        $this->assertSame(['1', '2'], $result['selected']['order_ids']);
    }

    public function test_no_feasible_candidate_returns_no_recommendation_and_incomplete_matrix_fails(): void
    {
        $snapshot = $this->snapshot(1);
        $snapshot['orders'][0]['window_end_at'] = '2026-11-05T02:04:00Z';
        $result = app(TripRouteOptimizer::class)->optimize($snapshot, [[0, 0], [0, 0]]);
        $this->assertNull($result['selected']);
        $this->expectException(BusinessFailure::class);
        app(TripRouteOptimizer::class)->optimize($snapshot, [[0]]);
    }

    public function test_service_completion_must_fit_slot_and_operating_close(): void
    {
        $snapshot = $this->snapshot(1);
        $snapshot['orders'][0]['window_end_at'] = '2026-11-05T11:00:00Z';
        $scheduler = app(TripScheduleService::class);
        $schedule = $scheduler->evaluate($snapshot, [0, 600], CarbonImmutable::parse('2026-11-05T09:55:00Z'));
        $this->assertSame('2026-11-05T10:00:00.000000Z', $schedule['stops'][0]['estimated_service_end_at']);
        $this->assertSame('2026-11-05T10:10:00.000000Z', $schedule['estimated_return_at']);
        $this->expectException(BusinessFailure::class);
        $scheduler->evaluate($snapshot, [0, 600], CarbonImmutable::parse('2026-11-05T09:56:00Z'));
    }

    public function test_twenty_stop_input_is_bounded_and_preserves_every_order(): void
    {
        $snapshot = $this->snapshot(20);
        $matrix = array_map(fn ($i) => array_map(fn ($j) => $i === $j ? 0 : 60, range(0, 20)), range(0, 20));
        $result = app(TripRouteOptimizer::class)->optimize($snapshot, $matrix);
        $this->assertCount(20, $result['selected']['order_ids']);
        $this->assertCount(21, $result['selected']['leg_seconds']);
        $this->assertEqualsCanonicalizing(array_column($snapshot['orders'], 'id'), $result['selected']['order_ids']);
    }
}
