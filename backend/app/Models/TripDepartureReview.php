<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class TripDepartureReview extends Model
{
    public $timestamps = false;

    protected $guarded = [];

    protected function casts(): array
    {
        return ['trip_version' => 'integer', 'handling_checked' => 'boolean', 'leg_seconds' => 'array', 'schedule_snapshot' => 'array', 'master_versions' => 'array', 'reviewed_at' => 'immutable_datetime', 'expires_at' => 'immutable_datetime'];
    }
}
