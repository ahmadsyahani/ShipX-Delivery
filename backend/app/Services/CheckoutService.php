<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use App\Models\Address;
use App\Models\DeliverySlot;
use App\Models\Depot;
use App\Models\Order;
use App\Models\Product;
use App\Models\StockReservation;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class CheckoutService
{
    public function __construct(private InventoryService $inventory, private DeliveryArea $area) {}

    public function quote(int $customer, array $payload): array
    {
        return DB::transaction(fn () => $this->prepare($customer, $payload)['quote']);
    }

    public function checkout(int $customer, array $payload): Order
    {
        return DB::transaction(function () use ($customer, $payload) {
            $prepared = $this->prepare($customer, $payload);
            $quote = $prepared['quote'];
            $depot = $prepared['depot'];
            $address = $prepared['address'];
            $slot = $prepared['slot'];
            if ($quote['total_rp'] !== $payload['expected_total_rp']) {
                throw new BusinessFailure('PRICE_CHANGED', 'Harga atau ongkir berubah. Hitung ulang total sebelum membuat pesanan.');
            }
            if (! $quote['stock_available_now']) {
                throw new BusinessFailure('OUT_OF_STOCK', 'Stok salah satu barang tidak cukup. Seluruh checkout dibatalkan.');
            }
            $expires = now()->addMinutes($depot->pending_ttl_minutes);
            if ($slot->cutoff_at < $expires) {
                $expires = $slot->cutoff_at;
            }
            $order = Order::create([
                'order_number' => 'SX-'.now()->format('Ymd').'-'.Str::ulid(), 'depot_id' => 1, 'customer_id' => $customer, 'source_address_id' => $address->id, 'delivery_slot_id' => $slot->id, 'status' => 'pending', 'payment_status' => 'unpaid',
                'recipient_name' => $address->recipient_name, 'recipient_phone' => $address->phone, 'address_text' => $address->address_text, 'latitude' => $address->latitude, 'longitude' => $address->longitude, 'directions' => $address->directions, 'timezone_snapshot' => $depot->timezone,
                'window_start_at' => $slot->window_start_at, 'window_end_at' => $slot->window_end_at, 'subtotal_rp' => $quote['subtotal_rp'], 'delivery_fee_rp' => $quote['delivery_fee_rp'], 'total_rp' => $quote['total_rp'], 'total_weight_g' => $quote['total_weight_g'], 'total_volume_cm3' => $quote['total_volume_cm3'], 'pending_expires_at' => $expires,
            ]);
            foreach ($quote['items'] as $item) {
                $row = $order->items()->create(['product_id' => $item['product_id'], 'product_name_snapshot' => $item['name'], 'unit_label_snapshot' => $item['unit_label'], 'quantity' => $item['quantity'], 'unit_price_rp' => $item['unit_price_rp'], 'line_total_rp' => $item['line_total_rp'], 'unit_weight_g' => $item['unit_weight_g'], 'unit_volume_cm3' => $item['unit_volume_cm3'], 'length_mm_snapshot' => $item['length_mm'], 'width_mm_snapshot' => $item['width_mm'], 'height_mm_snapshot' => $item['height_mm'], 'handling_notes_snapshot' => $item['handling_notes']]);
                StockReservation::create(['order_item_id' => $row->id, 'inventory_account_id' => $prepared['accounts'][$item['product_id']]->id, 'quantity' => $item['quantity'], 'status' => 'active']);
            }

            return $order->refresh()->load('items');
        });
    }

    private function prepare(int $customer, array $payload): array
    {
        // Single depot is the outer mutex for this MVP. Within it every inventory
        // account is locked in ascending ID order, before any order mutation.
        $depot = Depot::lockForUpdate()->findOrFail(1);
        if (! $depot->configured()) {
            throw new BusinessFailure('DELIVERY_NOT_CONFIGURED', 'Depot belum siap menerima pesanan.');
        }
        $slot = DeliverySlot::where('depot_id', 1)->lockForUpdate()->findOrFail($payload['delivery_slot_id']);
        if (! $slot->is_active || $slot->cutoff_at <= now() || $slot->window_start_at <= now()) {
            throw new BusinessFailure('SLOT_CLOSED', 'Slot pengiriman sudah ditutup. Pilih jadwal lain.');
        }
        $address = Address::where('user_id', $customer)->where('is_active', true)->lockForUpdate()->findOrFail($payload['address_id']);
        if (! $this->area->contains($depot, $address->latitude, $address->longitude)) {
            throw ValidationException::withMessages(['address_id' => 'Alamat berada di luar wilayah layanan saat ini.']);
        }
        $ids = array_column($payload['items'], 'product_id');
        $products = Product::where('depot_id', 1)->whereIn('id', $ids)->orderBy('id')->lockForUpdate()->get()->keyBy('id');
        foreach ($ids as $id) {
            $p = $products->get($id);
            if (! $p || ! $p->is_active || $p->unit_price_rp <= 0 || $p->shipping_weight_g <= 0 || min($p->length_mm, $p->width_mm, $p->height_mm) <= 0 || $p->shipping_volume_cm3 < (int) ceil($p->length_mm * $p->width_mm * $p->height_mm / 1000)) {
                throw ValidationException::withMessages(['items' => 'Salah satu produk tidak aktif atau metadata pengirimannya belum valid.']);
            }
            $this->inventory->ensureAccounts($p);
        }
        $accounts = $this->inventory->lockAccounts($ids)->where('stock_state', 'available')->keyBy('product_id');
        $items = [];
        $subtotal = 0;
        $weight = 0;
        $volume = 0;
        $available = true;
        foreach ($payload['items'] as $input) {
            $p = $products->get($input['product_id']);
            $account = $accounts[$p->id];
            $quantity = (int) $input['quantity'];
            $stock = max(0, $account->balance_quantity - $this->inventory->reserved($account->id));
            $line = $quantity * $p->unit_price_rp;
            $subtotal += $line;
            $weight += $quantity * $p->shipping_weight_g;
            $volume += $quantity * $p->shipping_volume_cm3;
            $available = $available && $stock >= $quantity;
            $items[] = ['product_id' => (string) $p->id, 'name' => $p->name, 'unit_label' => $p->unit_label, 'quantity' => $quantity, 'unit_price_rp' => $p->unit_price_rp, 'line_total_rp' => $line, 'unit_weight_g' => $p->shipping_weight_g, 'unit_volume_cm3' => $p->shipping_volume_cm3, 'length_mm' => $p->length_mm, 'width_mm' => $p->width_mm, 'height_mm' => $p->height_mm, 'handling_notes' => $p->handling_notes, 'available_quantity' => $stock];
        }
        $quote = ['items' => $items, 'subtotal_rp' => $subtotal, 'delivery_fee_rp' => $depot->delivery_fee_rp, 'total_rp' => $subtotal + $depot->delivery_fee_rp, 'total_weight_g' => $weight, 'total_volume_cm3' => $volume, 'stock_available_now' => $available, 'reserves_stock' => false];

        return compact('quote','depot','address','slot','accounts');
    }
}
