<?php

use App\Http\Controllers\AddressController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\CatalogController;
use App\Http\Controllers\DeliverySettingsController;
use App\Http\Controllers\OrderController;
use App\Http\Resources\UserResource;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:register')->name('api.register');
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:login');
    Route::middleware(['auth:sanctum', 'active.role'])->group(function (): void {
        Route::get('/catalog', CatalogController::class)->middleware('active.role:customer');
        Route::middleware('active.role:customer')->group(function (): void {
            Route::post('/order-quotes', [OrderController::class, 'quote']);
            Route::post('/orders', [OrderController::class, 'store'])->name('api.orders.store');
            Route::get('/orders', [OrderController::class, 'index']);
            Route::get('/orders/{order}', [OrderController::class, 'show'])->whereNumber('order');
            Route::post('/orders/{order}/cancel', [OrderController::class, 'cancel'])->whereNumber('order');
            Route::get('/delivery-settings', [DeliverySettingsController::class, 'show']);
            Route::get('/delivery-slots', [DeliverySettingsController::class, 'slots']);
            Route::apiResource('addresses', AddressController::class)->only(['index', 'store', 'update', 'destroy']);
        });
        Route::get('/me', fn (Request $request) => new UserResource($request->user()));
        Route::get('/delivery-proofs/{proof}', [\App\Http\Controllers\DeliveryProofController::class, 'show'])->whereNumber('proof');
        Route::middleware('active.role:courier')->prefix('courier')->group(function (): void {
            Route::get('trips', [\App\Http\Controllers\CourierTripController::class, 'index']);
            Route::get('trips/{id}', [\App\Http\Controllers\CourierTripController::class, 'show'])->whereNumber('id');
            Route::post('trips/{id}/start', [\App\Http\Controllers\CourierTripController::class, 'start'])->whereNumber('id');
            Route::post('trips/{id}/stops/{stop}/proofs', [\App\Http\Controllers\DeliveryProofController::class, 'store'])->whereNumber(['id', 'stop']);
            Route::post('trips/{id}/stops/{stop}/result', [\App\Http\Controllers\DeliveryResultController::class, 'store'])->whereNumber(['id', 'stop']);
        });
        Route::delete('/auth/token', [AuthController::class, 'logout']);
    });
    Route::get('/health', fn () => response()->json([
        'data' => [
            'service' => 'shipx-api',
            'status' => 'ok',
            'api_version' => 'v1',
        ],
    ]));
});
