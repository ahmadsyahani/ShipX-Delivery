<?php

namespace Tests\Feature;

use App\Models\Address;
use App\Models\DeliverySlot;
use App\Models\Depot;
use App\Models\Product;
use App\Models\Trip;
use App\Models\User;
use App\Models\Vehicle;
use App\Services\CheckoutService;
use App\Services\InventoryService;
use App\Services\OrderLifecycleService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Inertia\Testing\AssertableInertia as Assert;
use Tests\TestCase;

class ManualTripTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $customer;

    private User $courier;

    private Vehicle $vehicle;

    private array $orders;

    protected function setUp(): void
    {
        parent::setUp();
        $this->travelTo(CarbonImmutable::parse('2026-11-04T01:00:00Z'));
        Depot::findOrFail(1)->fill(['address_text' => 'Depot QA', 'latitude' => -7.25, 'longitude' => 112.75, 'service_radius_m' => 5000, 'delivery_fee_rp' => 3000])->save();
        $this->admin = User::factory()->create(['role' => 'admin']);
        $this->customer = User::factory()->create();
        $this->courier = User::factory()->create(['role' => 'courier', 'phone' => '080000000000'])->refresh();
        $this->vehicle = new Vehicle(['code' => 'TRIP-QA', 'name' => 'Motor QA', 'plate_number' => 'B123QA', 'travel_mode' => 'motorcycle', 'max_load_weight_g' => 4000, 'max_load_volume_cm3' => 4000, 'is_active' => true]);
        $this->vehicle->depot_id = 1;
        $this->vehicle->save();
        $this->vehicle->refresh();
        $address = new Address(['label' => 'Rumah', 'recipient_name' => 'Penerima', 'phone' => '080000', 'address_text' => 'Alamat snapshot', 'latitude' => -7.25, 'longitude' => 112.75]);
        $address->user_id = $this->customer->id;
        $address->save();
        $slot = new DeliverySlot(['service_date' => '2026-11-05', 'window_start_at' => '2026-11-05 03:00:00', 'window_end_at' => '2026-11-05 05:00:00', 'cutoff_at' => '2026-11-05 02:00:00', 'is_active' => true]);
        $slot->depot_id = 1;
        $slot->save();
        $p = new Product(['sku' => 'TRIP', 'name' => 'Barang snapshot', 'category' => 'QA', 'unit_label' => 'pak', 'unit_price_rp' => 15000, 'shipping_weight_g' => 1000, 'length_mm' => 100, 'width_mm' => 100, 'height_mm' => 100, 'is_active' => true]);
        $p->depot_id = 1;
        $p->calculateVolume();
        $p->save();
        app(InventoryService::class)->adjust($this->admin->id, $p->id, 'available', 10, 'QA stock', Str::uuid()->toString());
        $this->orders = [];
        for ($i = 0; $i < 2; $i++) {
            $o = app(CheckoutService::class)->checkout($this->customer->id, ['address_id' => $address->id, 'delivery_slot_id' => $slot->id, 'items' => [['product_id' => $p->id, 'quantity' => 2]], 'expected_total_rp' => 33000]);
            app(OrderLifecycleService::class)->decide($this->admin->id, $o->id, 0, 'confirmed');
            $this->orders[] = $o->refresh();
        }
        $this->actingAs($this->admin, 'web');
    }

    private function plan(array $overrides = []): array
    {
        return array_replace(['idempotency_key' => Str::uuid()->toString(), 'courier_id' => $this->courier->id, 'vehicle_id' => $this->vehicle->id, 'departure_local' => '2026-11-05T09:00', 'orders' => array_map(fn ($o) => ['id' => $o->id, 'lock_version' => $o->lock_version], array_reverse($this->orders))], $overrides);
    }

    private function draft(): Trip
    {
        $this->post('/admin/trips', $this->plan())->assertRedirect();

        return Trip::latest('id')->firstOrFail();
    }

    public function test_local_navigation_uses_assigned_snapshot_and_restricts_access_without_business_changes(): void
    {
        $trip = $this->draft();
        $this->action($trip, 'assign')->assertRedirect();
        $trip->refresh();
        $version = $trip->lock_version;
        \Illuminate\Support\Facades\Http::fake(['127.0.0.1:8002/*' => \Illuminate\Support\Facades\Http::response([
            'trip' => ['summary' => ['time' => 180, 'length' => 1.2],
                'legs' => [['shape' => 'encoded-test-route', 'maneuvers' => [[
                    'type' => 15, 'instruction' => 'Turn left', 'street_names' => ['Jalan QA'],
                    'begin_shape_index' => 0, 'end_shape_index' => 1, 'length' => 1.2, 'time' => 180,
                ]]]]],
        ])]);
        $this->app['auth']->forgetGuards();
        $this->withToken($this->courier->createToken('route-QA')->plainTextToken);
        $url = '/api/v1/courier/trips/'.$trip->id.'/navigation';
        $origin = ['latitude' => -7.26, 'longitude' => 112.76];
        $this->postJson($url, $origin)->assertOk()
            ->assertJsonPath('data.target_id', (string) $this->orders[1]->id)
            ->assertJsonPath('data.travel_mode', 'motorcycle')
            ->assertJsonPath('data.guidance', false)
            ->assertJsonPath('data.distance_m', 1200)
            ->assertJsonPath('data.maneuvers.0.instruction', 'Belok kiri menuju Jalan QA');
        \Illuminate\Support\Facades\Http::assertSent(fn ($request) => $request['costing'] === 'motorcycle'
            && $request['locations'][1] === ['lat' => -7.25, 'lon' => 112.75]);
        $this->postJson($url, ['latitude' => 91, 'longitude' => 112])->assertUnprocessable();
        $this->assertSame($version, $trip->fresh()->lock_version);
        $this->assertSame('assigned', $trip->fresh()->status);
        $this->assertDatabaseCount('delivery_results', 0);
        $this->assertDatabaseCount('inventory_entries', 1);
        \Illuminate\Support\Facades\Http::fake(fn () => throw new \Illuminate\Http\Client\ConnectionException());
        $this->postJson($url, $origin)->assertStatus(503)->assertJsonPath('code', 'ROUTING_OFFLINE');
        $this->app['auth']->forgetGuards();
        $this->withToken(User::factory()->create(['role' => 'courier'])->createToken('other-route')->plainTextToken);
        $this->postJson($url, $origin)->assertNotFound();
        $this->app['auth']->forgetGuards();
        $this->withToken($this->customer->createToken('customer-route')->plainTextToken);
        $this->postJson($url, $origin)->assertForbidden();
    }

    private function action(Trip $trip, string $action, array $overrides = [])
    {
        return $this->post('/admin/trips/'.$trip->id.'/'.$action, array_replace(['idempotency_key' => Str::uuid()->toString(), 'lock_version' => $trip->lock_version, 'reason' => 'Perubahan rencana'], $overrides));
    }

    public function test_draft_has_no_claims_and_assignment_preserves_stock_snapshots_and_manual_sequence(): void
    {
        $payload = $this->plan();
        $this->post('/admin/trips', $payload)->assertRedirect();
        $this->post('/admin/trips', $payload)->assertRedirect();
        $t = Trip::firstOrFail();
        $this->assertDatabaseCount('trips', 1);
        $this->assertDatabaseCount('active_order_allocations', 0);
        $this->assertDatabaseCount('trip_stops', 0);
        $this->assertDatabaseHas('orders', ['id' => $this->orders[0]->id, 'status' => 'confirmed', 'lock_version' => 1]);
        $this->assertSame(4000, $t->planned_weight_g);
        $this->assertSame(4000, $t->planned_volume_cm3);
        Product::query()->update(['name' => 'Master baru', 'shipping_weight_g' => 999999]);
        $key = Str::uuid()->toString();
        $this->action($t, 'assign', ['idempotency_key' => $key])->assertRedirect();
        $this->action($t, 'assign', ['idempotency_key' => $key])->assertRedirect();
        $this->assertDatabaseCount('trip_stops', 2);
        $this->assertDatabaseCount('active_order_allocations', 2);
        $this->assertDatabaseCount('courier_trip_locks', 1);
        $this->assertDatabaseCount('vehicle_trip_locks', 1);
        $this->assertDatabaseHas('trip_stops', ['sequence_no' => 1, 'order_id' => $this->orders[1]->id, 'estimated_arrival_at' => null]);
        $this->assertDatabaseHas('orders', ['id' => $this->orders[0]->id, 'status' => 'assigned', 'lock_version' => 2]);
        $this->assertDatabaseHas('stock_reservations', ['status' => 'active', 'quantity' => 2]);
        $this->assertDatabaseHas('inventory_accounts', ['stock_state' => 'available', 'balance_quantity' => 10]);
        $this->assertDatabaseCount('inventory_entries', 1);
        $this->get('/admin/trips/'.$t->id)->assertOk()->assertInertia(fn (Assert $p) => $p->where('trip.selected_route.feasibility_status', 'not_evaluated')->where('trip.selected_route.input_snapshot.orders.0.items.0.name', 'Barang snapshot'));
        $this->get('/admin/trips/'.$t->id)->assertInertia(fn (Assert $p) => $p->where('events.0.created_at', '2026-11-04T01:00:00.000000Z'));
        $this->post('/admin/trips', [...$payload, 'departure_local' => '2026-11-05T09:01'])->assertStatus(409);
    }

    public function test_reopen_appends_route_voids_history_and_reassignment_and_cancellation_release_claims(): void
    {
        $t = $this->draft();
        $firstRoute = $t->selected_route_version_id;
        $this->action($t, 'assign')->assertRedirect();
        $this->action($t->refresh(), 'reopen', ['reason' => 'Ganti urutan'])->assertRedirect();
        $t->refresh();
        $this->assertSame('draft', $t->status);
        $this->assertNotEquals($firstRoute, $t->selected_route_version_id);
        $this->assertDatabaseCount('route_versions', 2);
        $this->assertDatabaseHas('trip_stops', ['route_version_id' => $firstRoute, 'status' => 'voided', 'void_reason' => 'Ganti urutan']);
        $this->assertDatabaseCount('active_order_allocations', 0);
        $this->assertDatabaseHas('orders', ['id' => $this->orders[0]->id, 'status' => 'confirmed', 'lock_version' => 3]);
        $this->action($t, 'assign')->assertRedirect();
        $key = Str::uuid()->toString();
        $t->refresh();
        $this->action($t, 'cancel', ['idempotency_key' => $key])->assertRedirect();
        $this->action($t, 'cancel', ['idempotency_key' => $key])->assertRedirect();
        $this->assertDatabaseCount('trip_stops', 4);
        $this->assertDatabaseCount('active_order_allocations', 0);
        $this->assertDatabaseCount('courier_trip_locks', 0);
        $this->assertDatabaseCount('vehicle_trip_locks', 0);
        $this->assertDatabaseHas('orders', ['id' => $this->orders[0]->id, 'status' => 'confirmed', 'lock_version' => 5]);
        $this->assertDatabaseCount('inventory_entries', 1);
        $this->assertDatabaseHas('stock_reservations', ['status' => 'active']);
        $this->action($t->refresh(), 'assign')->assertStatus(409);
    }

    public function test_duplicate_assignment_is_blocked_for_order_courier_and_vehicle(): void
    {
        $a = $this->draft();
        $b = $this->draft();
        $this->action($a, 'assign')->assertRedirect();
        $this->action($b, 'assign')->assertStatus(409);
        $this->assertDatabaseCount('active_order_allocations', 2);
        $otherCourier = User::factory()->create(['role' => 'courier']);
        $v = $this->vehicle->replicate();
        $v->code = 'OTHER';
        $v->plate_number = 'B999QA';
        $v->save();
        $this->post('/admin/trips', $this->plan(['courier_id' => $otherCourier->id, 'vehicle_id' => $v->id]))->assertStatus(409);
        $this->assertDatabaseCount('trips', 2);
    }

    public function test_capacity_both_dimensions_pending_wrong_wave_time_and_invalid_reservations_are_rechecked(): void
    {
        foreach (['max_load_weight_g', 'max_load_volume_cm3'] as $dimension) {
            $this->vehicle->update([$dimension => 3999]);
            $this->post('/admin/trips', $this->plan())->assertStatus(409);
            $this->vehicle->update([$dimension => 4000]);
        }
        $this->post('/admin/trips', $this->plan(['departure_local' => '2026-11-04T08:00']))->assertStatus(409);
        $this->post('/admin/trips', $this->plan(['departure_local' => '2026-11-05T12:00']))->assertStatus(409);
        $this->orders[0]->update(['status' => 'pending']);
        $this->post('/admin/trips', $this->plan())->assertStatus(409);
        $this->orders[0]->update(['status' => 'confirmed']);
        $slot = DeliverySlot::first()->replicate();
        $slot->window_start_at = $slot->window_start_at->addHour();
        $slot->save();
        $this->orders[0]->update(['delivery_slot_id' => $slot->id]);
        $this->post('/admin/trips', $this->plan())->assertStatus(409);
        $this->orders[0]->update(['delivery_slot_id' => $this->orders[1]->delivery_slot_id]);
        DB::table('stock_reservations')->update(['status' => 'released']);
        $this->post('/admin/trips', $this->plan())->assertStatus(409);
        $this->assertDatabaseCount('trips', 0);
    }

    public function test_stale_drafts_master_changes_and_customer_cancellation_require_review(): void
    {
        $t = $this->draft();
        $this->put('/admin/trips/'.$t->id, $this->plan(['lock_version' => 0, 'orders' => [['id' => $this->orders[0]->id, 'lock_version' => 1]]]))->assertRedirect();
        $this->action($t, 'assign')->assertStatus(409);
        $this->assertDatabaseCount('route_versions', 2);
        $this->vehicle->lock_version++;
        $this->vehicle->save();
        $this->action($t->refresh(), 'assign')->assertStatus(409);
        $this->put('/admin/trips/'.$t->id, $this->plan(['lock_version' => $t->lock_version]))->assertRedirect();
        app(OrderLifecycleService::class)->cancel($this->customer->id, $this->orders[0]->id, 1, 'Customer batal');
        $this->action($t->refresh(), 'assign')->assertStatus(409);
        $this->assertDatabaseCount('active_order_allocations', 0);
        $this->action($t, 'cancel')->assertRedirect();
    }

    public function test_assigned_customer_cannot_cancel_but_can_after_reopen_and_courier_access_is_private(): void
    {
        $t = $this->draft();
        $this->action($t, 'assign')->assertRedirect();
        $this->app['auth']->forgetGuards();
        $this->withToken($this->customer->createToken('QA')->plainTextToken);
        $this->getJson('/api/v1/courier/trips')->assertForbidden();
        $this->getJson('/api/v1/orders/'.$this->orders[0]->id)->assertJsonPath('data.status', 'assigned');
        $this->postJson('/api/v1/orders/'.$this->orders[0]->id.'/cancel', ['lock_version' => 2, 'reason' => 'Batal'], ['Idempotency-Key' => Str::uuid()->toString()])->assertStatus(409)->assertJsonPath('code', 'ORDER_NOT_CANCELLABLE');
        $this->app['auth']->forgetGuards();
        $this->withToken($this->courier->createToken('QA')->plainTextToken);
        $this->getJson('/api/v1/courier/trips')->assertOk()->assertJsonCount(1, 'data')->assertJsonMissingPath('data.0.stops')->assertJsonMissingPath('data.0.vehicle.lock_version');
        $this->getJson('/api/v1/courier/trips/'.$t->id)->assertOk()->assertJsonPath('data.stops.0.order_id', (string) $this->orders[1]->id)->assertJsonPath('data.stops.0.estimated_arrival_at', null)->assertJsonMissingPath('data.created_by');
        $this->app['auth']->forgetGuards();
        $other = User::factory()->create(['role' => 'courier']);
        $this->withToken($other->createToken('QA')->plainTextToken);
        $this->getJson('/api/v1/courier/trips')->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/courier/trips/'.$t->id)->assertNotFound();
        $this->actingAs($this->admin, 'web');
        $this->action($t->refresh(), 'reopen')->assertRedirect();
        $this->app['auth']->forgetGuards();
        $this->withToken($this->courier->createToken('QA2')->plainTextToken);
        $this->getJson('/api/v1/courier/trips/'.$t->id)->assertNotFound();
        app(OrderLifecycleService::class)->cancel($this->customer->id, $this->orders[0]->id, 3, 'Customer batal');
        $this->assertDatabaseHas('orders', ['id' => $this->orders[0]->id, 'status' => 'cancelled']);
    }

    public function test_validation_roles_inactive_fleet_and_guards_after_departure(): void
    {
        $this->post('/admin/trips', $this->plan(['orders' => [['id' => $this->orders[0]->id, 'lock_version' => 1], ['id' => $this->orders[0]->id, 'lock_version' => 1]]]))->assertSessionHasErrors('orders.0.id');
        $this->post('/admin/trips', $this->plan(['courier_id' => $this->customer->id]))->assertStatus(409);
        $this->courier->is_active = false;
        $this->courier->save();
        $this->post('/admin/trips', $this->plan())->assertStatus(409);
        $this->courier->is_active = true;
        $this->courier->save();
        $t = $this->draft();
        $this->action($t, 'reopen')->assertStatus(409);
        $this->action($t, 'assign')->assertRedirect();
        $t->refresh()->update(['actual_departure_at' => now()]);
        $this->action($t, 'cancel')->assertStatus(409);
        $this->action($t, 'reopen')->assertStatus(409);
        $this->actingAs($this->customer, 'web');
        $this->post('/admin/trips', $this->plan())->assertForbidden();
        $this->get('/admin/trips')->assertForbidden();
    }

    public function test_assigned_masters_cannot_be_edited_and_cancelled_draft_never_releases_order_reservations(): void
    {
        $t = $this->draft();
        $this->action($t, 'assign')->assertRedirect();
        $this->put('/admin/vehicles/'.$this->vehicle->id, [...$this->vehicle->only(['code', 'name', 'plate_number', 'travel_mode', 'max_load_weight_g', 'max_load_volume_cm3', 'is_active', 'lock_version']), 'name' => 'Changed'])->assertStatus(409);
        $this->put('/admin/couriers/'.$this->courier->id, [...$this->courier->only(['name', 'email', 'phone', 'is_active', 'lock_version']), 'name' => 'Changed'])->assertStatus(409);
        $this->action($t->refresh(), 'reopen')->assertRedirect();
        $this->action($t->refresh(), 'cancel', ['reason' => ''])->assertSessionHasErrors('reason');
        $this->action($t, 'cancel')->assertRedirect();
        $this->assertDatabaseHas('stock_reservations', ['status' => 'active']);
        $this->assertDatabaseCount('inventory_entries', 1);
    }

    public function test_departure_and_all_master_versions_are_revalidated_at_assignment(): void
    {
        $t = $this->draft();
        Depot::whereKey(1)->increment('lock_version');
        $this->action($t, 'assign')->assertStatus(409);
        $this->put('/admin/trips/'.$t->id, $this->plan(['lock_version' => 0]))->assertRedirect();
        $this->courier->increment('lock_version');
        $this->action($t->refresh(), 'assign')->assertStatus(409);
        $this->put('/admin/trips/'.$t->id, $this->plan(['lock_version' => $t->lock_version]))->assertRedirect();
        $this->vehicle->is_active = false;
        $this->vehicle->save();
        $this->action($t->refresh(), 'assign')->assertStatus(409);
        $this->vehicle->is_active = true;
        $this->vehicle->save();
        $this->travelTo(CarbonImmutable::parse('2026-11-05T02:00:00Z'));
        $this->action($t, 'assign')->assertStatus(409);
        $this->assertDatabaseCount('active_order_allocations', 0);
        $this->assertDatabaseCount('inventory_entries', 1);
    }

    public function test_admin_session_csrf_and_courier_bearer_active_guards_apply_to_trips(): void
    {
        $this->post('/admin/trips', $this->plan(['status' => 'assigned', 'depot_id' => 9]))->assertSessionHasErrors(['status', 'depot_id']);
        $t = $this->draft();
        $this->app['env'] = 'local';
        $this->action($t, 'assign')->assertStatus(419);
        $this->post('/admin/trips', $this->plan())->assertStatus(419);
        $this->app['env'] = 'testing';
        $this->actingAs(User::factory()->create(['role' => 'admin', 'is_active' => false]), 'web');
        $this->action($t, 'assign')->assertForbidden();
        auth('web')->logout();
        $this->withToken($this->admin->createToken('QA')->plainTextToken);
        $this->action($t, 'assign')->assertRedirect('/admin/login');
        $this->app['auth']->forgetGuards();
        $this->courier->is_active = false;
        $this->courier->save();
        $this->withToken($this->courier->createToken('QA')->plainTextToken);
        $this->getJson('/api/v1/courier/trips')->assertForbidden();
        $this->assertDatabaseCount('active_order_allocations', 0);
    }
    private function optimizationInput(int $version = 0): array
    {
        return ['lock_version' => $version, 'source_reference' => 'Peta jalan QA, mode motor, dua arah diperiksa', 'matrix_minutes' => [[0, 10, 1], [1, 0, 10], [10, 1, 0]]];
    }

    public function test_optimization_preview_apply_replay_and_assignment_use_server_selected_route(): void
    {
        $trip = $this->draft();
        $url = '/admin/trips/'.$trip->id.'/optimization';
        $preview = $this->postJson($url.'/preview', $this->optimizationInput())->assertOk()->json('data');
        $ids = array_map(fn ($order) => (string) $order->id, $this->orders);
        $this->assertSame($ids, $preview['selected']['order_ids']);
        $this->assertDatabaseCount('route_versions', 1);
        $this->assertDatabaseCount('trip_stops', 0);
        $payload = ['idempotency_key' => Str::uuid()->toString(), 'optimization_id' => $preview['id'], 'lock_version' => 0, 'order_ids' => ['999999']];
        $this->post($url.'/apply', $payload)->assertRedirect('/admin/trips/'.$trip->id);
        $this->post($url.'/apply', $payload)->assertRedirect('/admin/trips/'.$trip->id);
        $this->assertDatabaseCount('route_versions', 2);
        $this->assertDatabaseCount('trip_optimizations', 1);
        $trip->refresh();
        $snapshot = $trip->selectedRoute->input_snapshot;
        $this->assertSame($ids, array_column($snapshot['orders'], 'id'));
        $this->assertSame([60, 60, 60], $snapshot['optimization']['leg_seconds']);
        $this->assertSame(0, DB::table('active_order_allocations')->count());
        $this->assertSame(1, DB::table('inventory_entries')->count());
        $this->action($trip, 'assign')->assertRedirect();
        $this->assertSame(array_map('intval', $ids), DB::table('trip_stops')->where('trip_id', $trip->id)->orderBy('sequence_no')->pluck('order_id')->all());
        $this->postJson($url.'/preview', $this->optimizationInput($trip->fresh()->lock_version))->assertStatus(409);
        $this->travelTo(CarbonImmutable::parse('2026-11-04T03:00:00Z'));
        $this->post('/admin/trips/'.$trip->id.'/departure-review', [
            'idempotency_key' => Str::uuid()->toString(), 'lock_version' => $trip->fresh()->lock_version,
            'leg_minutes' => [1, 1, 1], 'source_reference' => $snapshot['optimization']['source_reference'],
            'reason' => 'Tinjauan rute optimasi dan penanganan barang', 'handling_checked' => true,
        ])->assertRedirect();
        $trip->refresh();
        $review = app(\App\Services\TripDepartureReviewService::class)->current($trip);
        $this->travelTo(CarbonImmutable::parse('2026-11-05T02:00:00Z'));
        auth('web')->logout();
        $this->app['auth']->forgetGuards();
        $this->withToken($this->courier->createToken('QA optimizer')->plainTextToken);
        $start = ['lock_version' => $trip->lock_version, 'route_version_id' => $trip->selected_route_version_id, 'departure_review_id' => $review->id,
            'manifest' => array_map(fn ($row) => ['product_id' => $row['product_id'], 'quantity' => $row['quantity']], app(\App\Services\TripManifestService::class)->forTrip($trip))];
        $this->postJson('/api/v1/courier/trips/'.$trip->id.'/start', $start, ['Idempotency-Key' => Str::uuid()->toString()])->assertOk()->assertJsonPath('data.status', 'in_progress');
        $this->getJson('/api/v1/courier/trips/'.$trip->id)->assertOk()->assertJsonPath('data.stops.0.order_id', $ids[0]);
        $this->assertDatabaseCount('trip_load_confirmations', 1);

    }

    public function test_optimization_detects_stale_master_expired_preview_and_wrong_actor(): void
    {
        $trip = $this->draft();
        $url = '/admin/trips/'.$trip->id.'/optimization';
        $preview = $this->postJson($url.'/preview', $this->optimizationInput())->assertOk()->json('data');
        $payload = ['idempotency_key' => Str::uuid()->toString(), 'optimization_id' => $preview['id'], 'lock_version' => 0];
        $this->actingAs(User::factory()->create(['role' => 'admin']), 'web');
        $this->post($url.'/apply', $payload)->assertNotFound();
        $this->actingAs($this->admin, 'web');
        $this->travelTo(now()->addMinutes(31));
        $this->post($url.'/apply', array_replace($payload, ['idempotency_key' => Str::uuid()->toString()]))->assertStatus(409);
        $fresh = $this->postJson($url.'/preview', $this->optimizationInput())->assertOk()->json('data');
        Depot::whereKey(1)->increment('lock_version');
        $this->post($url.'/apply', array_replace($payload, ['idempotency_key' => Str::uuid()->toString(), 'optimization_id' => $fresh['id']]))->assertStatus(409);
        $this->assertDatabaseCount('route_versions', 1);
        $this->assertDatabaseCount('active_order_allocations', 0);
    }

    public function test_optimization_rejects_incomplete_data_no_feasible_route_and_insufficient_capacity(): void
    {
        $trip = $this->draft();
        $url = '/admin/trips/'.$trip->id.'/optimization';
        $this->postJson($url.'/preview', array_replace($this->optimizationInput(), ['matrix_minutes' => [[0, 1], [1, 0]]]))->assertStatus(409)->assertJsonPath('code', 'ROAD_DATA_INCOMPLETE');
        $this->postJson($url.'/preview', array_replace($this->optimizationInput(), ['source_reference' => '']))->assertUnprocessable();
        $this->postJson($url.'/preview', array_replace($this->optimizationInput(), ['matrix_minutes' => [[1, 1, 1], [1, 0, 1], [1, 1, 0]]]))->assertStatus(409)->assertJsonPath('code', 'ROAD_DATA_INVALID');
        $preview = $this->postJson($url.'/preview', array_replace($this->optimizationInput(), ['matrix_minutes' => [[0, 300, 300], [300, 0, 300], [300, 300, 0]]]))->assertOk()->assertJsonPath('data.selected', null)->json('data');
        $this->post($url.'/apply', ['idempotency_key' => Str::uuid()->toString(), 'optimization_id' => $preview['id'], 'lock_version' => 0])->assertStatus(409);
        $this->vehicle->update(['max_load_weight_g' => 3999]);
        $this->postJson($url.'/preview', $this->optimizationInput())->assertStatus(409)->assertJsonPath('code', 'CAPACITY_EXCEEDED');
        $this->assertDatabaseCount('route_versions', 1);
    }

    public function test_optimization_admin_role_and_csrf_are_enforced(): void
    {
        $trip = $this->draft();
        $url = '/admin/trips/'.$trip->id.'/optimization';
        $this->actingAs($this->customer, 'web');
        $this->postJson($url.'/preview', $this->optimizationInput())->assertForbidden();
        $this->actingAs($this->admin, 'web');
        $this->app['env'] = 'local';
        $this->postJson($url.'/preview', $this->optimizationInput())->assertStatus(419);
        $this->post($url.'/apply', ['idempotency_key' => Str::uuid()->toString(), 'optimization_id' => Str::uuid()->toString(), 'lock_version' => 0])->assertStatus(419);
        $this->app['env'] = 'testing';
        $this->assertDatabaseCount('trip_optimizations', 0);
    }

    public function test_trip_form_groups_customer_schedule_and_preserves_service_choices(): void
    {
        $slot = new DeliverySlot(['service_date' => '2026-11-06', 'window_start_at' => '2026-11-06T03:00:00Z', 'window_end_at' => '2026-11-06T04:00:00Z', 'cutoff_at' => '2026-11-06T02:00:00Z', 'is_active' => true]);
        $slot->depot_id = 1;
        $slot->save();
        $express = app(CheckoutService::class)->checkout($this->customer->id, ['address_id' => $this->orders[0]->source_address_id, 'delivery_slot_id' => $slot->id,
            'delivery_type' => 'express', 'items' => [['product_id' => $this->orders[0]->items->first()->product_id, 'quantity' => 1]], 'expected_total_rp' => 19500]);
        app(OrderLifecycleService::class)->decide($this->admin->id, $express->id, 0, 'confirmed');
        $this->get('/admin/trips/create')->assertOk()->assertInertia(fn (Assert $page) => $page
            ->has('deliveryGroups', 2)->where('deliveryGroups.0.order_count', 2)->where('deliveryGroups.0.regular_count', 2)
            ->where('deliveryGroups.0.default_departure_local', '2026-11-05T10:00')->where('deliveryGroups.0.service_date', '2026-11-05')
            ->where('deliveryGroups.1.order_count', 1)->where('deliveryGroups.1.express_count', 1)->where('deliveryGroups.1.service_date', '2026-11-06'));
        $this->post('/admin/trips', $this->plan(['departure_local' => '2026-11-06T10:00']))->assertStatus(409);
        $this->assertSame('2026-11-05T03:00:00.000000Z', $this->orders[0]->fresh()->window_start_at->toISOString());
    }

    public function test_recommended_departure_recovers_a_too_late_manual_plan_and_is_applied_with_route(): void
    {
        $this->post('/admin/trips', $this->plan(['departure_local' => '2026-11-05T11:50']))->assertRedirect();
        $trip = Trip::firstOrFail();
        $url = '/admin/trips/'.$trip->id.'/optimization';
        $this->postJson($url.'/preview', $this->optimizationInput())->assertOk()->assertJsonPath('data.selected', null);
        $data = array_replace($this->optimizationInput(), ['recommend_departure' => true]);
        $result = $this->postJson($url.'/preview', $data)->assertOk()->assertJsonPath('data.departure_recommended', true)
            ->assertJsonPath('data.departure_local', '2026-11-05T09:59')->json('data');
        $this->assertNotNull($result['selected']);
        $this->assertSame('2026-11-05T04:50:00.000000Z', $trip->fresh()->planned_departure_at->toISOString());
        $this->post($url.'/apply', ['optimization_id' => $result['id'], 'lock_version' => 0, 'idempotency_key' => Str::uuid()->toString()])->assertRedirect();
        $this->assertSame('2026-11-05T02:59:00.000000Z', $trip->fresh()->planned_departure_at->toISOString());
        $this->assertSame('2026-11-05T09:59', $trip->fresh()->selectedRoute->input_snapshot['plan']['departure_local']);
        foreach ($this->orders as $order) {
            $this->assertSame('2026-11-05T03:00:00.000000Z', $order->fresh()->window_start_at->toISOString());
        }
    }

    public function test_recommended_departure_respects_opening_and_remaining_preparation_time(): void
    {
        $this->post('/admin/trips', $this->plan(['departure_local' => '2026-11-05T11:50']))->assertRedirect();
        $trip = Trip::firstOrFail();
        $url = '/admin/trips/'.$trip->id.'/optimization';
        $data = array_replace($this->optimizationInput(), ['recommend_departure' => true, 'matrix_minutes' => [[0, 120, 120], [1, 0, 1], [1, 1, 0]]]);
        $this->postJson($url.'/preview', $data)->assertOk()->assertJsonPath('data.departure_local', '2026-11-05T08:00');
        $this->travelTo(CarbonImmutable::parse('2026-11-05T04:40:00Z'));
        $this->postJson($url.'/preview', array_replace($this->optimizationInput(), ['recommend_departure' => true]))->assertOk()->assertJsonPath('data.selected', null);
        $this->assertDatabaseCount('route_versions', 1);
    }

}
