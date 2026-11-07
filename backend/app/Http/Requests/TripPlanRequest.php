<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class TripPlanRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user('web')?->role === 'admin' && $this->user('web')->is_active;
    }

    public function rules(): array
    {
        return [
            'idempotency_key' => ['required', 'uuid'],
            'lock_version' => [$this->isMethod('POST') ? 'nullable' : 'required', 'integer', 'min:0'],
            'courier_id' => ['required', 'integer', 'min:1'],
            'vehicle_id' => ['required', 'integer', 'min:1'],
            'departure_local' => ['required', 'date_format:Y-m-d\TH:i'],
            'orders' => ['required', 'array', 'min:1', 'max:20'],
            'orders.*' => ['required', 'array:id,lock_version'],
            'orders.*.id' => ['required', 'integer', 'min:1', 'distinct'],
            'orders.*.lock_version' => ['required', 'integer', 'min:0'],
            'depot_id' => ['missing'], 'status' => ['missing'], 'created_by' => ['missing'],
            'selected_route_version_id' => ['missing'], 'planned_weight_g' => ['missing'], 'planned_volume_cm3' => ['missing'],
        ];
    }
}
