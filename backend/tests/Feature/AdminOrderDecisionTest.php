<?php

namespace Tests\Feature;

use App\Models\Address;
use App\Models\DeliverySlot;
use App\Models\Depot;
use App\Models\IdempotencyRecord;
use App\Models\Order;
use App\Models\Product;
use App\Models\StockReservation;
use App\Models\User;
use App\Services\CheckoutService;
use App\Services\InventoryService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class AdminOrderDecisionTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $customer;

    private Order $order;

    private Product $product;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-11-04T01:00:00Z'));
        Depot::findOrFail(1)->fill(['address_text' => 'Depot QA', 'latitude' => -7.25, 'longitude' => 112.75, 'service_radius_m' => 5000, 'delivery_fee_rp' => 3000])->save();
        $this->admin = User::factory()->create(['role' => 'admin']);
        $this->customer = User::factory()->create();
        $address = new Address(['label' => 'Rumah', 'recipient_name' => 'Penerima', 'phone' => '080000', 'address_text' => 'Alamat snapshot', 'latitude' => -7.25, 'longitude' => 112.75]);
        $address->user_id = $this->customer->id;
        $address->save();
        $slot = new DeliverySlot(['service_date' => '2026-11-05', 'window_start_at' => '2026-11-05 03:00:00', 'window_end_at' => '2026-11-05 05:00:00', 'cutoff_at' => '2026-11-05 02:00:00', 'is_active' => true]);
        $slot->depot_id = 1;
        $slot->save();
        $this->product = new Product(['sku' => 'DECISION', 'name' => 'Barang snapshot', 'category' => 'QA', 'unit_label' => 'pak', 'unit_price_rp' => 15000, 'shipping_weight_g' => 1000, 'length_mm' => 100, 'width_mm' => 100, 'height_mm' => 100, 'is_active' => true]);
        $this->product->depot_id = 1;
        $this->product->calculateVolume();
        $this->product->save();
        app(InventoryService::class)->adjust($this->admin->id, $this->product->id, 'available', 5, 'QA stock', Str::uuid()->toString());
        $this->order = app(CheckoutService::class)->checkout($this->customer->id, ['address_id' => $address->id, 'delivery_slot_id' => $slot->id, 'items' => [['product_id' => $this->product->id, 'quantity' => 2]], 'expected_total_rp' => 33000]);
        $this->actingAs($this->admin, 'web');
    }

    private function decide(string $action = 'confirm', array $overrides = [])
    {
        return $this->post('/admin/orders/'.$this->order->id.'/'.$action, array_replace(['idempotency_key' => Str::uuid()->toString(), 'lock_version' => 0], $action === 'reject' ? ['reason' => 'Jadwal tidak dapat dilayani'] : [], $overrides));
    }

    public function test_confirm_keeps_stock_and_snapshots_records_actor_and_replays_once(): void
    {
        $this->product->update(['unit_price_rp' => 9000, 'name' => 'Master berubah', 'is_active' => false]);
        $key = Str::uuid()->toString();
        $this->decide(overrides: ['idempotency_key' => $key])->assertRedirect('/admin/orders/'.$this->order->id);
        $this->decide(overrides: ['idempotency_key' => $key])->assertRedirect();
        $this->assertDatabaseHas('orders', ['id' => $this->order->id, 'status' => 'confirmed', 'lock_version' => 1, 'payment_status' => 'unpaid', 'total_rp' => 33000]);
        $this->assertNotNull($this->order->refresh()->confirmed_at);
        $this->assertDatabaseHas('order_decisions', ['order_id' => $this->order->id, 'admin_id' => $this->admin->id, 'decision' => 'confirmed', 'order_version' => 1]);
        $this->assertDatabaseCount('order_decisions', 1);
        $this->assertDatabaseCount('inventory_entries', 1);
        $this->assertDatabaseHas('inventory_accounts', ['product_id' => $this->product->id, 'stock_state' => 'available', 'balance_quantity' => 5]);
        $this->assertDatabaseHas('stock_reservations', ['status' => 'active', 'quantity' => 2]);
        $this->assertDatabaseHas('order_items', ['order_id' => $this->order->id, 'product_name_snapshot' => 'Barang snapshot', 'unit_price_rp' => 15000]);
        $this->get('/admin/orders/'.$this->order->id)->assertInertia(fn (Assert $page) => $page->where('order.decision.admin.name', $this->admin->name)->missing('order.decision.admin.email')->missing('order.decision.admin.password'));
        $this->decide(overrides: ['idempotency_key' => $key, 'lock_version' => 1])->assertStatus(409);
        $this->travel(31)->minutes();
        $this->artisan('shipx:expire-orders')->assertSuccessful();
        $this->assertSame('confirmed', $this->order->refresh()->status);
        $this->assertSame(2, (int) StockReservation::where('status', 'active')->sum('quantity'));
    }

    public function test_reject_is_final_requires_reason_and_releases_once(): void
    {
        $key = Str::uuid()->toString();
        $this->decide('reject', ['idempotency_key' => $key])->assertRedirect();
        $this->decide('reject', ['idempotency_key' => $key])->assertRedirect();
        $this->assertDatabaseHas('orders', ['id' => $this->order->id, 'status' => 'rejected', 'status_reason' => 'Jadwal tidak dapat dilayani', 'lock_version' => 1, 'confirmed_at' => null, 'cancelled_at' => null]);
        $this->assertNotNull($this->order->refresh()->closed_at);
        $this->assertDatabaseHas('order_decisions', ['decision' => 'rejected', 'reason' => 'Jadwal tidak dapat dilayani']);
        $this->assertDatabaseHas('stock_reservations', ['status' => 'released']);
        $this->assertDatabaseCount('order_decisions', 1);
        $this->assertDatabaseCount('inventory_entries', 1);
        $this->decide(overrides: ['lock_version' => 1])->assertStatus(409);
        $this->decide('reject', ['lock_version' => 1])->assertStatus(409);
        $this->assertSame('rejected', $this->order->refresh()->status);
        $this->get('/admin/orders?status=rejected')->assertInertia(fn (Assert $page) => $page->has('orders.data', 1));
    }

    public function test_only_active_web_admin_can_decide_and_csrf_is_required(): void
    {
        foreach (['customer', 'courier'] as $role) {
            $this->actingAs(User::factory()->create(['role' => $role]), 'web');
            $this->decide()->assertForbidden();
            $this->decide('reject')->assertForbidden();
        }
        $this->actingAs(User::factory()->create(['role' => 'admin', 'is_active' => false]), 'web');
        $this->decide()->assertForbidden();
        auth('web')->logout();
        $this->decide()->assertRedirect('/admin/login');
        $this->withToken($this->admin->createToken('not-web')->plainTextToken);
        $this->decide()->assertRedirect('/admin/login');
        $this->actingAs($this->admin, 'web');
        $this->app['env'] = 'local';
        $this->decide()->assertStatus(419);
        $this->assertDatabaseCount('order_decisions', 0);
        $this->assertSame('pending', $this->order->refresh()->status);
    }

    public function test_validation_and_stale_version_cannot_change_order(): void
    {
        $this->decide('reject', ['reason' => '   '])->assertSessionHasErrors('reason');
        $this->decide('reject', ['reason' => str_repeat('x', 501)])->assertSessionHasErrors('reason');
        $this->decide(overrides: ['idempotency_key' => 'bad', 'lock_version' => -1])->assertSessionHasErrors(['idempotency_key', 'lock_version']);
        $this->decide(overrides: ['admin_id' => $this->customer->id, 'status' => 'confirmed', 'reason' => 'not accepted'])->assertSessionHasErrors(['admin_id', 'status', 'reason']);
        $key = Str::uuid()->toString();
        $this->decide(overrides: ['idempotency_key' => $key, 'lock_version' => 9])->assertStatus(409);
        $this->decide(overrides: ['idempotency_key' => $key, 'lock_version' => 9])->assertStatus(409);
        $this->assertSame('STALE_VERSION', IdempotencyRecord::where('idempotency_key', $key)->firstOrFail()->response_body['code']);
        $this->assertDatabaseCount('order_decisions', 0);
    }

    public function test_exact_expiry_releases_reservations_and_cannot_confirm_or_reject(): void
    {
        $this->travelTo($this->order->pending_expires_at);
        $key = Str::uuid()->toString();
        $this->decide(overrides: ['idempotency_key' => $key])->assertStatus(409);
        $this->assertSame('ORDER_EXPIRED', IdempotencyRecord::where('idempotency_key', $key)->firstOrFail()->response_body['code']);
        $this->assertDatabaseHas('orders', ['id' => $this->order->id, 'status' => 'cancelled', 'status_reason' => 'PENDING_EXPIRED', 'lock_version' => 1]);
        $this->assertDatabaseHas('stock_reservations', ['status' => 'released']);
        $this->decide(overrides: ['idempotency_key' => $key])->assertStatus(409);
        $this->decide('reject', ['lock_version' => 1])->assertStatus(409);
        $this->artisan('shipx:expire-orders')->assertSuccessful();
        $this->assertSame(1, $this->order->refresh()->lock_version);
        $this->assertDatabaseCount('order_decisions', 0);
    }

    public function test_confirm_reject_conflict_and_customer_cancellation_use_latest_version(): void
    {
        $this->decide()->assertRedirect();
        $this->decide('reject')->assertStatus(409);
        $this->app['auth']->forgetGuards();
        $this->withToken($this->customer->createToken('customer')->plainTextToken);
        $this->getJson('/api/v1/orders/'.$this->order->id)->assertOk()->assertJsonPath('data.status', 'confirmed')->assertJsonPath('data.lock_version', 1)->assertJsonPath('data.confirmed_at', $this->order->refresh()->confirmed_at->toISOString())->assertJsonMissingPath('data.decision');
        $url = '/api/v1/orders/'.$this->order->id.'/cancel';
        $this->postJson($url, ['lock_version' => 0, 'reason' => 'Batal'], ['Idempotency-Key' => Str::uuid()->toString()])->assertStatus(409);
        $this->postJson($url, ['lock_version' => 1, 'reason' => 'Batal'], ['Idempotency-Key' => Str::uuid()->toString()])->assertOk()->assertJsonPath('data.status', 'cancelled');
        $this->assertDatabaseHas('stock_reservations', ['status' => 'released']);
        $this->assertDatabaseCount('order_decisions', 1);
        $this->assertDatabaseCount('inventory_entries', 1);
    }

    public function test_rejected_status_and_reason_reach_customer_but_order_cannot_be_cancelled(): void
    {
        $this->decide('reject')->assertRedirect();
        $this->app['auth']->forgetGuards();
        $this->withToken($this->customer->createToken('customer')->plainTextToken);
        $this->getJson('/api/v1/orders/'.$this->order->id)->assertOk()->assertJsonPath('data.status', 'rejected')->assertJsonPath('data.status_reason', 'Jadwal tidak dapat dilayani')->assertJsonMissingPath('data.decision');
        $this->postJson('/api/v1/orders/'.$this->order->id.'/cancel', ['lock_version' => 1, 'reason' => 'Batal'], ['Idempotency-Key' => Str::uuid()->toString()])->assertStatus(409)->assertJsonPath('code', 'ORDER_NOT_CANCELLABLE');
    }

    public function test_invalid_reservation_blocks_confirmation_without_creating_decision(): void
    {
        StockReservation::query()->update(['status' => 'released']);
        $this->decide()->assertStatus(409);
        $this->assertSame('pending', $this->order->refresh()->status);
        $this->assertDatabaseCount('order_decisions', 0);
        $this->decide('reject')->assertRedirect();
        $this->assertSame('rejected', $this->order->refresh()->status);
    }
}
