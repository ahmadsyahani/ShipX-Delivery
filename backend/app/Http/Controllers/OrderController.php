<?php

namespace App\Http\Controllers;

use App\Exceptions\BusinessFailure;
use App\Http\Requests\CheckoutRequest;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\CheckoutService;
use App\Services\IdempotencyService;
use App\Services\OrderLifecycleService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class OrderController extends Controller
{
    public function __construct(private CheckoutService $checkout, private IdempotencyService $idempotency, private OrderLifecycleService $lifecycle) {}

    public function quote(CheckoutRequest $request)
    {
        $this->lifecycle->expireAllDue();
        try {
            return response()->json(['data' => $this->checkout->quote($request->user()->id, $request->payload())]);
        } catch (BusinessFailure $error) {
            return response()->json($error->body(), $error->status);
        }
    }

    public function store(CheckoutRequest $request)
    {
        $key = $this->key($request);
        $this->lifecycle->expireAllDue();
        $result = $this->idempotency->run($request->user()->id, 'orders.create', $key, $request->payload(), function () use ($request) {
            $order = $this->checkout->checkout($request->user()->id, $request->payload());

            return ['status' => 201, 'body' => ['data' => (new OrderResource($order))->resolve($request)]];
        });

        return response()->json($result['body'], $result['status']);
    }

    public function index(Request $request)
    {
        $data = $request->validate(['page' => ['sometimes', 'integer', 'min:1'], 'per_page' => ['sometimes', 'integer', 'min:1', 'max:100']]);
        $this->lifecycle->expireAllDue();

        return OrderResource::collection(Order::where('customer_id', $request->user()->id)->with('items')->orderByDesc('id')->paginate($data['per_page'] ?? 20)->withQueryString());
    }

    public function show(Request $request, string $order)
    {
        $this->lifecycle->expireAllDue();

        return new OrderResource(Order::where('customer_id', $request->user()->id)->with('items')->findOrFail($order));
    }

    public function cancel(Request $request, string $order)
    {
        $key = $this->key($request);
        $data = $request->validate(['lock_version' => ['required', 'integer', 'min:0'], 'reason' => ['required', 'string', 'max:500']]);
        $data['lock_version'] = (int) $data['lock_version'];
        $this->lifecycle->expireAllDue();
        $result = $this->idempotency->run($request->user()->id, 'orders.cancel:'.$order, $key, $data, function () use ($request, $order, $data) {
            $record = $this->lifecycle->cancel($request->user()->id, (int) $order, $data['lock_version'], $data['reason']);

            return ['status' => 200, 'body' => ['data' => (new OrderResource($record))->resolve($request)]];
        });

        return response()->json($result['body'], $result['status']);
    }

    private function key(Request $request): string
    {
        $data = Validator::make(['idempotency_key' => $request->header('Idempotency-Key')], ['idempotency_key' => ['required', 'uuid']])->validate();

        return strtolower($data['idempotency_key']);
    }
}
