<?php

namespace App\Services;

use App\Models\DeliverySlot;
use App\Models\Depot;
use Illuminate\Support\Facades\DB;

class DeliveryScheduleGenerator
{
    public function generate(int $days = 14): int
    {
        return DB::transaction(function () use ($days) {
            $depot = Depot::lockForUpdate()->findOrFail(1);
            if (! $depot->configured()) {
                return 0;
            }
            $created = 0;
            for ($day = 0; $day < $days; $day++) {
                $date = now($depot->timezone)->addDays($day)->toDateString();
                [$open, $close] = app(DeliveryPolicy::class)->bounds($depot, $date);
                for ($start = $open; $start < $close; $start = $start->addHour()) {
                    $end = $start->addHour()->min($close);
                    $cutoff = $start->subMinutes($depot->delivery_prep_minutes);
                    if ($cutoff <= now() || DeliverySlot::where('depot_id', 1)->where('window_start_at', '<', $end)->where('window_end_at', '>', $start)->exists()) {
                        continue;
                    }
                    $slot = new DeliverySlot(['service_date' => $date, 'window_start_at' => $start, 'window_end_at' => $end, 'cutoff_at' => $cutoff, 'is_active' => true]);
                    $slot->depot_id = 1;
                    $slot->save();
                    $created++;
                }
            }

            return $created;
        });
    }
}
