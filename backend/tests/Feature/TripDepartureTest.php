<?php

namespace Tests\Feature;

use App\Models\Address;
use App\Models\DeliverySlot;
use App\Models\Depot;
use App\Models\InventoryAccount;
use App\Models\Product;
use App\Models\Trip;
use App\Models\TripDepartureReview;
use App\Models\User;
use App\Models\Vehicle;
use App\Services\CheckoutService;
use App\Services\InventoryService;
use App\Services\ManualTripService;
use App\Services\OrderLifecycleService;
use App\Services\TripDepartureReviewService;
use App\Services\TripManifestService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

class TripDepartureTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $courier;

    private User $customer;

    private Vehicle $vehicle;

    private Trip $trip;

    private array $orders;

    private array $products;

    private Address $address;

    private DeliverySlot $slot;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-11-04T01:00:00Z'));
        Depot::findOrFail(1)->fill(['address_text' => 'Depot QA', 'latitude' => -7.25, 'longitude' => 112.75, 'service_radius_m' => 5000, 'delivery_fee_rp' => 3000, 'default_service_seconds' => 300])->save();
        $this->admin = User::factory()->create(['role' => 'admin']);
        $this->courier = User::factory()->create(['role' => 'courier'])->refresh();
        $this->customer = User::factory()->create();
        $this->vehicle = new Vehicle(['code' => 'LOAD-QA', 'name' => 'Motor QA', 'plate_number' => 'B123QA', 'travel_mode' => 'motorcycle', 'max_load_weight_g' => 10000, 'max_load_volume_cm3' => 10000, 'is_active' => true]);
        $this->vehicle->depot_id = 1;
        $this->vehicle->save();
        $this->vehicle->refresh();
        $this->address = new Address(['label' => 'Rumah', 'recipient_name' => 'Penerima QA', 'phone' => '080000', 'address_text' => 'Alamat snapshot', 'latitude' => -7.25, 'longitude' => 112.75]);
        $this->address->user_id = $this->customer->id;
        $this->address->save();
        $this->slot = new DeliverySlot(['service_date' => '2026-11-04', 'window_start_at' => '2026-11-04 03:00:00', 'window_end_at' => '2026-11-04 05:00:00', 'cutoff_at' => '2026-11-04 02:00:00', 'is_active' => true]);
        $this->slot->depot_id = 1;
        $this->slot->save();
        $this->products = [];
        foreach ([1000, 500] as $i => $weight) {
            $p = new Product(['sku' => 'LOAD-'.$i, 'name' => 'Barang '.$i, 'category' => 'QA', 'unit_label' => 'pak', 'unit_price_rp' => 15000, 'shipping_weight_g' => $weight, 'length_mm' => 100, 'width_mm' => 100, 'height_mm' => 100, 'is_active' => true]);
            $p->depot_id = 1;
            $p->calculateVolume();
            $p->save();
            app(InventoryService::class)->adjust($this->admin->id, $p->id, 'available', 20, 'QA stock', Str::uuid()->toString());
            $this->products[] = $p;
        }
        $this->orders = [];
        for ($i = 0; $i < 2; $i++) {
            $o = app(CheckoutService::class)->checkout($this->customer->id, ['address_id' => $this->address->id, 'delivery_slot_id' => $this->slot->id, 'items' => [['product_id' => $this->products[0]->id, 'quantity' => 2], ['product_id' => $this->products[1]->id, 'quantity' => 1]], 'expected_total_rp' => 48000]);
            app(OrderLifecycleService::class)->decide($this->admin->id, $o->id, 0, 'confirmed');
            $this->orders[] = $o->refresh();
        }
        $r = app(ManualTripService::class)->save($this->admin->id, ['courier_id' => $this->courier->id, 'vehicle_id' => $this->vehicle->id, 'departure_local' => '2026-11-04T09:00', 'orders' => array_map(fn ($o) => ['id' => $o->id, 'lock_version' => 1], $this->orders)]);
        $this->trip = Trip::findOrFail($r['body']['data']['id']);
        app(ManualTripService::class)->act($this->admin->id, $this->trip->id, 0, 'assign');
        $this->trip->refresh();
        $this->actingAs($this->admin, 'web');
    }

    private function review(array $overrides = [])
    {
        $this->actingAs($this->admin, 'web');

        return $this->post('/admin/trips/'.$this->trip->id.'/departure-review', array_replace(['idempotency_key' => Str::uuid()->toString(), 'lock_version' => $this->trip->lock_version, 'leg_minutes' => [10, 10, 10], 'source_reference' => 'Peta jalan QA, mode motor; tinjauan manual', 'reason' => 'Dimensi dan penanganan sudah diperiksa', 'handling_checked' => true], $overrides));
    }

    private function prepared(): array
    {
        $this->review()->assertRedirect();
        $this->trip->refresh();
        $this->travelTo(CarbonImmutable::parse('2026-11-04T02:00:00Z'));

        return $this->payload();
    }

    private function payload(): array
    {
        return ['lock_version' => $this->trip->lock_version, 'route_version_id' => $this->trip->selected_route_version_id, 'departure_review_id' => app(TripDepartureReviewService::class)->current($this->trip)?->id ?? 1, 'manifest' => array_map(fn ($r) => ['product_id' => $r['product_id'], 'quantity' => $r['quantity']], app(TripManifestService::class)->forTrip($this->trip))];
    }

    private function start(array $payload, ?string $key = null, ?User $user = null)
    {
        $this->app['auth']->forgetGuards();
        $this->withToken(($user ?? $this->courier)->createToken('QA')->plainTextToken);

        return $this->postJson('/api/v1/courier/trips/'.$this->trip->id.'/start', $payload, ['Idempotency-Key' => $key ?? Str::uuid()->toString()]);
    }

    private function assertNotLoaded(): void
    {
        $this->assertSame('assigned', $this->trip->refresh()->status);
        $this->assertDatabaseCount('trip_load_confirmations', 0);
        $this->assertDatabaseCount('inventory_transactions', 2);
        $this->assertDatabaseCount('inventory_entries', 2);
        $this->assertDatabaseCount('inventory_accounts', 4);
        $this->assertDatabaseCount('active_order_allocations', 2);
    }

    public function test_review_checks_all_directed_legs_and_geometry_is_versioned_immutable_and_idempotent(): void
    {
        $this->review(['leg_minutes' => [10, 10]])->assertStatus(409);
        $this->review(['handling_checked' => false])->assertSessionHasErrors('handling_checked');
        $this->review(['source_reference' => '   '])->assertSessionHasErrors('source_reference');
        $this->review(['leg_minutes' => [1440, 1440, 10]])->assertStatus(409);
        $key = Str::uuid()->toString();
        $this->review(['idempotency_key' => $key])->assertRedirect();
        $this->review(['idempotency_key' => $key])->assertRedirect();
        $first = TripDepartureReview::firstOrFail();
        $before = $first->toArray();
        $this->assertSame('manual_road_estimate', $first->source);
        $this->assertTrue($first->handling_checked);
        $this->assertSame([600, 600, 600], $first->leg_seconds);
        $this->assertSame('2026-11-04T02:10:00.000000Z', $first->schedule_snapshot['stops'][0]['estimated_arrival_at']);
        $this->assertSame(3000, $first->schedule_snapshot['stops'][0]['waiting_seconds']);
        $this->assertSame('2026-11-04T03:15:00.000000Z', $first->schedule_snapshot['stops'][1]['estimated_service_start_at']);
        $this->assertSame('2026-11-04T03:30:00.000000Z', $first->schedule_snapshot['estimated_return_at']);
        $this->trip->refresh();
        $this->review(['leg_minutes' => [5, 15, 20]])->assertRedirect();
        $this->assertSame($before, $first->refresh()->toArray());
        $this->assertDatabaseCount('trip_departure_reviews', 2);
        $this->review(['idempotency_key' => $key, 'reason' => 'Berbeda'])->assertStatus(409);
        $this->assertNotLoaded();
    }

    public function test_start_transfers_each_sku_once_consumes_reservations_keeps_claims_and_preserves_other_orders(): void
    {
        $payload = $this->prepared();
        $this->travelTo(CarbonImmutable::parse('2026-11-04T01:59:00Z'));
        $other = app(CheckoutService::class)->checkout($this->customer->id, ['address_id' => $this->address->id, 'delivery_slot_id' => $this->slot->id, 'items' => [['product_id' => $this->products[0]->id, 'quantity' => 1]], 'expected_total_rp' => 18000]);
        $this->travelTo(CarbonImmutable::parse('2026-11-04T02:00:00Z'));
        Product::query()->update(['name' => 'Master baru', 'shipping_weight_g' => 999999, 'is_active' => false]);
        $key = Str::uuid()->toString();
        $this->start($payload, $key)->assertOk()->assertJsonPath('data.status', 'in_progress');
        $this->start($payload, $key)->assertOk();
        $this->start($payload)->assertStatus(409);
        $this->assertSame('in_progress', $this->trip->refresh()->status);
        $this->assertSame(5000, $this->trip->loaded_weight_g);
        $this->assertSame(6000, $this->trip->loaded_volume_cm3);
        $this->assertDatabaseCount('trip_load_confirmations', 1);
        $this->assertDatabaseCount('inventory_entries', 6);
        $this->assertDatabaseCount('inventory_transactions', 3);
        $this->assertDatabaseCount('active_order_allocations', 2);
        $this->assertDatabaseCount('courier_trip_locks', 1);
        $this->assertDatabaseCount('vehicle_trip_locks', 1);
        foreach ($this->products as $i => $p) {
            $qty = $i === 0 ? 4 : 2;
            $this->assertDatabaseHas('inventory_accounts', ['product_id' => $p->id, 'owner_key' => 'depot', 'stock_state' => 'available', 'balance_quantity' => 20 - $qty, 'trip_id' => null]);
            $this->assertDatabaseHas('inventory_accounts', ['product_id' => $p->id, 'owner_key' => 'trip:'.$this->trip->id, 'stock_state' => 'available', 'balance_quantity' => $qty, 'trip_id' => $this->trip->id]);
        }
        foreach (InventoryAccount::all() as $a) {
            $this->assertSame($a->balance_quantity, (int) DB::table('inventory_entries')->where('inventory_account_id', $a->id)->sum('quantity_delta'));
        }
        foreach ($this->orders as $o) {
            $this->assertDatabaseHas('orders', ['id' => $o->id, 'status' => 'out_for_delivery', 'payment_status' => 'unpaid', 'lock_version' => 3]);
            $this->assertDatabaseHas('stock_reservations', ['order_item_id' => $o->items()->first()->id, 'status' => 'consumed']);
        }
        $this->assertDatabaseHas('stock_reservations', ['order_item_id' => $other->items()->first()->id, 'status' => 'active', 'quantity' => 1]);
        $this->getJson('/api/v1/courier/trips/'.$this->trip->id)->assertOk()->assertJsonPath('data.status', 'in_progress')->assertJsonPath('data.can_start', false)->assertJsonPath('data.feasibility_status', 'feasible_manual')->assertJsonPath('data.manifest.0.quantity', 4);
        $this->app['auth']->forgetGuards();
        $this->withToken($this->customer->createToken('customer')->plainTextToken);
        $this->getJson('/api/v1/orders/'.$this->orders[0]->id)->assertJsonPath('data.status', 'out_for_delivery');
        $this->postJson('/api/v1/orders/'.$this->orders[0]->id.'/cancel', ['lock_version' => 3, 'reason' => 'Batal'], ['Idempotency-Key' => Str::uuid()->toString()])->assertStatus(409);
        $this->actingAs($this->admin, 'web');
        foreach (['cancel', 'reopen'] as $action) {
            $this->post('/admin/trips/'.$this->trip->id.'/'.$action, ['lock_version' => $this->trip->lock_version, 'idempotency_key' => Str::uuid()->toString(), 'reason' => 'Tidak boleh'])->assertStatus(409);
        }
        $this->review()->assertStatus(409);
    }

    public function test_wrong_missing_extra_and_duplicate_manifest_items_or_missing_review_roll_back(): void
    {
        $payload = $this->prepared();
        foreach ([array_slice($payload['manifest'], 0, 1), [...$payload['manifest'], ['product_id' => 999, 'quantity' => 1]], array_replace($payload['manifest'], [0 => ['product_id' => $this->products[0]->id, 'quantity' => 3]])] as $manifest) {
            $this->start([...$payload, 'manifest' => $manifest])->assertStatus(409);
            $this->assertNotLoaded();
        }
        $this->start([...$payload, 'manifest' => [$payload['manifest'][0], $payload['manifest'][0]]])->assertUnprocessable();
        $this->start([...$payload, 'departure_review_id' => 999])->assertStatus(409)->assertJsonPath('code', 'DEPARTURE_NOT_REVIEWED');
        $this->assertNotLoaded();
    }

    public function test_early_late_expired_or_changed_plan_cannot_start(): void
    {
        $payload = $this->prepared();
        $this->travelTo(CarbonImmutable::parse('2026-11-04T01:59:59Z'));
        $this->start($payload)->assertStatus(409)->assertJsonPath('code', 'DEPARTURE_NOT_DUE');
        $this->travelTo(CarbonImmutable::parse('2026-11-04T05:00:00Z'));
        $this->start($payload)->assertStatus(409)->assertJsonPath('code', 'SCHEDULE_INFEASIBLE');
        $this->travelTo(CarbonImmutable::parse('2026-11-05T01:00:00Z'));
        $this->start($payload)->assertStatus(409)->assertJsonPath('code', 'DEPARTURE_NOT_REVIEWED');
        $this->assertNotLoaded();
    }

    public function test_reopen_new_review_master_and_order_changes_invalidate_old_start_payload(): void
    {
        $payload = $this->prepared();
        $this->review()->assertRedirect();
        $this->trip->refresh();
        $this->start($payload)->assertStatus(409)->assertJsonPath('code', 'STALE_VERSION');
        $payload = $this->payload();
        Depot::whereKey(1)->increment('lock_version');
        $this->start($payload)->assertStatus(409)->assertJsonPath('code', 'PLAN_CHANGED');
        Depot::whereKey(1)->decrement('lock_version');
        $this->orders[0]->increment('lock_version');
        $this->start($payload)->assertStatus(409)->assertJsonPath('code', 'ORDER_CHANGED');
        $this->orders[0]->decrement('lock_version');
        app(ManualTripService::class)->act($this->admin->id, $this->trip->id, $this->trip->lock_version, 'reopen', 'QA replan');
        $this->start($payload)->assertNotFound();
        $this->assertDatabaseCount('trip_load_confirmations', 0);
    }

    public function test_bad_reservation_balance_or_capacity_does_not_partially_transfer_any_sku(): void
    {
        $payload = $this->prepared();
        $reservation = DB::table('stock_reservations')->first();
        DB::table('stock_reservations')->where('id', $reservation->id)->update(['status' => 'released']);
        $this->start($payload)->assertStatus(409)->assertJsonPath('code', 'RESERVATION_CONFLICT');
        $this->assertNotLoaded();
        DB::table('stock_reservations')->where('id', $reservation->id)->update(['status' => 'active']);
        $account = InventoryAccount::where('product_id', $this->products[1]->id)->where('stock_state', 'available')->firstOrFail();
        $account->update(['balance_quantity' => 1]);
        $this->start($payload)->assertStatus(409)->assertJsonPath('code', 'STOCK_CONFLICT');
        $this->assertNotLoaded();
        $account->update(['balance_quantity' => 20]);
        foreach (['max_load_weight_g', 'max_load_volume_cm3'] as $field) {
            $old = $this->vehicle->$field;
            $this->vehicle->update([$field => 1]);
            $this->start($payload)->assertStatus(409)->assertJsonPath('code', 'CAPACITY_CONFLICT');
            $this->assertNotLoaded();
            $this->vehicle->update([$field => $old]);
        }
    }

    public function test_start_and_review_role_csrf_validation_and_ownership_guards(): void
    {
        $payload = $this->prepared();
        $this->start($payload, user: User::factory()->create(['role' => 'courier']))->assertNotFound();
        $this->start($payload, user: $this->customer)->assertForbidden();
        $this->start($payload, user: $this->admin)->assertForbidden();
        $this->start($payload, user: User::factory()->create(['role' => 'courier', 'is_active' => false]))->assertForbidden();
        $this->start([...$payload, 'courier_id' => $this->courier->id])->assertUnprocessable();
        $this->app['auth']->forgetGuards();
        $this->withToken($this->courier->createToken('QA')->plainTextToken);
        $this->postJson('/api/v1/courier/trips/'.$this->trip->id.'/start', $payload)->assertUnprocessable();
        $this->actingAs($this->admin, 'web');
        $this->app['env'] = 'local';
        $this->review()->assertStatus(419);
        $this->assertNotLoaded();
    }

    public function test_reassignment_requires_new_departure_review_for_the_new_route(): void
    {
        $this->review()->assertRedirect();
        $this->trip->refresh();
        $oldReview = app(TripDepartureReviewService::class)->current($this->trip);
        app(ManualTripService::class)->act($this->admin->id, $this->trip->id, $this->trip->lock_version, 'reopen', 'Replan before departure');
        $this->trip->refresh();
        app(ManualTripService::class)->act($this->admin->id, $this->trip->id, $this->trip->lock_version, 'assign');
        $this->trip->refresh();
        $this->assertNull(app(TripDepartureReviewService::class)->current($this->trip));
        $this->travelTo(CarbonImmutable::parse('2026-11-04T02:00:00Z'));
        $payload = $this->payload();
        $payload['departure_review_id'] = $oldReview->id;
        $this->start($payload)->assertStatus(409)->assertJsonPath('code', 'DEPARTURE_NOT_REVIEWED');
        $this->assertNotLoaded();
    }
}
