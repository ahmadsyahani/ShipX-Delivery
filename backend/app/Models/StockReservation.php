<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class StockReservation extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return ['quantity' => 'integer', 'released_at' => 'immutable_datetime', 'consumed_at' => 'immutable_datetime'];
    }
}
