<?php

namespace App\Http\Resources;

use App\Models\Depot;
use App\Services\DeliveryArea;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AddressResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $depot = $request->attributes->get('delivery_depot') ?? Depot::findOrFail(1);
        $area = app(DeliveryArea::class);

        return ['id' => (string) $this->id, 'label' => $this->label, 'recipient_name' => $this->recipient_name, 'phone' => $this->phone, 'address_text' => $this->address_text, 'latitude' => $this->latitude, 'longitude' => $this->longitude, 'directions' => $this->directions, 'lock_version' => $this->lock_version, 'within_service_area' => $area->contains($depot, $this->latitude, $this->longitude)];
    }
}
