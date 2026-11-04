<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Order extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return ['subtotal_rp' => 'integer', 'delivery_fee_rp' => 'integer', 'total_rp' => 'integer', 'total_weight_g' => 'integer', 'total_volume_cm3' => 'integer', 'lock_version' => 'integer', 'latitude' => 'float', 'longitude' => 'float', 'pending_expires_at' => 'immutable_datetime', 'window_start_at' => 'immutable_datetime', 'window_end_at' => 'immutable_datetime', 'confirmed_at' => 'immutable_datetime', 'cancelled_at' => 'immutable_datetime', 'closed_at' => 'immutable_datetime'];
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    public function decision(): HasOne
    {
        return $this->hasOne(OrderDecision::class);
    }
}
