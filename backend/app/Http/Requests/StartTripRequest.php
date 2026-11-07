<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Facades\Validator;

class StartTripRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->role === 'courier' && $this->user()->is_active;
    }

    public function rules(): array
    {
        return [
            'lock_version' => ['required', 'integer', 'min:0'],
            'route_version_id' => ['required', 'integer', 'min:1'],
            'departure_review_id' => ['required', 'integer', 'min:1'],
            'manifest' => ['required', 'array', 'min:1', 'max:400'],
            'manifest.*' => ['required', 'array:product_id,quantity'],
            'manifest.*.product_id' => ['required', 'integer', 'min:1', 'distinct'],
            'manifest.*.quantity' => ['required', 'integer', 'min:1', 'max:400'],
            'courier_id' => ['missing'], 'status' => ['missing'], 'actual_departure_at' => ['missing'], 'depot_id' => ['missing'],
        ];
    }

    public function idempotencyKey(): string
    {
        $data = Validator::make(['key' => $this->header('Idempotency-Key')], ['key' => ['required', 'uuid']])->validate();

        return strtolower($data['key']);
    }

    public function payload(): array
    {
        $data = $this->validated();
        $manifest = array_map(fn ($row) => ['product_id' => (int) $row['product_id'], 'quantity' => (int) $row['quantity']], $data['manifest']);
        usort($manifest, fn ($a, $b) => $a['product_id'] <=> $b['product_id']);

        return ['lock_version' => (int) $data['lock_version'], 'route_version_id' => (int) $data['route_version_id'], 'departure_review_id' => (int) $data['departure_review_id'], 'manifest' => $manifest];
    }
}
