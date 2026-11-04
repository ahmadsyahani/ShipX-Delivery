<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->role === 'admin' && $this->user()->is_active;
    }

    protected function prepareForValidation(): void
    {
        if (is_string($this->sku)) {
            $this->merge(['sku' => strtoupper(trim($this->sku))]);
        }
    }

    public function rules(): array
    {
        return [
            'sku' => ['required', 'string', 'max:64', 'regex:/^[A-Z0-9][A-Z0-9._-]*$/', Rule::unique('products')->where('depot_id', 1)->ignore($this->route('product'))],
            'name' => ['required', 'string', 'max:160'],
            'category' => ['required', 'string', 'max:80'],
            'unit_label' => ['required', 'string', 'max:30'],
            'unit_price_rp' => ['required', 'integer', 'min:1', 'max:1000000000'],
            'shipping_weight_g' => ['required', 'integer', 'min:1', 'max:1000000'],
            'length_mm' => ['required', 'integer', 'min:1', 'max:10000'],
            'width_mm' => ['required', 'integer', 'min:1', 'max:10000'],
            'height_mm' => ['required', 'integer', 'min:1', 'max:10000'],
            'handling_notes' => ['nullable', 'string', 'max:1000'],
            'is_active' => ['required', 'boolean'],
            'lock_version' => [$this->route('product') ? 'required' : 'sometimes', 'integer', 'min:0'],
            'depot_id' => ['missing'],
            'shipping_volume_cm3' => ['missing'],
        ];
    }

    public function attributes(): array
    {
        return ['sku' => 'kode SKU', 'name' => 'nama produk', 'category' => 'kategori', 'unit_label' => 'satuan', 'unit_price_rp' => 'harga', 'shipping_weight_g' => 'berat', 'length_mm' => 'panjang', 'width_mm' => 'lebar', 'height_mm' => 'tinggi'];
    }
}
