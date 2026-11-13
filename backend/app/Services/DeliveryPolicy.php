<?php

namespace App\Services;

use App\Models\DeliverySlot;
use App\Models\Depot;
use Carbon\CarbonImmutable;

class DeliveryPolicy
{
    public function hours(Depot $depot, string $date): array
    {
        $day = CarbonImmutable::parse($date, $depot->timezone)->startOfDay();
        $holiday = in_array($date, app(NationalHolidayCalendar::class)->dates($day->year), true);
        $shortDay = $holiday || $day->isWeekend();

        return ['opens_at' => $shortDay ? '09:00' : '08:00', 'closes_at' => $shortDay ? '16:00' : '17:00', 'is_national_holiday' => $holiday];
    }

    public function bounds(Depot $depot, string $date): array
    {
        $hours = $this->hours($depot, $date);

        return [CarbonImmutable::parse($date.' '.$hours['opens_at'], $depot->timezone)->utc(), CarbonImmutable::parse($date.' '.$hours['closes_at'], $depot->timezone)->utc()];
    }

    public function allows(Depot $depot, DeliverySlot $slot): bool
    {
        [$open, $close] = $this->bounds($depot, $slot->service_date->format('Y-m-d'));

        return $slot->window_start_at >= $open && $slot->window_end_at <= $close && $slot->window_end_at > $slot->window_start_at;
    }

    public function pricing(Depot $depot, float $distance, string $type): array
    {
        $extraKm = max(0, (int) ceil($distance / 1000) - 1);
        $fee = $depot->delivery_fee_rp + $extraKm * $depot->delivery_per_km_rp;
        if ($type === 'express') {
            $fee = (int) ceil($fee * (100 + $depot->express_extra_percent) / 100);
        }

        return ['delivery_type' => $type, 'delivery_distance_m' => (int) ceil($distance), 'delivery_fee_rp' => $fee, 'preparation_minutes' => $depot->delivery_prep_minutes + (int) ceil($distance / 1000 / max(1, $depot->delivery_speed_kmh) * 60), 'distance_basis' => 'straight_line'];
    }
}
