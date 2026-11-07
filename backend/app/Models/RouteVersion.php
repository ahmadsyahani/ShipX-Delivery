<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RouteVersion extends Model
{
    protected $guarded = [];

    protected function casts(): array
    {
        return ['input_snapshot' => 'array', 'selected_snapshot' => 'array', 'version_number' => 'integer'];
    }
}
