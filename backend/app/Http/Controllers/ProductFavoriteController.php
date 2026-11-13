<?php

namespace App\Http\Controllers;

use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProductFavoriteController extends Controller
{
    public function __invoke(Request $request, Product $product)
    {
        abort_unless($product->depot_id === 1 && $product->is_active, 404);
        $data = $request->validate(['is_favorite' => ['required', 'boolean']]);
        $favorite = ['user_id' => $request->user()->id, 'product_id' => $product->id];
        if ($data['is_favorite']) {
            DB::table('product_favorites')->insertOrIgnore([...$favorite, 'created_at' => now(), 'updated_at' => now()]);
        } else {
            DB::table('product_favorites')->where($favorite)->delete();
        }

        return response()->json(['data' => ['product_id' => (string) $product->id, 'is_favorite' => (bool) $data['is_favorite']]]);
    }
}
