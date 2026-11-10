<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InventoryAccount extends Model
{
    protected $guarded = [];

    public function product(): \Illuminate\Database\Eloquent\Relations\BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    protected function casts(): array
    {
        return ['balance_quantity' => 'integer', 'lock_version' => 'integer', 'trip_id' => 'integer'];
    }
}
