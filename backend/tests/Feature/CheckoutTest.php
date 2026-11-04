<?php

namespace Tests\Feature;

use App\Models\Address;
use App\Models\DeliverySlot;
use App\Models\Depot;
use App\Models\IdempotencyRecord;
use App\Models\InventoryAccount;
use App\Models\Order;
use App\Models\Product;
use App\Models\StockReservation;
use App\Models\User;
use App\Services\InventoryService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class CheckoutTest extends TestCase
{
    use RefreshDatabase;

    private User $customer;

    private User $admin;

    private Address $address;

    private DeliverySlot $slot;

    private Product $a;

    private Product $b;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-11-04T01:00:00Z'));
        Depot::findOrFail(1)->fill(['address_text' => 'Depot uji', 'latitude' => -7.25, 'longitude' => 112.75, 'service_radius_m' => 5000, 'delivery_fee_rp' => 3000])->save();
        $this->admin = User::factory()->create(['role' => 'admin']);
        $this->customer = User::factory()->create();
        $this->address = new Address(['label' => 'Rumah', 'recipient_name' => 'Customer', 'phone' => '081234', 'address_text' => 'Alamat snapshot', 'latitude' => -7.251, 'longitude' => 112.751]);
        $this->address->user_id = $this->customer->id;
        $this->address->save();
        $this->slot = new DeliverySlot(['service_date' => '2026-11-05', 'window_start_at' => '2026-11-05 03:00:00', 'window_end_at' => '2026-11-05 05:00:00', 'cutoff_at' => '2026-11-05 02:00:00', 'is_active' => true]);
        $this->slot->depot_id = 1;
        $this->slot->save();
        $this->a = $this->product('A', 15000);
        $this->b = $this->product('B', 12000);
        $this->fund($this->a, 5);
        $this->fund($this->b, 5);
        $this->withToken($this->customer->createToken('test')->plainTextToken);
    }

    private function product(string $name, int $price): Product
    {
        $p = new Product(['sku' => $name, 'name' => 'Barang '.$name, 'unit_label' => 'pak', 'category' => 'Kebutuhan', 'unit_price_rp' => $price, 'shipping_weight_g' => 1000, 'length_mm' => 100, 'width_mm' => 100, 'height_mm' => 100, 'is_active' => true]);
        $p->depot_id = 1;
        $p->calculateVolume();
        $p->save();

        return $p;
    }

    private function fund(Product $p, int $delta): void
    {
        app(InventoryService::class)->adjust($this->admin->id, $p->id, 'available', $delta, 'Stok awal uji', Str::uuid()->toString());
    }

    private function payload(array $overrides = []): array
    {
        return array_replace(['address_id' => (string) $this->address->id, 'delivery_slot_id' => (string) $this->slot->id, 'items' => [['product_id' => (string) $this->a->id, 'quantity' => 2], ['product_id' => (string) $this->b->id, 'quantity' => 1]], 'expected_total_rp' => 45000], $overrides);
    }

    private function create(array $payload = [], ?string $key = null)
    {
        return $this->postJson('/api/v1/orders', $payload ?: $this->payload(), ['Idempotency-Key' => $key ?? Str::uuid()->toString()]);
    }

    public function test_quote_calculates_server_totals_without_reserving(): void
    {
        $payload = $this->payload();
        unset($payload['expected_total_rp']);
        $this->postJson('/api/v1/order-quotes', $payload)->assertOk()->assertJsonPath('data.total_rp', 45000)->assertJsonPath('data.total_weight_g', 3000)->assertJsonPath('data.total_volume_cm3', 3000)->assertJsonPath('data.reserves_stock', false)->assertJsonPath('data.stock_available_now', true);
        $this->assertDatabaseCount('orders', 0);
        $this->assertDatabaseCount('stock_reservations', 0);
    }

    public function test_checkout_snapshots_items_and_reserves_without_changing_physical_stock(): void
    {
        $data = $this->create()->assertCreated()->assertJsonPath('data.status', 'pending')->assertJsonPath('data.payment_status', 'unpaid')->assertJsonPath('data.total_rp', 45000)->json('data');
        $this->assertIsString($data['id']);
        $this->assertStringStartsWith('SX-', $data['order_number']);
        $this->assertDatabaseCount('order_items', 2);
        $this->assertDatabaseCount('stock_reservations', 2);
        $this->assertDatabaseCount('inventory_entries', 2);
        $this->assertDatabaseHas('inventory_accounts', ['product_id' => $this->a->id, 'stock_state' => 'available', 'balance_quantity' => 5]);
        $this->getJson('/api/v1/catalog?q=Barang%20A')->assertJsonPath('data.0.available_quantity', 3);
        $this->a->name = 'Nama baru';
        $this->a->unit_price_rp = 99000;
        $this->a->save();
        $this->address->address_text = 'Alamat baru';
        $this->address->save();
        $this->getJson('/api/v1/orders/'.$data['id'])->assertOk()->assertJsonPath('data.items.0.name', 'Barang A')->assertJsonPath('data.items.0.unit_price_rp', 15000)->assertJsonPath('data.address.address_text', 'Alamat snapshot');
    }

    public function test_idempotency_replays_success_and_rejects_payload_conflicts(): void
    {
        $key = Str::uuid()->toString();
        $first = $this->create(key: $key)->assertCreated()->json();
        $this->create(key: $key)->assertCreated()->assertExactJson($first);
        $this->create($this->payload(['expected_total_rp' => 45001]), $key)->assertStatus(409)->assertJsonPath('code', 'IDEMPOTENCY_CONFLICT');
        $this->assertDatabaseCount('orders', 1);
        $this->assertDatabaseCount('stock_reservations', 2);
        IdempotencyRecord::first()->update(['expires_at' => now()->subSecond()]);
        $this->create(key: $key)->assertStatus(409)->assertJsonPath('code', 'IDEMPOTENCY_EXPIRED');
    }

    public function test_checkout_requires_uuid_key_and_valid_items(): void
    {
        $this->postJson('/api/v1/orders', $this->payload())->assertUnprocessable()->assertJsonValidationErrors('idempotency_key');
        $this->postJson('/api/v1/orders', $this->payload(), ['Idempotency-Key' => 'no'])->assertUnprocessable();
        foreach ([0, 21] as $q) {
            $this->create($this->payload(['items' => [['product_id' => $this->a->id, 'quantity' => $q]]]))->assertUnprocessable();
        }
        $this->create($this->payload(['items' => [['product_id' => $this->a->id, 'quantity' => 1], ['product_id' => (string) $this->a->id, 'quantity' => 1]]]))->assertUnprocessable();
        $this->create($this->payload(['items' => [['product_id' => $this->a->id, 'quantity' => 1, 'unit_price_rp' => 1]]]))->assertUnprocessable();
        $this->assertDatabaseCount('orders', 0);
    }

    public function test_multi_sku_stock_failure_rolls_back_entire_order(): void
    {
        app(InventoryService::class)->adjust($this->admin->id, $this->b->id, 'available', -5, 'Kosongkan B', Str::uuid()->toString());
        $key = Str::uuid()->toString();
        $this->create(key: $key)->assertStatus(409)->assertJsonPath('code', 'OUT_OF_STOCK');
        $this->assertDatabaseCount('orders', 0);
        $this->assertDatabaseCount('order_items', 0);
        $this->assertDatabaseCount('stock_reservations', 0);
        $payload = $this->payload();
        unset($payload['expected_total_rp']);
        $this->postJson('/api/v1/order-quotes', $payload)->assertOk()->assertJsonPath('data.stock_available_now', false);
        $this->fund($this->b, 2);
        $this->create(key: $key)->assertStatus(409)->assertJsonPath('code', 'OUT_OF_STOCK');
        $this->create()->assertCreated();
    }

    public function test_price_slot_and_invalid_metadata_are_rechecked_at_checkout(): void
    {
        $this->create($this->payload(['expected_total_rp' => 1]))->assertStatus(409)->assertJsonPath('code', 'PRICE_CHANGED');
        $this->slot->cutoff_at = now();
        $this->slot->save();
        $this->create()->assertStatus(409)->assertJsonPath('code', 'SLOT_CLOSED');
        $this->slot->cutoff_at = now()->addDay();
        $this->slot->save();
        $this->a->is_active = false;
        $this->a->save();
        $this->create()->assertUnprocessable();
        $this->a->is_active = true;
        $this->a->shipping_volume_cm3 = 1;
        $this->a->save();
        $this->create()->assertUnprocessable();
        $this->assertDatabaseCount('orders', 0);
    }

    public function test_cancellation_is_owned_versioned_idempotent_and_releases_once(): void
    {
        $id = $this->create()->json('data.id');
        $url = '/api/v1/orders/'.$id.'/cancel';
        $key = Str::uuid()->toString();
        $this->postJson($url, ['lock_version' => 9, 'reason' => 'Tidak jadi'], ['Idempotency-Key' => Str::uuid()->toString()])->assertStatus(409)->assertJsonPath('code', 'STALE_VERSION');
        $first = $this->postJson($url, ['lock_version' => 0, 'reason' => 'Tidak jadi'], ['Idempotency-Key' => $key])->assertOk()->assertJsonPath('data.status', 'cancelled')->json();
        $this->postJson($url, ['lock_version' => 0, 'reason' => 'Tidak jadi'], ['Idempotency-Key' => $key])->assertOk()->assertExactJson($first);
        $this->assertSame(0, StockReservation::where('status', 'active')->count());
        $this->assertDatabaseCount('inventory_entries', 2);
        $this->getJson('/api/v1/catalog?q=Barang%20A')->assertJsonPath('data.0.available_quantity', 5);
    }

    public function test_expiry_command_and_lazy_reads_release_reservations_once(): void
    {
        $id = $this->create()->json('data.id');
        $this->travel(31)->minutes();
        $this->getJson('/api/v1/orders/'.$id)->assertOk()->assertJsonPath('data.status', 'cancelled')->assertJsonPath('data.status_reason', 'PENDING_EXPIRED');
        $this->artisan('shipx:expire-orders')->assertExitCode(0);
        $this->assertSame(0, StockReservation::where('status', 'active')->count());
        $this->assertDatabaseHas('orders', ['id' => $id, 'lock_version' => 1]);
        $this->assertDatabaseCount('inventory_entries', 2);
    }

    public function test_pending_deadline_never_exceeds_slot_cutoff(): void
    {
        $this->slot->cutoff_at = now()->addMinutes(5);
        $this->slot->save();
        $this->create()->assertCreated()->assertJsonPath('data.pending_expires_at', now()->addMinutes(5)->toISOString());
    }

    public function test_other_customer_cannot_read_or_cancel_order_and_role_cannot_checkout(): void
    {
        $id = $this->create()->json('data.id');
        $other = User::factory()->create();
        $this->app['auth']->forgetGuards();
        $this->withToken($other->createToken('other')->plainTextToken);
        $this->getJson('/api/v1/orders')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/orders/'.$id)->assertNotFound();
        $this->postJson('/api/v1/orders/'.$id.'/cancel', ['lock_version' => 0, 'reason' => 'x'], ['Idempotency-Key' => Str::uuid()->toString()])->assertNotFound();
        $this->create()->assertNotFound();
        $this->app['auth']->forgetGuards();
        $this->withToken($this->admin->createToken('admin')->plainTextToken);
        $this->create()->assertForbidden();
    }

    public function test_stock_adjustment_uses_ledger_key_and_protects_reserved_balance(): void
    {
        $this->create()->assertCreated();
        $this->actingAs($this->admin, 'web');
        $key = Str::uuid()->toString();
        $payload = ['idempotency_key' => $key, 'stock_state' => 'available', 'quantity_delta' => 2, 'reason' => 'Barang masuk'];
        $this->post('/admin/stock/'.$this->a->id, $payload)->assertRedirect();
        $this->post('/admin/stock/'.$this->a->id, $payload)->assertRedirect();
        $this->assertDatabaseHas('inventory_accounts', ['product_id' => $this->a->id, 'stock_state' => 'available', 'balance_quantity' => 7]);
        $this->assertDatabaseCount('inventory_entries', 3);
        $this->post('/admin/stock/'.$this->a->id, [...$payload, 'quantity_delta' => 3])->assertStatus(409);
        $this->post('/admin/stock/'.$this->a->id, [...$payload, 'idempotency_key' => Str::uuid()->toString(), 'quantity_delta' => -7])->assertStatus(409);
        $this->assertDatabaseCount('inventory_entries', 3);
        $this->get('/admin/stock')->assertOk();
        $this->get('/admin/stock/'.$this->a->id)->assertOk();
        $order = Order::first();
        $this->get('/admin/orders')->assertOk()->assertSee($order->order_number);
        $this->get('/admin/orders/'.$order->id)->assertOk()->assertSee('Alamat snapshot');
    }

    public function test_stock_admin_routes_reject_customers_and_require_reason(): void
    {
        $this->actingAs($this->customer, 'web');
        $this->post('/admin/stock/'.$this->a->id, [])->assertForbidden();
        $this->get('/admin/orders')->assertForbidden();
        $this->actingAs($this->admin, 'web');
        $this->post('/admin/stock/'.$this->a->id, ['idempotency_key' => Str::uuid()->toString(), 'quantity_delta' => 1, 'stock_state' => 'available'])->assertSessionHasErrors('reason');
    }

    public function test_ledger_matches_physical_balances_for_every_account(): void
    {
        $this->create()->assertCreated();
        foreach (InventoryAccount::all() as $account) {
            $sum = (int) DB::table('inventory_entries')->where('inventory_account_id',$account->id)->sum('quantity_delta');
            $this->assertSame($account->balance_quantity,$sum);
        }
    }
}
