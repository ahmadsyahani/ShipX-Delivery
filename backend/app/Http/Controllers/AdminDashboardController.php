<?php

namespace App\Http\Controllers;

use App\Models\DeliverySlot;
use App\Models\Depot;
use App\Models\Order;
use App\Models\Product;
use App\Models\Trip;
use App\Services\OrderLifecycleService;
use Illuminate\Support\Facades\DB;
use Inertia\Inertia;

class AdminDashboardController extends Controller
{
    public function __invoke(OrderLifecycleService $lifecycle)
    {
        $lifecycle->expireAllDue();
        $depot = Depot::findOrFail(1);
        $localDay = now($depot->timezone)->startOfDay();
        $day = $localDay->copy()->utc();
        $dayEnd = $localDay->copy()->addDay()->utc();
        $unsettled = DB::table('payment_collections')->join('delivery_results', 'delivery_results.id', '=', 'payment_collections.delivery_result_id')
            ->join('trip_stops', 'trip_stops.id', '=', 'delivery_results.trip_stop_id')->join('trips', 'trips.id', '=', 'trip_stops.trip_id')
            ->where('trips.depot_id', 1)->whereIn('trips.status', ['in_progress', 'awaiting_reconciliation'])->sum('payment_collections.amount_rp');

        return Inertia::render('Admin/Dashboard', [
            'depot' => ['name' => $depot->name, 'configured' => $depot->configured(), 'timezone' => $depot->timezone],
            'stats' => [
                'active_trips' => Trip::where('depot_id', 1)->whereIn('status', ['assigned', 'in_progress', 'awaiting_reconciliation'])->count(),
                'late_orders' => Order::where('depot_id', 1)->whereIn('status', ['confirmed', 'assigned', 'out_for_delivery'])->where('window_end_at', '<', now())->count(),
                'failed_today' => DB::table('delivery_results')->join('orders', 'orders.id', '=', 'delivery_results.order_id')->where('orders.depot_id', 1)->where('delivery_results.outcome', 'failed')->where('recorded_at', '>=', $day)->where('recorded_at', '<', $dayEnd)->count(),
                'unsettled_cod_rp' => (int) $unsettled,
                'products' => Product::where('depot_id', 1)->where('is_active', true)->count(),
                'pending' => Order::where('depot_id', 1)->where('status', 'pending')->count(),
                'confirmed' => Order::where('depot_id', 1)->where('status', 'confirmed')->count(),
                'open_slots' => DeliverySlot::where('depot_id', 1)->where('is_active', true)->where('cutoff_at', '>', now())->count(),
            ],
            'recentOrders' => Order::where('depot_id', 1)->orderByDesc('id')->limit(5)->get(['id', 'order_number', 'recipient_name', 'status', 'total_rp', 'created_at']),
        ]);
    }
}
