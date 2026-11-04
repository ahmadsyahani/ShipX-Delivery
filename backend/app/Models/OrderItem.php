<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OrderItem extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return ['quantity' => 'integer', 'unit_price_rp' => 'integer', 'line_total_rp' => 'integer', 'unit_weight_g' => 'integer', 'unit_volume_cm3' => 'integer', 'length_mm_snapshot' => 'integer', 'width_mm_snapshot' => 'integer', 'height_mm_snapshot' => 'integer'];
    }
}
