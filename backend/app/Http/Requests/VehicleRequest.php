<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class VehicleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user('web')?->role === 'admin' && $this->user('web')->is_active;
    }

    protected function prepareForValidation(): void
    {
        if (is_string($this->code)) {
            $this->merge(['code' => strtoupper(trim($this->code))]);
        }
        if (is_string($this->plate_number)) {
            $this->merge(['plate_number' => strtoupper(preg_replace('/[\s-]+/u', '', $this->plate_number))]);
        }
    }

    public function rules(): array
    {
        return [
            'code' => ['required', 'string', 'max:64', 'regex:/^[A-Z0-9][A-Z0-9._-]*$/', Rule::unique('vehicles')->where('depot_id', 1)->ignore($this->route('vehicle'))],
            'name' => ['required', 'string', 'max:160'],
            'plate_number' => ['required', 'string', 'min:3', 'max:16', 'regex:/^[A-Z0-9]+$/', Rule::unique('vehicles')->where('depot_id', 1)->ignore($this->route('vehicle'))],
            'travel_mode' => ['required', 'in:motorcycle,car'],
            'max_load_weight_g' => ['required', 'integer', 'min:1', 'max:1000000000'],
            'max_load_volume_cm3' => ['required', 'integer', 'min:1', 'max:1000000000000'],
            'is_active' => ['required', 'boolean'],
            'lock_version' => [$this->route('vehicle') ? 'required' : 'sometimes', 'integer', 'min:0'],
            'depot_id' => ['missing'],
        ];
    }
}
