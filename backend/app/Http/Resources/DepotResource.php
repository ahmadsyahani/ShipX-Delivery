<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DepotResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['server_time' => now()->toISOString(), 'id' => (string) $this->id, 'name' => $this->name, 'configured' => $this->resource->configured(), 'address_text' => $this->address_text, 'latitude' => $this->latitude, 'longitude' => $this->longitude, 'timezone' => $this->timezone, 'service_radius_m' => $this->service_radius_m, 'delivery_fee_rp' => $this->delivery_fee_rp, 'today' => now($this->timezone)->toDateString()];
    }
}
