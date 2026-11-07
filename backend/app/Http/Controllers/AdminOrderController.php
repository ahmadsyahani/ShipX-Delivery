<?php

namespace App\Http\Controllers;

use App\Http\Requests\AdminOrderDecisionRequest;
use App\Models\Order;
use App\Services\DeliveryResultView;
use App\Services\IdempotencyService;
use App\Services\OrderLifecycleService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Inertia\Inertia;

class AdminOrderController extends Controller
{
    public function index(Request $request, OrderLifecycleService $lifecycle)
    {
        $data = $request->validate(['status' => ['nullable', 'in:pending,confirmed,assigned,out_for_delivery,delivered,failed,rejected,cancelled'], 'page' => ['sometimes', 'integer', 'min:1']]);
        $lifecycle->expireAllDue();
        $orders = Order::where('depot_id', 1);
        if ($status = $data['status'] ?? null) {
            $orders->where('status', $status);
        }

        return Inertia::render('Admin/Orders/Index', ['filters' => ['status' => $data['status'] ?? ''], 'orders' => $orders->orderByDesc('id')->paginate(20)->withQueryString()]);
    }

    public function show(Order $order, OrderLifecycleService $lifecycle)
    {
        abort_unless((int) $order->depot_id === 1, 404);
        $lifecycle->expireAllDue();

        return Inertia::render('Admin/Orders/Show', ['order' => $order->refresh()->load(['items', 'decision.admin:id,name']), 'deliveryResult' => app(DeliveryResultView::class)->forOrder($order->id, true), 'tripId' => DB::table('active_order_allocations')->where('order_id', $order->id)->value('trip_id'), 'decisionKeys' => ['confirm' => Str::uuid()->toString(), 'reject' => Str::uuid()->toString()]]);
    }

    public function confirm(AdminOrderDecisionRequest $request, Order $order, OrderLifecycleService $lifecycle, IdempotencyService $idempotency)
    {
        return $this->decide($request, $order, 'confirmed', $lifecycle, $idempotency);
    }

    public function reject(AdminOrderDecisionRequest $request, Order $order, OrderLifecycleService $lifecycle, IdempotencyService $idempotency)
    {
        return $this->decide($request, $order, 'rejected', $lifecycle, $idempotency);
    }

    private function decide(AdminOrderDecisionRequest $request, Order $order, string $decision, OrderLifecycleService $lifecycle, IdempotencyService $idempotency)
    {
        abort_unless((int) $order->depot_id === 1, 404);
        $payload = ['lock_version' => (int) $request->validated('lock_version')];
        if ($decision === 'rejected') {
            $payload['reason'] = $request->validated('reason');
        }
        $result = $idempotency->run($request->user('web')->id, 'orders.'.$decision.':'.$order->id, strtolower($request->validated('idempotency_key')), $payload,
            fn () => $lifecycle->decide($request->user('web')->id, $order->id, $payload['lock_version'], $decision, $payload['reason'] ?? null));
        if ($result['status'] !== 200) {
            return Inertia::render('Admin/Conflict', ['message' => $result['body']['message'], 'reloadUrl' => route('admin.orders.show', $order)])->toResponse($request)->setStatusCode($result['status']);
        }

        return redirect()->route('admin.orders.show', $order)->with('status', $decision === 'confirmed' ? 'Pesanan dikonfirmasi. Reservasi stok tetap ditahan untuk pengiriman.' : 'Pesanan ditolak. Reservasi stok sudah dilepas.');
    }
}
