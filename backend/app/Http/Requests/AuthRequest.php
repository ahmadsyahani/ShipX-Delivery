<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class AuthRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        if (is_string($this->email)) {
            $this->merge(['email' => mb_strtolower(trim($this->email))]);
        }
    }

    public function rules(): array
    {
        $register = $this->routeIs('api.register');

        return [
            'email' => ['required', 'string', 'email', 'max:255', ...($register ? ['unique:users,email'] : [])],
            'password' => ['required', 'string', 'max:1024', ...($register ? ['min:12', 'confirmed'] : [])],
            'device_name' => ['required', 'string', 'max:100'],
            'role' => ['missing'],
            'is_active' => ['missing'],
            ...($register ? ['name' => ['required', 'string', 'max:255'], 'phone' => ['required', 'string', 'max:30']] : []),
        ];
    }
}
