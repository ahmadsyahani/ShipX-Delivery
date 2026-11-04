<?php

use App\Http\Controllers\AdminDashboardController;
use App\Http\Controllers\AdminDeliverySlotController;
use App\Http\Controllers\AdminOrderController;
use App\Http\Controllers\AdminSessionController;
use App\Http\Controllers\DepotController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\StockController;
use Illuminate\Support\Facades\Route;
use Inertia\Inertia;

Route::get('/', function () {
    return redirect()->route('admin.home');
});

Route::get('/admin/login', fn () => Inertia::render('Admin/Login'))->name('login');
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
    Route::post('/logout', [AdminSessionController::class, 'destroy'])->name('admin.logout');
});
