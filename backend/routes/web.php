<?php

use App\Http\Controllers\AdminDashboardController;
use App\Http\Controllers\AdminDeliverySlotController;
use App\Http\Controllers\AdminOrderController;
use App\Http\Controllers\AdminSessionController;
use App\Http\Controllers\CourierController;
use App\Http\Controllers\DepotController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\StockController;
use App\Http\Controllers\VehicleController;
use Illuminate\Support\Facades\Route;
use Inertia\Inertia;

Route::get('/', function () {
    return redirect()->route('admin.home');
});

Route::get('/admin/login', fn () => Inertia::render('Admin/Login'))->name('login');
Route::get('/product-photos/{file}', [\App\Http\Controllers\ProductPhotoController::class, 'show'])->where('file', '[a-f0-9-]{36}\.(jpg|png|webp)')->name('product.photo');
Route::post('/admin/login', [AdminSessionController::class, 'store'])->middleware('throttle:login');
Route::middleware(['auth:web', 'active.role:admin'])->prefix('admin')->group(function (): void {
    Route::get('/', AdminDashboardController::class)->name('admin.home');
    Route::get('stock', [StockController::class, 'index'])->name('admin.stock.index');
    Route::get('stock/{product}', [StockController::class, 'edit'])->name('admin.stock.edit');
    Route::post('stock/{product}', [StockController::class, 'store'])->name('admin.stock.store');
    Route::get('orders', [AdminOrderController::class, 'index'])->name('admin.orders.index');
    Route::get('orders/{order}', [AdminOrderController::class, 'show'])->name('admin.orders.show');
    Route::post('orders/{order}/confirm', [AdminOrderController::class, 'confirm'])->name('admin.orders.confirm');
    Route::post('orders/{order}/reject', [AdminOrderController::class, 'reject'])->name('admin.orders.reject');
    Route::get('depot', [DepotController::class, 'edit'])->name('admin.depot.edit');
    Route::put('depot', [DepotController::class, 'update'])->name('admin.depot.update');
    Route::resource('slots', AdminDeliverySlotController::class)->parameters(['slots' => 'slot'])->only(['index', 'create', 'store', 'edit', 'update'])->names('admin.slots');
    Route::resource('products', ProductController::class)->only(['index', 'create', 'store', 'edit', 'update'])->names('admin.products');
    Route::resource('couriers', CourierController::class)->parameters(['couriers' => 'courier'])->only(['index', 'create', 'store', 'edit', 'update'])->names('admin.couriers');
    Route::resource('vehicles', VehicleController::class)->only(['index', 'create', 'store', 'edit', 'update'])->names('admin.vehicles');
    Route::post('/logout', [AdminSessionController::class, 'destroy'])->name('admin.logout');
    Route::get('delivery-proofs/{proof}', [\App\Http\Controllers\DeliveryProofController::class, 'show'])->whereNumber('proof');
    Route::resource('trips', \App\Http\Controllers\AdminTripController::class)->only(['index', 'create', 'store', 'show', 'edit', 'update'])->names('admin.trips');
    Route::post('trips/{trip}/{action}', [\App\Http\Controllers\AdminTripController::class, 'action'])->where('action', 'assign|reopen|cancel')->name('admin.trips.action');
    Route::post('trips/{trip}/departure-review', [\App\Http\Controllers\AdminTripController::class, 'review'])->name('admin.trips.review');
    Route::post('trips/{trip}/reconcile', [\App\Http\Controllers\AdminTripController::class, 'reconcile'])->name('admin.trips.reconcile');
});
