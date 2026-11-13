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
        $filters = $request->validate(['q' => ['nullable', 'string', 'max:100'], 'category' => ['nullable', 'string', 'max:80'], 'collection' => ['sometimes', 'in:all,favorites,frequent'], 'grouped' => ['sometimes', 'boolean'], 'page' => ['sometimes', 'integer', 'min:1'], 'per_page' => ['sometimes', 'integer', 'min:1', 'max:100']]);
        $categories = Product::where('depot_id', 1)->where('is_active', true)->select('category')->distinct()->orderBy('category')->pluck('category');
        $products = app(InventoryService::class)->decorate(Product::where('depot_id', 1)->where('is_active', true));
        $favorites = DB::table('product_favorites')->where('user_id', $request->user()->id);
        $history = DB::table('order_items')->join('orders', 'orders.id', '=', 'order_items.order_id')
            ->where('orders.customer_id', $request->user()->id)
            ->whereIn('orders.status', ['pending', 'confirmed', 'assigned', 'out_for_delivery', 'delivered', 'failed'])
            ->whereColumn('order_items.product_id', 'products.id');
        $products->selectSub((clone $favorites)->whereColumn('product_id', 'products.id')->selectRaw('COUNT(*)'), 'is_favorite')
            ->selectSub((clone $history)->selectRaw('COUNT(*)'), 'customer_order_count');
        if (($filters['collection'] ?? 'all') === 'favorites') {
            $products->whereIn('products.id', (clone $favorites)->select('product_id'));
        }
        if ($request->boolean('grouped')) {
            $products->orderBy('products.category');
        }
        if (($filters['collection'] ?? 'all') === 'frequent') {
            $products->whereExists((clone $history)->selectRaw('1'))->orderByDesc('customer_order_count');
        }
        if ($q = $filters['q'] ?? null) {
            $products->where(fn ($builder) => $builder->where('name', 'like', '%'.$q.'%')->orWhere('category', 'like', '%'.$q.'%')->orWhere('sku', 'like', '%'.$q.'%'));
        }
        if (isset($filters['category']) && $filters['category'] !== '') {
            $products->where('category', $filters['category']);
        }

        if ($request->boolean('grouped')) {
            $categories = (clone $products)->reorder()->select('products.category')->distinct()->orderBy('products.category')->pluck('products.category');
        }

        return ProductResource::collection($products->orderBy('name')->orderBy('id')->paginate($filters['per_page'] ?? 20)->withQueryString())
            ->additional(['depot' => ['id' => '1', 'name' => DB::table('depots')->where('id', 1)->value('name')], 'categories' => $categories]);
    }
}
