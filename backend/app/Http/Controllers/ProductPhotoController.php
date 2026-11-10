<?php

namespace App\Http\Controllers;

use App\Models\Product;
use Illuminate\Support\Facades\Storage;

class ProductPhotoController extends Controller
{
    public function show(string $file)
    {
        $path = 'product-photos/'.$file;
        Product::where('depot_id', 1)->where('photo_path', $path)->firstOrFail();
        abort_unless(Storage::disk('local')->exists($path), 404);
        $mime = match (pathinfo($file, PATHINFO_EXTENSION)) {
            'jpg' => 'image/jpeg',
            'png' => 'image/png',
            'webp' => 'image/webp',
        };

        return response()->file(Storage::disk('local')->path($path), [
            'Content-Type' => $mime,
            'X-Content-Type-Options' => 'nosniff',
            'Cache-Control' => 'public, max-age=86400, immutable',
        ]);
    }
}
