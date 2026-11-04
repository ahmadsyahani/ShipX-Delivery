<?php

namespace App\Http\Controllers;

use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;

class AdminSessionController extends Controller
{
    public function store(Request $request): RedirectResponse
    {
        $request->merge(['email' => is_string($request->email) ? mb_strtolower(trim($request->email)) : $request->email]);
        $credentials = $request->validate(['email' => ['required', 'email'], 'password' => ['required', 'string']]);
        if (! Auth::attempt([...$credentials, 'role' => 'admin', 'is_active' => true])) {
            throw ValidationException::withMessages(['email' => ['Email atau kata sandi tidak sesuai.']]);
        }
        $request->session()->regenerate();
        Inertia::clearHistory();

        return redirect()->route('admin.home');
    }

    public function destroy(Request $request): RedirectResponse
    {
        Auth::guard('web')->logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();
        Inertia::clearHistory();

        return redirect()->route('login');
    }
}
