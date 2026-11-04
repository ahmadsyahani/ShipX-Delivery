<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Address extends Model
{
    protected $fillable = ['label', 'recipient_name', 'phone', 'address_text', 'latitude', 'longitude', 'directions'];

    protected function casts(): array
    {
        return ['latitude' => 'float', 'longitude' => 'float', 'is_active' => 'boolean', 'lock_version' => 'integer'];
    }
}
