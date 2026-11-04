<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OrderDecision extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return ['decided_at' => 'immutable_datetime', 'order_version' => 'integer'];
    }

    public function admin(): BelongsTo
    {
        return $this->belongsTo(User::class, 'admin_id');
    }
}
