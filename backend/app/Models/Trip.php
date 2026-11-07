<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Trip extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return ['planned_departure_at' => 'immutable_datetime', 'actual_departure_at' => 'immutable_datetime', 'actual_return_at' => 'immutable_datetime', 'lock_version' => 'integer', 'capacity_weight_g_snapshot' => 'integer', 'capacity_volume_cm3_snapshot' => 'integer', 'planned_weight_g' => 'integer', 'planned_volume_cm3' => 'integer', 'loaded_weight_g' => 'integer', 'loaded_volume_cm3' => 'integer'];
    }

    public function selectedRoute(): BelongsTo
    {
        return $this->belongsTo(RouteVersion::class, 'selected_route_version_id');
    }

    public function routes(): HasMany
    {
        return $this->hasMany(RouteVersion::class)->orderByDesc('version_number');
    }
}
