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
        $filters = $request->validate(['date' => ['required', 'date_format:Y-m-d'], 'page' => ['sometimes', 'integer', 'min:1'], 'per_page' => ['sometimes', 'integer', 'min:1', 'max:100']]);
        $depot = Depot::findOrFail(1);
        $query = DeliverySlot::where('depot_id', 1)->whereDate('service_date', $filters['date'])->where('is_active', true)->where('cutoff_at', '>', now())->where('window_start_at', '>', now());
        if (! $depot->configured()) {
            $query->whereRaw('1 = 0');
        }

        return DeliverySlotResource::collection($query->orderBy('window_start_at')->orderBy('id')->paginate($filters['per_page'] ?? 20)->withQueryString())->additional(['timezone' => $depot->timezone, 'server_time' => now()->toISOString()]);
    }
}
