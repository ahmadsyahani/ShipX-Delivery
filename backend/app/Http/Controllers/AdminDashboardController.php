<?php

namespace App\Http\Controllers;

use App\Models\DeliverySlot;
use App\Models\Depot;
use App\Models\Order;
use App\Models\Product;
use App\Services\OrderLifecycleService;
use Inertia\Inertia;

class AdminDashboardController extends Controller
{
    public function __invoke(OrderLifecycleService $lifecycle)
    {
        $lifecycle->expireAllDue();
        $depot = Depot::findOrFail(1);

        return Inertia::render('Admin/Dashboard', [
            'depot' => ['name' => $depot->name, 'configured' => $depot->configured(), 'timezone' => $depot->timezone],
            'stats' => [
                'products' => Product::where('depot_id', 1)->where('is_active', true)->count(),
                'pending' => Order::where('depot_id', 1)->where('status', 'pending')->count(),
                'confirmed' => Order::where('depot_id', 1)->where('status', 'confirmed')->count(),
                'open_slots' => DeliverySlot::where('depot_id', 1)->where('is_active', true)->where('cutoff_at', '>', now())->count(),
            ],
            'recentOrders' => Order::where('depot_id', 1)->orderByDesc('id')->limit(5)->get(['id', 'order_number', 'recipient_name', 'status', 'total_rp', 'created_at']),
        ]);
    }
}
