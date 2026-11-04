<?php

use App\Http\Middleware\EnsureActiveRole;
use App\Http\Middleware\HandleInertiaRequests;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Symfony\Component\HttpFoundation\Response;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->web(append: [HandleInertiaRequests::class]);
        $middleware->alias(['active.role' => EnsureActiveRole::class]);
        $middleware->redirectGuestsTo(fn () => route('login'));
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(fn (Request $request) => $request->is('api/*') || $request->expectsJson());
        $exceptions->respond(function (Response $response) {
            $request = request();
            if ($request->is('admin', 'admin/*') && $request->header('X-Inertia') && in_array($response->getStatusCode(), [403, 404, 419, 429, 500, 503], true)) {
                return Inertia::render('Admin/Error', ['status' => $response->getStatusCode()])->toResponse($request)->setStatusCode($response->getStatusCode());
            }

            return $response;
        });
    })->create();
