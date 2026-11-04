<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class AdminOrderDecisionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user('web')?->role === 'admin' && $this->user('web')->is_active;
    }

    public function rules(): array
    {
        return [
            'idempotency_key' => ['required', 'uuid'],
            'lock_version' => ['required', 'integer', 'min:0'],
            'reason' => $this->routeIs('admin.orders.reject') ? ['required', 'string', 'max:500'] : ['missing'],
            'admin_id' => ['missing'], 'status' => ['missing'], 'decided_at' => ['missing'],
        ];
    }
}
