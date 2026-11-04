<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Depot extends Model
{
    protected $fillable = ['name', 'address_text', 'latitude', 'longitude', 'timezone', 'service_radius_m', 'delivery_fee_rp', 'pending_ttl_minutes', 'default_service_seconds'];

    protected function casts(): array
    {
        return ['latitude' => 'float', 'longitude' => 'float', 'service_radius_m' => 'integer', 'delivery_fee_rp' => 'integer', 'lock_version' => 'integer', 'pending_ttl_minutes' => 'integer', 'default_service_seconds' => 'integer'];
    }

    public function configured(): bool
    {
        return $this->latitude !== null && $this->longitude !== null && $this->service_radius_m > 0 && $this->delivery_fee_rp !== null && filled($this->address_text);
    }
}
