<?php

namespace App\Http\Controllers;

use App\Http\Requests\ProductRequest;
use App\Models\Product;
use App\Services\InventoryService;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $filters = $request->validate(['q' => ['nullable', 'string', 'max:100'], 'status' => ['nullable', 'in:active,inactive'], 'page' => ['sometimes', 'integer', 'min:1']]);
        $query = Product::where('depot_id', 1);
        if ($q = $filters['q'] ?? null) {
            $query->where(fn ($builder) => $builder->where('name', 'like', '%'.$q.'%')->orWhere('sku', 'like', '%'.$q.'%'));
        }
        if ($status = $filters['status'] ?? null) {
            $query->where('is_active', $status === 'active');
        }

        return Inertia::render('Admin/Products/Index', [
            'filters' => ['q' => $filters['q'] ?? '', 'status' => $filters['status'] ?? ''],
            'products' => $query->orderBy('name')->orderBy('id')->paginate(15)->withQueryString(),
            'total' => Product::where('depot_id', 1)->count(),
            'active' => Product::where('depot_id', 1)->where('is_active', true)->count(),
        ]);
    }

    public function create()
    {
        return Inertia::render('Admin/Products/Form', ['product' => null]);
    }

    public function store(ProductRequest $request)
    {
        $product = new Product($request->safe()->except('lock_version'));
        $product->depot_id = 1;
        $product->calculateVolume();
        DB::transaction(function () use ($product) {
            $this->save($product);
            app(InventoryService::class)->ensureAccounts($product);
        });

        return redirect()->route('admin.products.index')->with('status', 'Produk ditambahkan.');
    }

    public function edit(Product $product)
    {
        abort_unless($product->depot_id === 1, 404);

        return Inertia::render('Admin/Products/Form', compact('product'));
    }

    public function update(ProductRequest $request, Product $product)
    {
        return DB::transaction(function () use ($request, $product) {
            $product = Product::where('depot_id', 1)->lockForUpdate()->findOrFail($product->id);
            if ($product->lock_version !== (int) $request->validated('lock_version')) {
                return Inertia::render('Admin/Conflict', ['message' => 'Produk telah diperbarui pengguna lain. Muat produk terbaru sebelum mengedit kembali.', 'reloadUrl' => route('admin.products.edit', $product)])->toResponse($request)->setStatusCode(409);
            }
            $product->fill($request->safe()->except('lock_version'));
            $product->calculateVolume();
            $product->lock_version++;
            $this->save($product);

            return redirect()->route('admin.products.index')->with('status', 'Perubahan produk disimpan.');
        });
    }

    private function save(Product $product): void
    {
        try {
            $product->save();
        } catch (UniqueConstraintViolationException) {
            throw ValidationException::withMessages(['sku' => 'Kode SKU sudah digunakan. Gunakan kode lain.']);
        }
    }
}
