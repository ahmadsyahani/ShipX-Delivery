<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Services\IdempotencyService;
use App\Services\InventoryService;
use App\Services\OrderLifecycleService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Inertia\Inertia;

class StockController extends Controller
{
    public function __construct(private InventoryService $inventory, private OrderLifecycleService $lifecycle, private IdempotencyService $idempotency) {}

    public function index(Request $request)
    {
        $data = $request->validate(['q' => ['nullable', 'string', 'max:100'], 'page' => ['sometimes', 'integer', 'min:1']]);
        $this->lifecycle->expireAllDue();
        $products = Product::where('depot_id', 1);
        if ($q = $data['q'] ?? null) {
            $products->where(fn ($b) => $b->where('name', 'like', '%'.$q.'%')->orWhere('sku', 'like', '%'.$q.'%'));
        }

        return Inertia::render('Admin/Stock/Index', ['filters' => ['q' => $data['q'] ?? ''], 'products' => $this->inventory->decorate($products)->orderBy('name')->orderBy('id')->paginate(20)->withQueryString()]);
    }

    public function edit(Request $request, Product $product)
    {
        abort_unless((int) $product->depot_id === 1, 404);
        $this->lifecycle->expireAllDue();

        return Inertia::render('Admin/Stock/Form', ['product' => $this->inventory->decorate(Product::whereKey($product->id))->firstOrFail(), 'mutationKey' => Str::uuid()->toString(),
            'entries' => DB::table('inventory_entries')->join('inventory_accounts', 'inventory_accounts.id', '=', 'inventory_entries.inventory_account_id')->join('inventory_transactions', 'inventory_transactions.id', '=', 'inventory_entries.inventory_transaction_id')->where('inventory_accounts.product_id', $product->id)->where('inventory_accounts.depot_id', 1)->select('inventory_entries.quantity_delta', 'inventory_accounts.stock_state', 'inventory_transactions.kind', 'inventory_transactions.reason', 'inventory_transactions.created_at')->orderByDesc('inventory_entries.id')->paginate(20)]);
    }

    public function store(Request $request, Product $product)
    {
        abort_unless((int) $product->depot_id === 1, 404);
        $data = $request->validate(['idempotency_key' => ['required', 'uuid'], 'stock_state' => ['required', 'in:available,quarantine'], 'quantity_delta' => ['required', 'integer', 'between:-1000000,1000000', 'not_in:0'], 'reason' => ['required', 'string', 'max:500']]);
        $this->lifecycle->expireAllDue();
        $key = strtolower($data['idempotency_key']);
        $payload = ['product_id' => $product->id, 'stock_state' => $data['stock_state'], 'quantity_delta' => (int) $data['quantity_delta'], 'reason' => $data['reason']];
        $result = $this->idempotency->run($request->user()->id, 'stock.adjust', $key, $payload, fn () => $this->inventory->adjust($request->user()->id, $product->id, $payload['stock_state'], $payload['quantity_delta'], $payload['reason'], $key));
        if ($result['status'] !== 201) {
            return Inertia::render('Admin/Conflict', ['message' => $result['body']['message'], 'reloadUrl' => route('admin.stock.edit', $product)])->toResponse($request)->setStatusCode($result['status']);
        }

        return redirect()->route('admin.stock.edit', $product)->with('status', 'Mutasi stok tercatat. Saldo dan riwayat sudah diperbarui.');
    }
}
