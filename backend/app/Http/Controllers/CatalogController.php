<?php

namespace App\Http\Controllers;

use App\Http\Resources\ProductResource;
use App\Models\Product;
use App\Services\InventoryService;
use App\Services\OrderLifecycleService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CatalogController extends Controller
{
    public function __invoke(Request $request)
    {
        app(OrderLifecycleService::class)->expireAllDue();
        $filters = $request->validate(['q' => ['nullable', 'string', 'max:100'], 'page' => ['sometimes', 'integer', 'min:1'], 'per_page' => ['sometimes', 'integer', 'min:1', 'max:100']]);
        $products = app(InventoryService::class)->decorate(Product::where('depot_id', 1)->where('is_active', true));
        if ($q = $filters['q'] ?? null) {
            $products->where(fn ($builder) => $builder->where('name', 'like', '%'.$q.'%')->orWhere('category', 'like', '%'.$q.'%')->orWhere('sku', 'like', '%'.$q.'%'));
        }

        return ProductResource::collection($products->orderBy('name')->orderBy('id')->paginate($filters['per_page'] ?? 20)->withQueryString())
            ->additional(['depot' => ['id' => '1', 'name' => DB::table('depots')->where('id', 1)->value('name')]]);
    }
}
