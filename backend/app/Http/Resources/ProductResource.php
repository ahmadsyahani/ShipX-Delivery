<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'available_quantity' => max(0, (int) $this->physical_quantity - (int) $this->reserved_quantity),
            'id' => (string) $this->id, 'sku' => $this->sku, 'name' => $this->name,
            'category' => $this->category, 'unit_label' => $this->unit_label,
            'unit_price_rp' => $this->unit_price_rp, 'shipping_weight_g' => $this->shipping_weight_g,
            'shipping_volume_cm3' => $this->shipping_volume_cm3, 'length_mm' => $this->length_mm,
            'width_mm' => $this->width_mm, 'height_mm' => $this->height_mm,
            'handling_notes' => $this->handling_notes,
            'photo_url' => $this->photo_url,
        ];
    }
}
