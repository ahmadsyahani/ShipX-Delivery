<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use Carbon\CarbonImmutable;

class TripRouteOptimizer
{
    public function optimize(array $snapshot, array $matrix): array
    {
        $orders = $snapshot['orders'];
        $size = count($orders) + 1;
        if (count($matrix) !== $size || ! array_is_list($matrix)) {
            throw new BusinessFailure('ROAD_DATA_INCOMPLETE', 'Isi tabel waktu jalan untuk depot dan seluruh tujuan.');
        }
        foreach ($matrix as $i => $row) {
            if (! is_array($row) || ! array_is_list($row) || count($row) !== $size) {
                throw new BusinessFailure('ROAD_DATA_INCOMPLETE', 'Setiap baris tabel harus memuat seluruh tujuan.');
            }
            foreach ($row as $j => $seconds) {
                if (! is_int($seconds) || $seconds < 0 || $seconds > 86400 || ($i === $j && $seconds !== 0)) {
                    throw new BusinessFailure('ROAD_DATA_INVALID', 'Waktu jalan harus 0–1440 menit dan diagonal tabel harus nol.');
                }
            }
        }
        $original = array_keys($orders);
        $baseline = $this->evaluate($snapshot, $matrix, $original);
        $fifo = $original;
        usort($fifo, fn ($a, $b) => [$orders[$a]['created_at'] ?? '', (int) $orders[$a]['id']] <=> [$orders[$b]['created_at'] ?? '', (int) $orders[$b]['id']]);
        $fifoResult = $this->evaluate($snapshot, $matrix, $fifo);
        $urgent = $original;
        usort($urgent, fn ($a, $b) => [$orders[$a]['window_end_at'], ($orders[$a]['delivery_type'] ?? 'regular') === 'express' ? 0 : 1, (int) $orders[$a]['id']]
            <=> [$orders[$b]['window_end_at'], ($orders[$b]['delivery_type'] ?? 'regular') === 'express' ? 0 : 1, (int) $orders[$b]['id']]);
        $sequence = [];
        $candidate = null;
        foreach ($urgent as $index) {
            $best = null;
            foreach (range(0, count($sequence)) as $position) {
                $trial = $sequence;
                array_splice($trial, $position, 0, [$index]);
                $evaluated = $this->evaluate($snapshot, $matrix, $trial);
                if ($evaluated !== null && ($best === null || $evaluated['score'] < $best['score'])) {
                    $best = $evaluated;
                }
            }
            if ($best === null) {
                $candidate = null;
                break;
            }
            $sequence = $best['sequence'];
            $candidate = $best;
        }
        if ($candidate !== null) {
            // Directed matrices require evaluating every reversed arc and schedule.
            for ($pass = 0; $pass < 10; $pass++) {
                $improved = false;
                for ($i = 0; $i < count($sequence) - 1; $i++) {
                    for ($j = $i + 1; $j < count($sequence); $j++) {
                        $trial = array_merge(array_slice($sequence, 0, $i), array_reverse(array_slice($sequence, $i, $j - $i + 1)), array_slice($sequence, $j + 1));
                        $evaluated = $this->evaluate($snapshot, $matrix, $trial);
                        if ($evaluated !== null && $evaluated['score'] < $candidate['score']) {
                            $candidate = $evaluated;
                            $sequence = $trial;
                            $improved = true;
                            break 2;
                        }
                    }
                }
                if (! $improved) {
                    break;
                }
            }
        }
        $selected = null;
        $selectedFrom = null;
        foreach (['original' => $baseline, 'fifo' => $fifoResult, 'optimized' => $candidate] as $name => $route) {
            if ($route !== null && ($selected === null || $route['score'] < $selected['score'])) {
                $selected = $route;
                $selectedFrom = $name;
            }
        }

        return ['algorithm' => 'deadline_insertion_2opt_v1', 'baseline' => $baseline, 'fifo' => $fifoResult, 'candidate' => $candidate, 'selected' => $selected, 'selected_from' => $selectedFrom];
    }

    private function evaluate(array $snapshot, array $matrix, array $sequence): ?array
    {
        $route = $snapshot;
        $route['orders'] = array_map(fn ($i) => $snapshot['orders'][$i], $sequence);
        $legs = [];
        $previous = 0;
        foreach ($sequence as $i) {
            $legs[] = $matrix[$previous][$i + 1];
            $previous = $i + 1;
        }
        $legs[] = $matrix[$previous][0];
        $departure = CarbonImmutable::parse($snapshot['departure_at'])->utc();
        try {
            $schedule = app(TripScheduleService::class)->evaluate($route, $legs, $departure);
        } catch (BusinessFailure $error) {
            if ($error->businessCode !== 'SCHEDULE_INFEASIBLE') {
                throw $error;
            }

            return null;
        }
        $expressSeconds = 0;
        foreach ($route['orders'] as $i => $order) {
            if (($order['delivery_type'] ?? 'regular') === 'express') {
                $expressSeconds += CarbonImmutable::parse($schedule['stops'][$i]['estimated_service_end_at'])->timestamp - $departure->timestamp;
            }
        }

        return ['sequence' => $sequence, 'order_ids' => array_column($route['orders'], 'id'), 'leg_seconds' => $legs, 'schedule' => $schedule,
            'score' => [$expressSeconds, $schedule['travel_seconds'], CarbonImmutable::parse($schedule['estimated_return_at'])->timestamp - $departure->timestamp], 'express_completion_seconds' => $expressSeconds];
    }
}
