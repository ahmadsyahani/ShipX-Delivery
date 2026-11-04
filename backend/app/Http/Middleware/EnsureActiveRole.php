<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureActiveRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        abort_unless($request->user()?->is_active, 403, 'Akun tidak aktif.');
        abort_unless(in_array($request->user()->role, $roles ?: ['customer', 'courier', 'admin'], true), 403);

        return $next($request);
    }
}
