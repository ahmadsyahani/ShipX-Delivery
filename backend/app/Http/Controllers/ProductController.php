<?php

namespace App\Http\Controllers;

use App\Http\Requests\ProductRequest;
use App\Models\Product;
use App\Services\InventoryService;
use App\Services\ProductPhotoService;
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
        return Inertia::render('Admin/Products/Form', ['product' => null, 'categories' => $this->categories()]);
    }

    public function store(ProductRequest $request, ProductPhotoService $photos)
    {
        $product = new Product($request->safe()->except(['lock_version', 'photo', 'remove_photo']));
        $product->depot_id = 1;
        $product->calculateVolume();
        $newPath = null;
        try {
            DB::transaction(function () use ($request, $product, $photos, &$newPath) {
                $this->applyPhoto($request, $product, $photos, $newPath);
                $this->save($product);
                app(InventoryService::class)->ensureAccounts($product);
            });
        } catch (\Throwable $error) {
            $photos->discard($newPath);
            throw $error;
        }

        return redirect()->route('admin.products.index')->with('status', 'Produk ditambahkan.');
    }

    public function edit(Product $product)
    {
        abort_unless($product->depot_id === 1, 404);

        return Inertia::render('Admin/Products/Form', ['product' => $product, 'categories' => $this->categories()]);
    }

    private function categories(): array
    {
        return collect(['Minuman', 'Makanan', 'Kebutuhan Rumah Tangga', 'Perawatan Diri', 'Lainnya'])
            ->merge(Product::where('depot_id', 1)->distinct()->pluck('category'))
            ->unique()->sort(SORT_NATURAL | SORT_FLAG_CASE)->values()->all();
    }

    public function update(ProductRequest $request, Product $product, ProductPhotoService $photos)
    {
        $newPath = null;
        try {
            return DB::transaction(function () use ($request, $product, $photos, &$newPath) {
                $product = Product::where('depot_id', 1)->lockForUpdate()->findOrFail($product->id);
                if ($product->lock_version !== (int) $request->validated('lock_version')) {
                    return Inertia::render('Admin/Conflict', ['message' => 'Produk telah diperbarui pengguna lain. Muat produk terbaru sebelum mengedit kembali.', 'reloadUrl' => route('admin.products.edit', $product)])->toResponse($request)->setStatusCode(409);
                }
                $product->fill($request->safe()->except(['lock_version', 'photo', 'remove_photo']));
                $product->calculateVolume();
                $product->lock_version++;
                $this->applyPhoto($request, $product, $photos, $newPath);
                $this->save($product);

                return redirect()->route('admin.products.index')->with('status', 'Perubahan produk disimpan.');
            });
        } catch (\Throwable $error) {
            $photos->discard($newPath);
            throw $error;
        }
    }

    private function applyPhoto(ProductRequest $request, Product $product, ProductPhotoService $photos, ?string &$newPath): void
    {
        if ($request->hasFile('photo') && $request->boolean('remove_photo')) {
            throw ValidationException::withMessages(['photo' => 'Pilih foto baru atau hapus foto yang ada.']);
        }
        if (! $request->hasFile('photo') && ! $request->boolean('remove_photo')) {
            return;
        }
        $oldPath = $product->photo_path;
        $newPath = $request->hasFile('photo') ? $photos->store($request->file('photo')) : null;
        $product->photo_path = $newPath;
        if ($oldPath) {
            DB::afterCommit(fn () => $photos->discard($oldPath));
        }
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
