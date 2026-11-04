<?php

namespace App\Http\Controllers;

use App\Http\Resources\AddressResource;
use App\Models\Address;
use App\Models\Depot;
use App\Services\DeliveryArea;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class AddressController extends Controller
{
    public function index(Request $request)
    {
        $filters = $request->validate(['per_page' => ['sometimes', 'integer', 'min:1', 'max:100'], 'page' => ['sometimes', 'integer', 'min:1']]);
        $request->attributes->set('delivery_depot', Depot::findOrFail(1));

        return AddressResource::collection(Address::where('user_id', $request->user()->id)->where('is_active', true)->orderByDesc('id')->paginate($filters['per_page'] ?? 20)->withQueryString());
    }

    public function store(Request $request)
    {
        return DB::transaction(function () use ($request) {
            $depot = Depot::lockForUpdate()->findOrFail(1);
            if (! $depot->configured()) {
                return response()->json(['message' => 'Wilayah pengiriman belum dikonfigurasi oleh admin.', 'code' => 'DELIVERY_NOT_CONFIGURED'], 409);
            }
            $address = new Address($this->validated($request, $depot));
            $address->user_id = $request->user()->id;
            $address->save();

            return (new AddressResource($address->refresh()))->response()->setStatusCode(201);
        });
    }

    public function update(Request $request, string $address)
    {
        return DB::transaction(function () use ($request, $address) {
            // Depot then address is the common mutation lock order.
            $depot = Depot::lockForUpdate()->findOrFail(1);
            $record = Address::where('user_id', $request->user()->id)->where('is_active', true)->lockForUpdate()->findOrFail($address);
            $version = $request->validate(['lock_version' => ['required', 'integer', 'min:0']])['lock_version'];
            if ($record->lock_version !== (int) $version) {
                return response()->json(['message' => 'Alamat telah berubah. Muat ulang sebelum mengedit.', 'code' => 'STALE_VERSION'], 409);
            }
            if (! $depot->configured()) {
                return response()->json(['message' => 'Wilayah pengiriman belum dikonfigurasi oleh admin.', 'code' => 'DELIVERY_NOT_CONFIGURED'], 409);
            }
            $record->fill($this->validated($request, $depot, $record));
            $record->lock_version++;
            $record->save();

            return new AddressResource($record);
        });
    }

    public function destroy(Request $request, string $address)
    {
        return DB::transaction(function () use ($request, $address) {
            $record = Address::where('user_id', $request->user()->id)->lockForUpdate()->findOrFail($address);
            if (! $record->is_active) {
                return response()->noContent();
            }
            $version = $request->validate(['lock_version' => ['required', 'integer', 'min:0']])['lock_version'];
            if ($record->lock_version !== (int) $version) {
                return response()->json(['message' => 'Alamat telah berubah. Muat ulang sebelum menghapus.', 'code' => 'STALE_VERSION'], 409);
            }
            $record->is_active = false;
            $record->lock_version++;
            $record->save();

            return response()->noContent();
        });
    }

    private function validated(Request $request, Depot $depot, ?Address $existing = null): array
    {
        $fields = ['label', 'recipient_name', 'phone', 'address_text', 'latitude', 'longitude', 'directions'];
        $rules = ['label' => ['required', 'string', 'max:80'], 'recipient_name' => ['required', 'string', 'max:160'], 'phone' => ['required', 'string', 'max:30'], 'address_text' => ['required', 'string', 'max:2000'], 'latitude' => ['required', 'numeric', 'between:-90,90'], 'longitude' => ['required', 'numeric', 'between:-180,180'], 'directions' => ['nullable', 'string', 'max:1000'], 'user_id' => ['missing'], 'is_active' => ['missing']];
        $values = array_replace($existing?->only($fields) ?? [], $request->all());
        $data = Validator::make($values, $rules)->validate();
        $data['latitude'] = round((float) $data['latitude'], 7);
        $data['longitude'] = round((float) $data['longitude'], 7);
        if (! app(DeliveryArea::class)->contains($depot, $data['latitude'], $data['longitude'])) {
            throw ValidationException::withMessages(['latitude' => 'Pin alamat berada di luar radius layanan depot.']);
        }

        return $data;
    }
}
