<?php

namespace App\Http\Controllers;

use App\Http\Resources\DeliverySlotResource;
use App\Http\Resources\DepotResource;
use App\Models\DeliverySlot;
use App\Models\Depot;
use Illuminate\Http\Request;

class DeliverySettingsController extends Controller
{
    public function show()
    {
        return new DepotResource(Depot::findOrFail(1));
    }

    public function slots(Request $request)
    {
        $filters = $request->validate(['address_id' => ['sometimes', 'integer', 'min:1'], 'delivery_type' => ['sometimes', 'in:regular,express'], 'date' => ['required', 'date_format:Y-m-d'], 'page' => ['sometimes', 'integer', 'min:1'], 'per_page' => ['sometimes', 'integer', 'min:1', 'max:100']]);
        $depot = Depot::findOrFail(1);
        $query = DeliverySlot::where('depot_id', 1)->whereDate('service_date', $filters['date'])->where('is_active', true)->where('cutoff_at', '>', now())->where('window_start_at', '>', now());
        $hours = app(\App\Services\DeliveryPolicy::class)->hours($depot, $filters['date']);
        [$opens, $closes] = app(\App\Services\DeliveryPolicy::class)->bounds($depot, $filters['date']);
        $query->where('window_start_at', '>=', $opens)->where('window_end_at', '<=', $closes);
        $options = [];
        if (isset($filters['address_id']) && $depot->configured()) {
            $address = \App\Models\Address::where('user_id', $request->user()->id)->where('is_active', true)->findOrFail($filters['address_id']);
            $distance = app(\App\Services\DeliveryArea::class)->distance($depot, $address->latitude, $address->longitude);
            if ($distance > $depot->service_radius_m) {
                throw \Illuminate\Validation\ValidationException::withMessages(['address_id' => 'Alamat berada di luar wilayah layanan.']);
            }
            foreach (['regular', 'express'] as $type) {
                $options[] = app(\App\Services\DeliveryPolicy::class)->pricing($depot, $distance, $type);
            }
            if (($filters['delivery_type'] ?? 'regular') === 'express') {
                $query->where('window_start_at', '>=', now()->addMinutes($options[1]['preparation_minutes']));
            }
        } elseif (($filters['delivery_type'] ?? 'regular') === 'express') {
            $query->whereRaw('1 = 0');
        }
        if (! $depot->configured()) {
            $query->whereRaw('1 = 0');
        }

        return DeliverySlotResource::collection($query->orderBy('window_start_at')->orderBy('id')->paginate($filters['per_page'] ?? 20)->withQueryString())->additional(['delivery_options' => $options, 'operating_hours' => $hours, 'timezone' => $depot->timezone, 'server_time' => now()->toISOString()]);
    }
}
