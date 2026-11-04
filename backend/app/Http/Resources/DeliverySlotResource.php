<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DeliverySlotResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['id' => (string) $this->id, 'service_date' => $this->service_date->format('Y-m-d'), 'window_start_at' => $this->window_start_at->toISOString(), 'window_end_at' => $this->window_end_at->toISOString(), 'cutoff_at' => $this->cutoff_at->toISOString()];
    }
}
