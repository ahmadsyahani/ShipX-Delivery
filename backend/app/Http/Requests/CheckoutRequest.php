<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CheckoutRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->role === 'customer' && $this->user()->is_active;
    }

    public function rules(): array
    {
        return ['address_id' => ['required', 'integer', 'min:1'], 'delivery_slot_id' => ['required', 'integer', 'min:1'], 'items' => ['required', 'array', 'min:1', 'max:20'], 'items.*' => ['required', 'array:product_id,quantity'], 'items.*.product_id' => ['required', 'integer', 'min:1', 'distinct'], 'items.*.quantity' => ['required', 'integer', 'min:1', 'max:20'], 'expected_total_rp' => [$this->routeIs('api.orders.store') ? 'required' : 'prohibited', 'integer', 'min:0'], 'customer_id' => ['missing'], 'depot_id' => ['missing']];
    }

    public function payload(): array
    {
        $data = $this->validated();
        $items = array_map(fn ($item) => ['product_id' => (int) $item['product_id'], 'quantity' => (int) $item['quantity']], $data['items']);
        usort($items, fn ($a, $b) => $a['product_id'] <=> $b['product_id']);

        return ['address_id' => (int) $data['address_id'], 'delivery_slot_id' => (int) $data['delivery_slot_id'], 'items' => $items, ...(isset($data['expected_total_rp']) ? ['expected_total_rp' => (int) $data['expected_total_rp']] : [])];
    }
}
