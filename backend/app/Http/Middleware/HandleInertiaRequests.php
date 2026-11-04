<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Inertia\Middleware;
use Symfony\Component\HttpFoundation\Response;

class HandleInertiaRequests extends Middleware
{
    protected $rootView = 'app';

    public function handle(Request $request, Closure $next): Response
    {
        $response = parent::handle($request, $next);
        if ($request->is('admin', 'admin/*')) {
            $response->headers->set('Cache-Control', 'no-store, private');
        }

        return $response;
    }

    public function share(Request $request): array
    {
        return [
            ...parent::share($request),
            'auth' => ['user' => fn () => $request->user('web')?->only('id', 'name', 'email', 'role')],
            'flash' => ['status' => fn () => $request->session()->get('status')],
        ];
    }
}
