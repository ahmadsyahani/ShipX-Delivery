<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DepotResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['delivery_per_km_rp' => $this->delivery_per_km_rp, 'express_extra_percent' => $this->express_extra_percent, 'delivery_prep_minutes' => $this->delivery_prep_minutes, 'delivery_speed_kmh' => $this->delivery_speed_kmh, 'server_time' => now()->toISOString(), 'id' => (string) $this->id, 'name' => $this->name, 'configured' => $this->resource->configured(), 'address_text' => $this->address_text, 'latitude' => $this->latitude, 'longitude' => $this->longitude, 'timezone' => $this->timezone, 'service_radius_m' => $this->service_radius_m, 'delivery_fee_rp' => $this->delivery_fee_rp, 'today' => now($this->timezone)->toDateString()];
    }
}
