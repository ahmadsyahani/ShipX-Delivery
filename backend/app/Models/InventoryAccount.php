<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InventoryAccount extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return ['balance_quantity' => 'integer', 'lock_version' => 'integer', 'trip_id' => 'integer'];
    }
}
