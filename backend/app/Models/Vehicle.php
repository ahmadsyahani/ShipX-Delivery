<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Vehicle extends Model
{
    protected $fillable = ['code', 'name', 'plate_number', 'travel_mode', 'max_load_weight_g', 'max_load_volume_cm3', 'is_active'];

    protected function casts(): array
    {
        return ['depot_id' => 'integer', 'max_load_weight_g' => 'integer', 'max_load_volume_cm3' => 'integer', 'is_active' => 'boolean', 'lock_version' => 'integer'];
    }
}
