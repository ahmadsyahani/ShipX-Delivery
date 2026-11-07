<?php

namespace App\Services;

use App\Models\Trip;

class TripManifestService
{
    public function forTrip(Trip $trip): array
    {
        $groups = [];
        foreach ($trip->selectedRoute->input_snapshot['orders'] as $order) {
            foreach ($order['items'] as $item) {
                $id = (string) $item['product_id'];
                $groups[$id] ??= ['product_id' => $id, 'quantity' => 0, 'weight_g' => 0, 'volume_cm3' => 0, 'variants' => []];
                $groups[$id]['quantity'] += $item['quantity'];
                $groups[$id]['weight_g'] += $item['quantity'] * $item['unit_weight_g'];
                $groups[$id]['volume_cm3'] += $item['quantity'] * $item['unit_volume_cm3'];
                // Preserve differing historical packaging/labels of the same SKU.
                $groups[$id]['variants'][] = ['order_number' => $order['order_number'], 'name' => $item['name'], 'unit_label' => $item['unit_label'], 'quantity' => $item['quantity'], 'length_mm' => $item['length_mm'], 'width_mm' => $item['width_mm'], 'height_mm' => $item['height_mm'], 'handling_notes' => $item['handling_notes']];
            }
        }
        ksort($groups, SORT_NUMERIC);

        return array_values($groups);
    }
}
