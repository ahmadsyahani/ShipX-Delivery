<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CourierRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user('web')?->role === 'admin' && $this->user('web')->is_active;
    }

    protected function prepareForValidation(): void
    {
        if (is_string($this->email)) {
            $this->merge(['email' => mb_strtolower(trim($this->email))]);
        }
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', Rule::unique('users')->ignore($this->route('courier'))],
            'phone' => ['required', 'string', 'max:30'],
            'password' => [$this->route('courier') ? 'nullable' : 'required', 'string', 'min:12', 'max:1024', 'confirmed'],
            'password_confirmation' => ['nullable', 'string', 'max:1024'],
            'is_active' => ['required', 'boolean'],
            'lock_version' => [$this->route('courier') ? 'required' : 'sometimes', 'integer', 'min:0'],
            'role' => ['missing'], 'depot_id' => ['missing'], 'remember_token' => ['missing'], 'email_verified_at' => ['missing'],
        ];
    }
}
