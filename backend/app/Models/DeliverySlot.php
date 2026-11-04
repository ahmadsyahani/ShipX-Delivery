<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DeliverySlot extends Model
{
    protected $fillable = ['service_date', 'window_start_at', 'window_end_at', 'cutoff_at', 'is_active'];

    protected function casts(): array
    {
        return ['service_date' => 'date:Y-m-d', 'window_start_at' => 'immutable_datetime', 'window_end_at' => 'immutable_datetime', 'cutoff_at' => 'immutable_datetime', 'is_active' => 'boolean', 'lock_version' => 'integer'];
    }
}
