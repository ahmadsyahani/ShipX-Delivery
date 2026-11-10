<?php

namespace Tests\Feature;

use App\Models\Address;
use App\Models\DeliverySlot;
use App\Models\Depot;
use App\Models\InventoryAccount;
use App\Models\Order;
use App\Models\Product;
use App\Models\Trip;
use App\Models\User;
use App\Models\Vehicle;
use App\Services\CheckoutService;
use App\Services\InventoryService;
use App\Services\ManualTripService;
use App\Services\OrderLifecycleService;
use App\Services\TripDepartureReviewService;
use App\Services\TripDepartureService;
use App\Services\TripManifestService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

class DeliveryResultTest extends TestCase
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
        app(TripDepartureReviewService::class)->review($this->admin->id, $this->trip->id, ['lock_version' => 1, 'leg_minutes' => [5, 5, 5], 'source_reference' => 'QA manual road review', 'reason' => 'QA checked', 'handling_checked' => true]);
        $this->trip->refresh();
        $this->travelTo(CarbonImmutable::parse('2026-11-04T02:00:00Z'));
        app(TripDepartureService::class)->start($this->courier->id, $this->trip->id, ['lock_version' => $this->trip->lock_version, 'route_version_id' => (int) $this->trip->selected_route_version_id, 'departure_review_id' => app(TripDepartureReviewService::class)->current($this->trip)->id, 'manifest' => array_map(fn ($r) => ['product_id' => (int) $r['product_id'], 'quantity' => $r['quantity']], app(TripManifestService::class)->forTrip($this->trip))]);
        $this->trip->refresh();
        Storage::fake('local');
        $this->app['auth']->forgetGuards();
        $this->withToken($this->courier->createToken('QA')->plainTextToken);
    }

    private function reconciliationData(array $overrides = []): array
    {
        return array_replace([
            'idempotency_key' => Str::uuid()->toString(), 'lock_version' => $this->trip->refresh()->lock_version,
            'actual_cash_rp' => 48000, 'discrepancy_reason' => null, 'received_and_approved' => true,
            'items' => array_map(fn ($p, $i) => ['product_id' => $p->id, 'available_quantity' => $i === 0 ? 2 : 1, 'quarantine_quantity' => 0, 'discrepancy_reason' => null], $this->products, array_keys($this->products)),
        ], $overrides);
    }

    private function readyForReconciliation(): void
    {
        $photo = $this->photo()->assertCreated()->json('data.id');
        $this->recordResult('delivered', overrides: ['proof_upload_id' => $photo])->assertOk();
        $this->recordResult('failed', 1)->assertOk();
        $this->flushHeaders();
        $this->actingAs($this->admin, 'web');
    }

    public function test_reconciliation_returns_each_sku_records_cod_and_releases_claims_once(): void
    {
        $this->readyForReconciliation();
        $data = $this->reconciliationData();
        $url = '/admin/trips/'.$this->trip->id.'/reconcile';
        $this->post($url, $data)->assertRedirect('/admin/trips/'.$this->trip->id);
        $this->post($url, $data)->assertRedirect();
        $this->assertDatabaseCount('trip_reconciliations', 1);
        $this->assertDatabaseCount('reconciliation_items', 4);
        $this->assertDatabaseHas('trip_reconciliations', ['expected_cash_rp' => 48000, 'actual_cash_rp' => 48000, 'cash_difference_rp' => 0, 'approved_by' => $this->admin->id]);
        $this->assertSame('completed', $this->trip->refresh()->status);
        $this->assertNotNull($this->trip->actual_return_at);
        foreach (['active_order_allocations', 'courier_trip_locks', 'vehicle_trip_locks'] as $table) {
            $this->assertDatabaseCount($table, 0);
        }
        foreach ($this->products as $i => $p) {
            $this->assertDatabaseHas('inventory_accounts', ['product_id' => $p->id, 'owner_key' => 'depot', 'stock_state' => 'available', 'balance_quantity' => $i === 0 ? 18 : 19]);
            $this->assertSame(0, (int) InventoryAccount::where('owner_key', 'trip:'.$this->trip->id)->where('product_id', $p->id)->sum('balance_quantity'));
        }
        $this->assertSame(1, DB::table('inventory_transactions')->where('event_key', 'reconciliation:'.$this->trip->id)->count());
        $this->assertSame(48000, (int) DB::table('payment_collections')->sum('amount_rp'));
        $this->get('/admin/trips?status=completed')->assertOk();
        $this->get('/admin/trips/'.$this->trip->id)->assertOk();
        $this->post($url, array_replace($data, ['idempotency_key' => Str::uuid()->toString(), 'lock_version' => $this->trip->lock_version]))->assertStatus(409);
        $this->post($url, array_replace($data, ['actual_cash_rp' => 1]))->assertStatus(409);
    }

    public function test_stock_and_cash_discrepancies_require_reasons_and_approval_before_any_mutation(): void
    {
        $this->readyForReconciliation();
        $url = '/admin/trips/'.$this->trip->id.'/reconcile';
        $data = $this->reconciliationData(['actual_cash_rp' => 47000]);
        $this->post($url, $data)->assertStatus(409);
        $data['idempotency_key'] = Str::uuid()->toString();
        $data['discrepancy_reason'] = 'Setoran kurang seribu, ditinjau admin';
        $data['items'][0]['available_quantity'] = 1;
        $data['items'][0]['quarantine_quantity'] = 1;
        $this->post($url, $data)->assertStatus(409);
        $this->assertDatabaseCount('trip_reconciliations', 0);
        $this->assertDatabaseCount('courier_trip_locks', 1);
        $data['idempotency_key'] = Str::uuid()->toString();
        $data['items'][0]['discrepancy_reason'] = 'Satu kemasan rusak saat kembali';
        $this->post($url, array_replace($data, ['received_and_approved' => false]))->assertSessionHasErrors('received_and_approved');
        $this->post($url, $data)->assertRedirect();
        $this->assertDatabaseHas('trip_reconciliations', ['cash_difference_rp' => -1000, 'discrepancy_reason' => $data['discrepancy_reason']]);
        $this->assertDatabaseHas('inventory_accounts', ['product_id' => $this->products[0]->id, 'owner_key' => 'depot', 'stock_state' => 'quarantine', 'balance_quantity' => 1]);
        $this->assertDatabaseHas('reconciliation_items', ['product_id' => $this->products[0]->id, 'stock_state' => 'available', 'difference' => -1]);
        $this->assertDatabaseHas('reconciliation_items', ['product_id' => $this->products[0]->id, 'stock_state' => 'quarantine', 'expected_quantity' => 0, 'difference' => 1]);
        $this->assertSame(48000, (int) DB::table('payment_collections')->sum('amount_rp'));
    }

    public function test_reconciliation_rejects_missing_duplicate_foreign_items_stale_versions_and_nonfinal_trip(): void
    {
        $this->flushHeaders();
        $this->actingAs($this->admin, 'web');
        $url = '/admin/trips/'.$this->trip->id.'/reconcile';
        $this->post($url, $this->reconciliationData())->assertStatus(409);
        $this->app['auth']->forgetGuards();
        $this->flushHeaders();
        $this->withToken($this->courier->createToken('QA')->plainTextToken);
        $this->readyForReconciliation();
        $data = $this->reconciliationData();
        $this->post($url, array_replace($data, ['lock_version' => 0]))->assertStatus(409);
        $this->post($url, $this->reconciliationData(['items' => [$data['items'][0]]]))->assertStatus(409);
        $this->post($url, $this->reconciliationData(['items' => [$data['items'][0], $data['items'][0]]]))->assertSessionHasErrors('items.0.product_id');
        $data['items'][0]['product_id'] = 999999;
        $this->post($url, $this->reconciliationData(['items' => $data['items']]))->assertStatus(409);
        $this->post($url, $this->reconciliationData(['actual_cash_rp' => -1]))->assertSessionHasErrors('actual_cash_rp');
        $this->post($url, $this->reconciliationData(['approved_by' => $this->customer->id]))->assertSessionHasErrors('approved_by');
        $this->assertDatabaseCount('trip_reconciliations', 0);
        $this->assertSame('awaiting_reconciliation', $this->trip->refresh()->status);
    }

    public function test_excess_missing_items_and_cash_surplus_are_audited_without_modifying_delivery_results(): void
    {
        $this->readyForReconciliation();
        $extra = $this->products[0]->replicate();
        $extra->sku = 'EXTRA-RETURN';
        $extra->is_active = false;
        $extra->save();
        $data = $this->reconciliationData(['actual_cash_rp' => 49000, 'discrepancy_reason' => 'Kelebihan uang ditinjau']);
        $data['items'][0]['available_quantity'] = 0;
        $data['items'][0]['discrepancy_reason'] = 'Barang hilang';
        $data['items'][] = ['product_id' => $extra->id, 'available_quantity' => 3, 'quarantine_quantity' => 0, 'discrepancy_reason' => 'Barang tambahan ikut kembali'];
        $this->post('/admin/trips/'.$this->trip->id.'/reconcile', $data)->assertRedirect();
        $this->assertDatabaseHas('reconciliation_items', ['product_id' => $extra->id, 'stock_state' => 'available', 'expected_quantity' => 0, 'actual_quantity' => 3, 'difference' => 3]);
        $this->assertDatabaseHas('inventory_accounts', ['product_id' => $extra->id, 'owner_key' => 'depot', 'balance_quantity' => 3]);
        $this->assertDatabaseHas('trip_reconciliations', ['cash_difference_rp' => 1000]);
        $this->assertDatabaseCount('delivery_results', 2);
        $this->assertDatabaseHas('orders', ['id' => $this->orders[1]->id, 'status' => 'failed', 'payment_status' => 'unpaid']);
    }

    public function test_only_active_admin_can_close_and_courier_can_read_only_their_completed_receipt(): void
    {
        $this->readyForReconciliation();
        $url = '/admin/trips/'.$this->trip->id.'/reconcile';
        foreach ([$this->courier, $this->customer, User::factory()->create(['role' => 'admin', 'is_active' => false])] as $actor) {
            $this->actingAs($actor, 'web')->post($url, $this->reconciliationData())->assertForbidden();
        }
        $this->actingAs($this->admin, 'web')->post($url, $this->reconciliationData())->assertRedirect();
        $this->app['auth']->forgetGuards();
        $this->withToken($this->courier->createToken('QA')->plainTextToken);
        $this->getJson('/api/v1/courier/trips')->assertJsonCount(0, 'data')->assertJsonCount(1, 'recent_completed');
        $this->getJson('/api/v1/courier/trips/'.$this->trip->id)->assertOk()->assertJsonPath('data.status', 'completed')->assertJsonPath('data.can_start', false)->assertJsonPath('data.reconciliation.record.actual_cash_rp', 48000)->assertJsonPath('data.reconciliation.record.trip_id', (string) $this->trip->id)->assertJsonPath('data.reconciliation.record.items.0.product_id', (string) $this->products[0]->id)->assertJsonPath('data.stops.0.can_record_result', false);
        $this->app['auth']->forgetGuards();
        $this->withToken(User::factory()->create(['role' => 'courier'])->createToken('QA')->plainTextToken);
        $this->getJson('/api/v1/courier/trips/'.$this->trip->id)->assertNotFound();
    }

    public function test_all_failed_returns_entire_load_with_zero_cash(): void
    {
        $this->recordResult('failed')->assertOk();
        $this->recordResult('failed', 1)->assertOk();
        $this->flushHeaders();
        $this->actingAs($this->admin, 'web');
        $data = $this->reconciliationData(['actual_cash_rp' => 0]);
        $data['items'][0]['available_quantity'] = 4;
        $data['items'][1]['available_quantity'] = 2;
        $this->post('/admin/trips/'.$this->trip->id.'/reconcile', $data)->assertRedirect();
        $this->assertDatabaseHas('trip_reconciliations', ['expected_cash_rp' => 0, 'actual_cash_rp' => 0]);
        foreach ($this->products as $product) {
            $this->assertDatabaseHas('inventory_accounts', ['product_id' => $product->id, 'owner_key' => 'depot', 'stock_state' => 'available', 'balance_quantity' => 20]);
        }
    }

    public function test_all_delivered_closes_with_zero_returned_items_and_full_cash(): void
    {
        foreach ([0, 1] as $index) {
            $proof = $this->photo($index)->assertCreated()->json('data.id');
            $this->recordResult('delivered', $index, ['proof_upload_id' => $proof])->assertOk();
        }
        $this->flushHeaders();
        $this->actingAs($this->admin, 'web');
        $data = $this->reconciliationData(['actual_cash_rp' => 96000]);
        foreach ($data['items'] as &$row) {
            $row['available_quantity'] = 0;
        }
        unset($row);
        $this->post('/admin/trips/'.$this->trip->id.'/reconcile', $data)->assertRedirect();
        $this->assertDatabaseHas('trip_reconciliations', ['expected_cash_rp' => 96000, 'actual_cash_rp' => 96000]);
        $this->assertSame(0, (int) DB::table('reconciliation_items')->sum('actual_quantity'));
        $this->assertSame(0, DB::table('inventory_entries')->join('inventory_transactions', 'inventory_transactions.id', '=', 'inventory_entries.inventory_transaction_id')->where('kind', 'reconciliation')->count());
    }

    public function test_failure_after_stock_mutation_rolls_back_receipt_ledger_and_claim_release(): void
    {
        $this->readyForReconciliation();
        $before = InventoryAccount::orderBy('id')->get()->toArray();
        DB::unprepared("CREATE TRIGGER qa_reconciliation_failure BEFORE INSERT ON trip_reconciliations BEGIN SELECT RAISE(ABORT, 'QA forced failure'); END");
        try {
            app(\App\Services\TripReconciliationService::class)->close($this->admin->id, $this->trip->id, $this->reconciliationData());
            $this->fail('Expected forced database failure.');
        } catch (\Illuminate\Database\QueryException $error) {
            $this->assertStringContainsString('QA forced failure', $error->getMessage());
        } finally {
            DB::unprepared('DROP TRIGGER qa_reconciliation_failure');
        }
        $this->assertSame($before, InventoryAccount::orderBy('id')->get()->toArray());
        $this->assertDatabaseCount('trip_reconciliations', 0);
        $this->assertSame(0, DB::table('inventory_transactions')->where('kind', 'reconciliation')->count());
        $this->assertDatabaseCount('courier_trip_locks', 1);
        $this->assertSame('awaiting_reconciliation', $this->trip->refresh()->status);
        $this->assertNull($this->trip->actual_return_at);
    }

    private function stop(int $index = 0): object
    {
        return DB::table('trip_stops')->where('trip_id', $this->trip->id)->orderBy('sequence_no')->get()[$index];
    }

    private function photo(int $index = 0, ?string $key = null)
    {
        $file = UploadedFile::fake()->createWithContent('proof.png', base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='));

        return $this->post('/api/v1/courier/trips/'.$this->trip->id.'/stops/'.$this->stop($index)->id.'/proofs', ['photo' => $file], ['Accept' => 'application/json', 'Idempotency-Key' => $key ?? Str::uuid()->toString()]);
    }

    private function recordResult(string $outcome, int $index = 0, array $overrides = [], ?string $key = null)
    {
        $stop = $this->stop($index);
        $data = array_replace(['trip_version' => $this->trip->refresh()->lock_version, 'order_version' => Order::findOrFail($stop->order_id)->lock_version, 'outcome' => $outcome, 'cash_received_rp' => $outcome === 'delivered' ? 48000 : 0, 'failure_reason' => $outcome === 'failed' ? 'Penerima tidak berada di lokasi' : null, 'notes' => 'QA', 'proof_upload_id' => null], $overrides);

        return $this->postJson('/api/v1/courier/trips/'.$this->trip->id.'/stops/'.$stop->id.'/result', $data, ['Idempotency-Key' => $key ?? Str::uuid()->toString()]);
    }

    public function test_delivered_is_atomic_with_private_proof_cash_and_multi_sku_ledger(): void
    {
        $uploadKey = Str::uuid()->toString();
        $upload = $this->photo(key: $uploadKey)->assertCreated()->json('data.id');
        $this->photo(key: $uploadKey)->assertOk()->assertJsonPath('data.id', $upload);
        $key = Str::uuid()->toString();
        $version = $this->trip->lock_version;
        $this->recordResult('delivered', overrides: ['proof_upload_id' => $upload], key: $key)->assertOk()->assertJsonPath('data.outcome', 'delivered');
        $this->recordResult('delivered', overrides: ['trip_version' => $version, 'order_version' => 3, 'proof_upload_id' => $upload], key: $key)->assertOk();
        $this->assertDatabaseCount('delivery_results', 1);
        $this->assertDatabaseCount('delivery_proofs', 1);
        $this->assertDatabaseCount('payment_collections', 1);
        $this->assertDatabaseHas('payment_collections', ['amount_rp' => 48000, 'method' => 'cash']);
        $this->assertDatabaseHas('orders', ['id' => $this->stop()->order_id, 'status' => 'delivered', 'payment_status' => 'paid']);
        foreach ($this->products as $i => $product) {
            $this->assertDatabaseHas('inventory_accounts', ['product_id' => $product->id, 'owner_key' => 'trip:'.$this->trip->id, 'stock_state' => 'available', 'balance_quantity' => $i === 0 ? 2 : 1]);
        }
        $proof = DB::table('delivery_proofs')->first();
        $this->get('/api/v1/delivery-proofs/'.$proof->id)->assertOk()->assertHeader('X-Content-Type-Options', 'nosniff');
        $this->app['auth']->forgetGuards();
        $this->withToken($this->customer->createToken('QA')->plainTextToken);
        $this->getJson('/api/v1/orders/'.$this->stop()->order_id)->assertJsonPath('data.delivery_result.cash_received_rp', 48000);
        $this->get('/api/v1/delivery-proofs/'.$proof->id)->assertOk();
        $this->app['auth']->forgetGuards();
        $this->withToken(User::factory()->create()->createToken('QA')->plainTextToken);
        $this->get('/api/v1/delivery-proofs/'.$proof->id)->assertNotFound();
    }

    public function test_failed_keeps_stock_and_final_stop_waits_for_reconciliation_with_claims_held(): void
    {
        $this->recordResult('failed')->assertOk();
        $this->recordResult('failed', 1)->assertOk()->assertJsonPath('data.trip_status', 'awaiting_reconciliation');
        $this->assertDatabaseCount('delivery_results', 2);
        $this->assertDatabaseCount('payment_collections', 0);
        $this->assertDatabaseCount('inventory_transactions', 3);
        $this->assertDatabaseCount('active_order_allocations', 2);
        $this->assertDatabaseCount('courier_trip_locks', 1);
        $this->assertDatabaseCount('vehicle_trip_locks', 1);
        $this->assertDatabaseHas('inventory_accounts', ['owner_key' => 'trip:'.$this->trip->id, 'product_id' => $this->products[0]->id, 'balance_quantity' => 4, 'stock_state' => 'available']);
        $this->getJson('/api/v1/courier/trips/'.$this->trip->id)->assertOk()->assertJsonPath('data.status', 'awaiting_reconciliation');
        $this->assertNull($this->trip->refresh()->actual_return_at);
        $this->recordResult('failed')->assertStatus(409);
    }

    public function test_out_of_sequence_wrong_cod_missing_proof_and_invalid_items_are_rejected(): void
    {
        $this->recordResult('failed', 1)->assertStatus(409)->assertJsonPath('code', 'STOP_OUT_OF_SEQUENCE');
        $this->recordResult('delivered')->assertUnprocessable();
        $upload = $this->photo()->assertCreated()->json('data.id');
        $this->recordResult('delivered', overrides: ['proof_upload_id' => $upload, 'cash_received_rp' => 47000])->assertStatus(409)->assertJsonPath('code', 'COD_MISMATCH');
        $this->recordResult('failed', overrides: ['cash_received_rp' => 1])->assertStatus(409);
        $this->recordResult('failed', overrides: ['failure_reason' => ' '])->assertUnprocessable();
        $this->recordResult('failed', overrides: ['items' => []])->assertUnprocessable();
        $this->assertDatabaseCount('delivery_results', 0);
        $this->assertDatabaseCount('payment_collections', 0);
    }

    public function test_expired_foreign_proof_and_stock_shortage_roll_back_every_side_effect(): void
    {
        $foreign = $this->photo(1)->assertCreated()->json('data.id');
        $this->recordResult('delivered', overrides: ['proof_upload_id' => $foreign])->assertStatus(409)->assertJsonPath('code', 'PROOF_UNAVAILABLE');
        $upload = $this->photo()->assertCreated()->json('data.id');
        DB::table('delivery_proof_uploads')->where('id', $upload)->update(['expires_at' => now()]);
        $this->recordResult('delivered', overrides: ['proof_upload_id' => $upload])->assertStatus(409);
        DB::table('delivery_proof_uploads')->where('id', $upload)->update(['expires_at' => now()->addDay()]);
        InventoryAccount::where('owner_key', 'trip:'.$this->trip->id)->where('product_id', $this->products[1]->id)->where('stock_state', 'available')->update(['balance_quantity' => 0]);
        $this->recordResult('delivered', overrides: ['proof_upload_id' => $upload])->assertStatus(409)->assertJsonPath('code', 'STOCK_CONFLICT');
        $this->assertDatabaseCount('delivery_results', 0);
        $this->assertDatabaseCount('payment_collections', 0);
        $this->assertDatabaseCount('delivery_proofs', 0);
        $this->assertDatabaseHas('delivery_proof_uploads', ['id' => $upload, 'status' => 'pending']);
        $this->assertDatabaseCount('inventory_transactions', 3);
    }

    public function test_courier_ownership_roles_and_invalid_upload_are_enforced(): void
    {
        $bad = UploadedFile::fake()->createWithContent('fake.jpg', 'not an image');
        $this->post('/api/v1/courier/trips/'.$this->trip->id.'/stops/'.$this->stop()->id.'/proofs', ['photo' => $bad], ['Accept' => 'application/json', 'Idempotency-Key' => Str::uuid()->toString()])->assertUnprocessable();
        $this->app['auth']->forgetGuards();
        $this->withToken(User::factory()->create(['role' => 'courier'])->createToken('QA')->plainTextToken);
        $this->recordResult('failed')->assertNotFound();
        $this->photo()->assertNotFound();
        $this->app['auth']->forgetGuards();
        $this->withToken($this->customer->createToken('QA')->plainTextToken);
        $this->recordResult('failed')->assertForbidden();
    }

    public function test_cleanup_removes_expired_staging_but_preserves_attached_proof(): void
    {
        $attached = $this->photo()->assertCreated()->json('data.id');
        $this->recordResult('delivered', overrides: ['proof_upload_id' => $attached])->assertOk();
        $pending = $this->photo(1)->assertCreated()->json('data.id');
        $staged = DB::table('delivery_proof_uploads')->find($pending);
        $proof = DB::table('delivery_proof_uploads')->find($attached);
        DB::table('delivery_proof_uploads')->where('id', $pending)->update(['expires_at' => now()]);
        $this->artisan('shipx:cleanup-delivery-proofs')->assertSuccessful();
        Storage::disk('local')->assertMissing($staged->storage_key);
        Storage::disk('local')->assertExists($proof->storage_key);
        $this->assertDatabaseHas('delivery_proof_uploads', ['id' => $pending, 'status' => 'expired']);
        $this->assertDatabaseHas('delivery_proof_uploads', ['id' => $attached, 'status' => 'attached']);
    }
}
