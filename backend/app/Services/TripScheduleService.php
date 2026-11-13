<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use Carbon\CarbonImmutable;

class TripScheduleService
{
    // Inputs are directed road travel durations, including the final return leg.
    // No straight-line distance, speed assumption or road data is invented here.
    public function evaluate(array $snapshot, array $legs, CarbonImmutable $departure): array
    {
        $orders = $snapshot['orders'];
        if (count($legs) !== count($orders) + 1 || ! array_is_list($legs)) {
            throw new BusinessFailure('ROAD_DATA_INCOMPLETE', 'Waktu jalan harus lengkap: depot ke tujuan, antar-tujuan, dan kembali ke depot.');
        }
        foreach ($legs as $seconds) {
            if (! is_int($seconds) || $seconds < 0 || $seconds > 86400) {
                throw new BusinessFailure('ROAD_DATA_INVALID', 'Waktu perjalanan setiap ruas harus berupa detik 0–86400.');
            }
        }
        $hours = $snapshot['operating_hours'] ?? null;
        if ($hours === null && count($orders) > 0 && isset($snapshot['depot']['timezone'])) {
            $depot = new \App\Models\Depot(['timezone' => $snapshot['depot']['timezone']]);
            $date = CarbonImmutable::parse($orders[0]['window_start_at'])->setTimezone($depot->timezone)->toDateString();
            [$opens, $closes] = app(DeliveryPolicy::class)->bounds($depot, $date);
            $hours = ['opens_at' => $opens->toISOString(), 'closes_at' => $closes->toISOString()];
        }
        if ($hours !== null && ($departure < CarbonImmutable::parse($hours['opens_at']) || $departure >= CarbonImmutable::parse($hours['closes_at']))) {
            throw new BusinessFailure('SCHEDULE_INFEASIBLE', 'Keberangkatan di luar jam layanan.');
        }
        $cursor = $departure;
        $stops = [];
        foreach ($orders as $i => $order) {
            $arrival = $cursor->addSeconds($legs[$i]);
            $opening = CarbonImmutable::parse($order['window_start_at'])->utc();
            $closing = CarbonImmutable::parse($order['window_end_at'])->utc();
            $service = $arrival->max($opening);
            if ($hours !== null) {
                $closing = $closing->min(CarbonImmutable::parse($hours['closes_at']));
            }
            $completion = $service->addSeconds($snapshot['depot']['default_service_seconds']);
            if ($completion > $closing) {
                throw new BusinessFailure('SCHEDULE_INFEASIBLE', 'Tujuan '.($i + 1).' melewati akhir jendela pengiriman atau jam tutup. Tinjau urutan, waktu jalan, atau gelombang.');
            }
            $cursor = $completion;
            $stops[] = ['order_id' => (string) $order['id'], 'sequence_no' => $i + 1, 'estimated_arrival_at' => $arrival->toISOString(), 'estimated_service_start_at' => $service->toISOString(), 'estimated_service_end_at' => $cursor->toISOString(), 'waiting_seconds' => $service->getTimestamp() - $arrival->getTimestamp()];
        }

        return ['departure_at' => $departure->toISOString(), 'stops' => $stops, 'estimated_return_at' => $cursor->addSeconds($legs[count($orders)])->toISOString(), 'travel_seconds' => array_sum($legs)];
    }
}
