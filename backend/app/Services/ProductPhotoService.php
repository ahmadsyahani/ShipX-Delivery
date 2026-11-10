<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class ProductPhotoService
{
    public function store(UploadedFile $photo): string
    {
        $extension = match ($photo->getMimeType()) {
            'image/jpeg' => 'jpg',
            'image/png' => 'png',
            'image/webp' => 'webp',
            default => throw ValidationException::withMessages(['photo' => 'Gunakan foto JPG, PNG atau WebP.']),
        };
        $path = 'product-photos/'.Str::uuid()->toString().'.'.$extension;
        if (! Storage::disk('local')->putFileAs('product-photos', $photo, basename($path))) {
            $this->discard($path);
            throw ValidationException::withMessages(['photo' => 'Foto belum dapat disimpan. Coba lagi.']);
        }

        return $path;
    }

    public function discard(?string $path): void
    {
        if (! $path || ! preg_match('~^product-photos/[a-f0-9-]{36}\.(jpg|png|webp)$~D', $path)) {
            return;
        }
        try {
            Storage::disk('local')->delete($path);
        } catch (\Throwable $error) {
            // The new product state is already committed when replacing a photo.
            report($error);
        }
    }
}
