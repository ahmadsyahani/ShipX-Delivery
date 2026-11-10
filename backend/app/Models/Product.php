<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Product extends Model
{
    protected $fillable = ['sku', 'name', 'category', 'unit_label', 'unit_price_rp', 'shipping_weight_g', 'length_mm', 'width_mm', 'height_mm', 'handling_notes', 'is_active'];

    protected $hidden = ['photo_path'];

    protected $appends = ['photo_url'];

    public function getPhotoUrlAttribute(): ?string
    {
        return $this->photo_path ? '/product-photos/'.basename($this->photo_path) : null;
    }

    protected function casts(): array
    {
        return ['depot_id' => 'integer', 'is_active' => 'boolean', 'unit_price_rp' => 'integer', 'shipping_weight_g' => 'integer', 'shipping_volume_cm3' => 'integer', 'length_mm' => 'integer', 'width_mm' => 'integer', 'height_mm' => 'integer', 'lock_version' => 'integer'];
    }

    public function calculateVolume(): void
    {
        $this->shipping_volume_cm3 = intdiv($this->length_mm * $this->width_mm * $this->height_mm + 999, 1000);
    }
}
