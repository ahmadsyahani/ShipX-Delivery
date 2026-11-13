<?php

namespace App\Http\Resources;

use App\Services\DeliveryResultView;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return ['delivery_type' => $this->delivery_type ?? 'regular', 'delivery_distance_m' => $this->delivery_distance_m, 'delivery_result' => in_array($this->status, ['delivered', 'failed'], true) ? app(DeliveryResultView::class)->forOrder($this->id) : null, 'id' => (string) $this->id, 'order_number' => $this->order_number, 'status' => $this->status, 'payment_status' => $this->payment_status, 'lock_version' => $this->lock_version, 'timezone' => $this->timezone_snapshot, 'confirmed_at' => $this->confirmed_at?->toISOString(), 'closed_at' => $this->closed_at?->toISOString(),
            'items' => $this->items->map(fn ($i) => ['id' => (string) $i->id, 'product_id' => (string) $i->product_id, 'name' => $i->product_name_snapshot, 'unit_label' => $i->unit_label_snapshot, 'quantity' => $i->quantity, 'unit_price_rp' => $i->unit_price_rp, 'line_total_rp' => $i->line_total_rp, 'unit_weight_g' => $i->unit_weight_g, 'unit_volume_cm3' => $i->unit_volume_cm3, 'length_mm' => $i->length_mm_snapshot, 'width_mm' => $i->width_mm_snapshot, 'height_mm' => $i->height_mm_snapshot, 'handling_notes' => $i->handling_notes_snapshot]),
            'address' => ['recipient_name' => $this->recipient_name, 'phone' => $this->recipient_phone, 'address_text' => $this->address_text, 'latitude' => $this->latitude, 'longitude' => $this->longitude, 'directions' => $this->directions],
            'subtotal_rp' => $this->subtotal_rp, 'delivery_fee_rp' => $this->delivery_fee_rp, 'total_rp' => $this->total_rp, 'total_weight_g' => $this->total_weight_g, 'total_volume_cm3' => $this->total_volume_cm3, 'window_start_at' => $this->window_start_at->toISOString(), 'window_end_at' => $this->window_end_at->toISOString(), 'pending_expires_at' => $this->pending_expires_at->toISOString(), 'estimated_arrival_at' => null, 'status_reason' => $this->status_reason, 'created_at' => $this->created_at->toISOString()];
    }
}
