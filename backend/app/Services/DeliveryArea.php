<?php

namespace App\Services;

use App\Models\Depot;

class DeliveryArea
{
    public function distance(Depot $depot, float $latitude, float $longitude): ?float
    {
        if (! $depot->configured()) {
            return null;
        }
        $a = sin(deg2rad($latitude - $depot->latitude) / 2) ** 2
            + cos(deg2rad($depot->latitude)) * cos(deg2rad($latitude)) * sin(deg2rad($longitude - $depot->longitude) / 2) ** 2;

        return 6371008.8 * 2 * asin(sqrt(min(1, max(0, $a))));
    }

    public function contains(Depot $depot, float $latitude, float $longitude): bool
    {
        $distance = $this->distance($depot, $latitude, $longitude);

        return $distance !== null && $distance <= $depot->service_radius_m;
    }
}
