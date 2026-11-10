<?php

// Real independent MySQL workers. Only generated, disposable QA databases.
if (($argv[1] ?? '') === 'worker') {
    $qa = $argv[2] ?? '';
    if (! preg_match('/^shipx_qa_trips_[a-f0-9]{20}$/D', $qa)) {
        throw new RuntimeException('Invalid QA database.');
    }
    putenv('DB_DATABASE='.$qa);
    $_ENV['DB_DATABASE'] = $qa;
    $_SERVER['DB_DATABASE'] = $qa;
}
require __DIR__.'/../backend/vendor/autoload.php';
$app = require __DIR__.'/../backend/bootstrap/app.php';
$app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Models\Address;
use App\Models\DeliverySlot;
use App\Models\Depot;
use App\Models\InventoryAccount;
use App\Models\Product;
use App\Models\StockReservation;
use App\Models\Trip;
use App\Models\User;
use App\Models\Vehicle;
use App\Services\CheckoutService;
use App\Services\DeliveryResultService;
use App\Services\IdempotencyService;
use App\Services\InventoryService;
use App\Services\ManualTripService;
use App\Services\OrderLifecycleService;
use App\Services\TripDepartureReviewService;
use App\Services\TripDepartureService;
use App\Services\TripManifestService;
use App\Services\TripReconciliationService;
use Carbon\CarbonImmutable;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Date;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

if (($argv[1] ?? '') === 'worker') {
    try {
        [, , $database, $round, $actor, $id, $action, $version, $key, $index] = $argv;
        if (! ctype_digit($round) || ! in_array($index, ['0', '1'], true)) {
            throw new RuntimeException('Invalid worker.');
        }
        $barrier = storage_path('app/trips-qa-'.substr($database, 15).'-'.$round);
        file_put_contents($barrier.'.ready'.$index, 'ready');
        $deadline = microtime(true) + 20;
        while (! is_file($barrier.'.go')) {
            if (microtime(true) > $deadline) {
                throw new RuntimeException('Barrier timeout.');
            } usleep(20000);
        }
        $result = app(IdempotencyService::class)->run((int) $actor, 'qa.'.$action.':'.$id, $key, ['lock_version' => (int) $version], function () use ($actor, $id, $action, $version) {
            if ($action === 'reconcile') {
                $trip = Trip::findOrFail($id);
                $summary = app(TripReconciliationService::class)->summary($trip);
                $items = [];
                foreach ($summary['items'] as $row) {
                    $product = (int) $row['product_id'];
                    $items[$product] ??= ['product_id' => $product, 'available_quantity' => 0, 'quarantine_quantity' => 0, 'discrepancy_reason' => null];
                    $items[$product][$row['stock_state'].'_quantity'] = $row['expected_quantity'];
                }

                return app(TripReconciliationService::class)->close((int) $actor, (int) $id, ['lock_version' => (int) $version, 'actual_cash_rp' => $summary['expected_cash_rp'], 'discrepancy_reason' => null, 'received_and_approved' => true, 'items' => array_values($items)]);
            }
            if (in_array($action, ['delivered', 'failed'], true)) {
                config(['filesystems.disks.local.root' => storage_path('framework/testing/delivery-qa-'.substr(config('database.connections.mysql.database'), 15))]);
                $stop = DB::table('trip_stops')->where('trip_id', $id)->orderBy('sequence_no')->first();
                $proof = DB::table('delivery_proof_uploads')->where('trip_stop_id', $stop->id)->first();

                return app(DeliveryResultService::class)->record((int) $actor, (int) $id, (int) $stop->id, ['trip_version' => (int) $version, 'order_version' => 3, 'outcome' => $action, 'cash_received_rp' => $action === 'delivered' ? 48000 : 0, 'failure_reason' => $action === 'failed' ? 'QA failed' : null, 'notes' => null, 'proof_upload_id' => $action === 'delivered' ? $proof->id : null]);
            }
            if ($action === 'start') {
                $trip = Trip::findOrFail($id);
                $review = app(TripDepartureReviewService::class)->current($trip);

                return app(TripDepartureService::class)->start((int) $actor, (int) $id, ['lock_version' => (int) $version, 'route_version_id' => (int) $trip->selected_route_version_id, 'departure_review_id' => (int) ($review?->id ?? 1), 'manifest' => array_map(fn ($row) => ['product_id' => (int) $row['product_id'], 'quantity' => $row['quantity']], app(TripManifestService::class)->forTrip($trip))]);
            }
            if ($action === 'cancelorder') {
                app(OrderLifecycleService::class)->cancel((int) $actor, (int) $id, (int) $version, 'QA customer cancel');

                return ['status' => 200, 'body' => []];
            }

            return app(ManualTripService::class)->act((int) $actor, (int) $id, (int) $version, $action, 'QA trip change');
        });
        echo json_encode(['status' => $result['status'], 'code' => $result['body']['code'] ?? null], JSON_THROW_ON_ERROR);
        exit(0);
    } catch (Throwable $e) {
        echo json_encode(['error' => $e->getMessage()]);
        exit(1);
    }
}

$qa = 'shipx_qa_trips_'.bin2hex(random_bytes(10));
$original = config('database.connections.mysql.database');
$created = false;
$workers = [];
$barriers = [];
$failed = false;
$proofFiles = [];
try {
    if (DB::connection()->getDriverName() !== 'mysql') {
        throw new RuntimeException('MySQL is required.');
    }
    DB::statement('CREATE DATABASE `'.$qa.'` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
    $created = true;
    DB::purge('mysql');
    config(['database.connections.mysql.database' => $qa]);
    Artisan::call('migrate', ['--force' => true]);
    Artisan::call('migrate:rollback', ['--step' => 1, '--force' => true]);
    Artisan::call('migrate', ['--force' => true]);
    Depot::findOrFail(1)->fill(['address_text' => 'QA depot', 'latitude' => -7.25, 'longitude' => 112.75, 'service_radius_m' => 5000, 'delivery_fee_rp' => 3000])->save();
    $admin = User::factory()->create(['role' => 'admin']);
    $customer = User::factory()->create();
    $couriers = User::factory()->count(2)->create(['role' => 'courier']);
    $vehicles = [];
    for ($i = 0; $i < 2; $i++) {
        $v = new Vehicle(['code' => 'QA-'.$i, 'name' => 'QA Motor', 'plate_number' => 'B202'.$i.'QA', 'travel_mode' => 'motorcycle', 'max_load_weight_g' => 10000, 'max_load_volume_cm3' => 10000, 'is_active' => true]);
        $v->depot_id = 1;
        $v->save();
        $vehicles[] = $v;
    }
    $address = new Address(['label' => 'QA', 'recipient_name' => 'QA', 'phone' => '080000', 'address_text' => 'QA address', 'latitude' => -7.25, 'longitude' => 112.75]);
    $address->user_id = $customer->id;
    $address->save();
    $start = CarbonImmutable::now('Asia/Jakarta')->addDays(2)->setTime(10, 0);
    $slot = new DeliverySlot(['service_date' => $start->toDateString(), 'window_start_at' => $start->utc(), 'window_end_at' => $start->addHour()->utc(), 'cutoff_at' => $start->subHour()->utc(), 'is_active' => true]);
    $slot->depot_id = 1;
    $slot->save();
    $p = new Product(['sku' => 'QA-TRIP', 'name' => 'QA Trip', 'category' => 'QA', 'unit_label' => 'pak', 'unit_price_rp' => 15000, 'shipping_weight_g' => 1000, 'length_mm' => 100, 'width_mm' => 100, 'height_mm' => 100, 'is_active' => true]);
    $p->depot_id = 1;
    $p->calculateVolume();
    $p->save();
    app(InventoryService::class)->adjust($admin->id, $p->id, 'available', 10, 'QA opening', Str::uuid()->toString());
    $orders = [];
    for ($i = 0; $i < 2; $i++) {
        $o = app(CheckoutService::class)->checkout($customer->id, ['address_id' => $address->id, 'delivery_slot_id' => $slot->id, 'items' => [['product_id' => $p->id, 'quantity' => 2]], 'expected_total_rp' => 33000]);
        app(OrderLifecycleService::class)->decide($admin->id, $o->id, 0, 'confirmed');
        $orders[] = $o->refresh();
    }
    $draft = function (int $order, int $courier, int $vehicle) use ($admin, $start, $orders, $couriers, $vehicles) {
        $o = $orders[$order]->refresh();
        $r = app(ManualTripService::class)->save($admin->id, ['courier_id' => $couriers[$courier]->id, 'vehicle_id' => $vehicles[$vehicle]->id, 'departure_local' => $start->subHour()->format('Y-m-d\TH:i'), 'orders' => [['id' => $o->id, 'lock_version' => $o->lock_version]]]);

        return Trip::findOrFail($r['body']['data']['id']);
    };
    $pair = function (int $round, array $actions, array $expected = [200, 409], bool $allowNotFound = false) use ($qa, &$workers, &$barriers) {
        $barrier = storage_path('app/trips-qa-'.substr($qa, 15).'-'.$round);
        $barriers[] = $barrier;
        $pipes = [];
        foreach ($actions as $i => [$actor, $id, $action, $version, $key]) {
            $workers[$i] = proc_open([PHP_BINARY, __FILE__, 'worker', $qa, (string) $round, (string) $actor, (string) $id, $action, (string) $version, $key, (string) $i], [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes[$i], base_path());
            if (! is_resource($workers[$i])) {
                throw new RuntimeException('Could not launch worker.');
            } fclose($pipes[$i][0]);
        }
        $deadline = microtime(true) + 20;
        while (! is_file($barrier.'.ready0') || ! is_file($barrier.'.ready1')) {
            if (microtime(true) > $deadline) {
                throw new RuntimeException('Workers not ready.');
            } usleep(20000);
        }
        file_put_contents($barrier.'.go', 'go');
        $results = [];
        foreach ($actions as $i => $unused) {
            $raw = stream_get_contents($pipes[$i][1]);
            $stderr = stream_get_contents($pipes[$i][2]);
            fclose($pipes[$i][1]);
            fclose($pipes[$i][2]);
            $exit = proc_close($workers[$i]);
            unset($workers[$i]);
            $r = json_decode($raw, true);
            if ($exit !== 0 || ! isset($r['status'])) {
                throw new RuntimeException('Worker failed: '.$raw.$stderr);
            }
            $results[] = $r['status'];
        }
        sort($results);
        if ($results !== $expected && ! ($allowNotFound && $results === [200, 404])) {
            throw new RuntimeException('Unexpected race '.$round.': '.json_encode($results));
        }
    };
    $action = fn ($t, $verb = 'assign', $key = null) => [$admin->id, $t->id, $verb, $t->lock_version, $key ?? Str::uuid()->toString()];
    foreach ([[0, 1, 1], [1, 0, 1], [1, 1, 0]] as $round => [$order, $courier, $vehicle]) {
        $a = $draft(0, 0, 0);
        $b = $draft($order, $courier, $vehicle);
        $pair($round + 1, [$action($a), $action($b)]);
        if (DB::table('active_order_allocations')->count() !== 1 || DB::table('courier_trip_locks')->count() !== 1 || DB::table('vehicle_trip_locks')->count() !== 1) {
            throw new RuntimeException('Claim invariant failed.');
        }
        foreach ([$a, $b] as $t) {
            $t->refresh();
            app(ManualTripService::class)->act($admin->id, $t->id, $t->lock_version, 'cancel', 'QA cleanup');
        }
    }
    $t = $draft(0, 0, 0);
    $key = Str::uuid()->toString();
    $pair(4, [$action($t, 'assign', $key), $action($t, 'assign', $key)], [200, 200]);
    if (DB::table('active_order_allocations')->count() !== 1 || DB::table('trip_events')->where('trip_id', $t->id)->where('action', 'assign')->count() !== 1) {
        throw new RuntimeException('Idempotency duplicated assignment.');
    }
    $t->refresh();
    $pair(5, [$action($t, 'reopen'), $action($t, 'cancel')]);
    $t->refresh();
    if ($t->status === 'draft') {
        app(ManualTripService::class)->act($admin->id, $t->id, $t->lock_version, 'cancel', 'QA cleanup');
    }
    $t = $draft(0, 0, 0);
    $o = $orders[0]->refresh();
    $pair(6, [$action($t), [$customer->id, $o->id, 'cancelorder', $o->lock_version, Str::uuid()->toString()]]);
    $o->refresh();
    if (! in_array($o->status, ['assigned', 'cancelled'], true)) {
        throw new RuntimeException('Cancel/assign status invariant failed.');
    }
    $t->refresh();
    app(ManualTripService::class)->act($admin->id, $t->id, $t->lock_version, 'cancel', 'QA cleanup');
    if (DB::table('active_order_allocations')->exists() || DB::table('courier_trip_locks')->exists() || DB::table('vehicle_trip_locks')->exists()) {
        throw new RuntimeException('Claim leak.');
    }
    if (DB::table('inventory_entries')->count() !== 1 || InventoryAccount::where('stock_state', 'available')->value('balance_quantity') !== 10) {
        throw new RuntimeException('Assignment changed inventory.');
    }
    foreach ($orders as $order) {
        $order->refresh();
        $active = (int) StockReservation::whereIn('order_item_id', $order->items()->pluck('id'))->where('status', 'active')->sum('quantity');
        if ($active !== ($order->status === 'cancelled' ? 0 : 2)) {
            throw new RuntimeException('Reservation invariant failed.');
        }
    }
    // Cross-trip selected routes must be rejected by the composite foreign key.
    $a = Trip::firstOrFail();
    $b = Trip::where('id', '!=', $a->id)->firstOrFail();
    $rejected = false;
    try {
        DB::transaction(fn () => DB::table('trips')->where('id', $a->id)->update(['selected_route_version_id' => $b->selected_route_version_id]));
    } catch (QueryException $e) {
        if (($e->errorInfo[0] ?? '') !== '23000') {
            throw $e;
        } $rejected = true;
    }
    if (! $rejected) {
        throw new RuntimeException('Cross-trip route FK failed.');
    }
    if ($verifyDepartures ?? false) {
        $start = CarbonImmutable::now('Asia/Jakarta')->addHour()->startOfMinute();
        $wave = new DeliverySlot(['service_date' => $start->toDateString(), 'window_start_at' => $start->utc(), 'window_end_at' => $start->addHour()->utc(), 'cutoff_at' => $start->subMinutes(15)->utc(), 'is_active' => true]);
        $wave->depot_id = 1;
        $wave->save();
        $loadProducts = [];
        foreach ([1000, 500] as $i => $weight) {
            $p = new Product(['sku' => 'QA-LOAD-'.$i, 'name' => 'QA Load '.$i, 'category' => 'QA', 'unit_label' => 'pak', 'unit_price_rp' => 15000, 'shipping_weight_g' => $weight, 'length_mm' => 100, 'width_mm' => 100, 'height_mm' => 100, 'is_active' => true]);
            $p->depot_id = 1;
            $p->calculateVolume();
            $p->save();
            app(InventoryService::class)->adjust($admin->id, $p->id, 'available', 100, 'QA departure opening', Str::uuid()->toString());
            $loadProducts[] = $p;
        }
        $makeDeparture = function (int $round) use ($admin, $customer, $address, $wave, $loadProducts) {
            $courier = User::factory()->create(['role' => 'courier']);
            $v = new Vehicle(['code' => 'QA-LOAD-'.$round, 'name' => 'QA Load Motor', 'plate_number' => 'B'.$round.'LOAD', 'travel_mode' => 'motorcycle', 'max_load_weight_g' => 100000, 'max_load_volume_cm3' => 100000, 'is_active' => true]);
            $v->depot_id = 1;
            $v->save();
            $orders = [];
            for ($i = 0; $i < 2; $i++) {
                $o = app(CheckoutService::class)->checkout($customer->id, ['address_id' => $address->id, 'delivery_slot_id' => $wave->id, 'items' => [['product_id' => $loadProducts[0]->id, 'quantity' => 2], ['product_id' => $loadProducts[1]->id, 'quantity' => 1]], 'expected_total_rp' => 48000]);
                app(OrderLifecycleService::class)->decide($admin->id, $o->id, 0, 'confirmed');
                $orders[] = $o->refresh();
            }
            $clock = CarbonImmutable::now('Asia/Jakarta');
            Date::setTestNow($clock->subMinutes(3));
            try {
                $r = app(ManualTripService::class)->save($admin->id, ['courier_id' => $courier->id, 'vehicle_id' => $v->id, 'departure_local' => $clock->subMinute()->format('Y-m-d\TH:i'), 'orders' => array_map(fn ($o) => ['id' => $o->id, 'lock_version' => 1], $orders)]);
                $t = Trip::findOrFail($r['body']['data']['id']);
                app(ManualTripService::class)->act($admin->id, $t->id, 0, 'assign');
            } finally {
                Date::setTestNow();
            }
            app(TripDepartureReviewService::class)->review($admin->id, $t->id, ['lock_version' => 1, 'leg_minutes' => [5, 5, 5], 'source_reference' => 'QA manual road review', 'reason' => 'QA handling checked', 'handling_checked' => true]);

            return $t->refresh();
        };
        foreach ([7, 8, 9, 10] as $round) {
            $t = $makeDeparture($round);
            $key = Str::uuid()->toString();
            $first = [$t->courier_id, $t->id, 'start', $t->lock_version, $key];
            $second = $round === 8 ? $first : ($round === 7 ? [$t->courier_id, $t->id, 'start', $t->lock_version, Str::uuid()->toString()] : [$admin->id, $t->id, $round === 9 ? 'reopen' : 'cancel', $t->lock_version, Str::uuid()->toString()]);
            $pair($round, [$first, $second], $round === 8 ? [200, 200] : [200, 409], $round >= 9);
            $t->refresh();
            $loaded = $t->status === 'in_progress';
            if (DB::table('trip_load_confirmations')->where('trip_id', $t->id)->count() !== ($loaded ? 1 : 0) || DB::table('inventory_transactions')->where('trip_id', $t->id)->count() !== ($loaded ? 1 : 0) || DB::table('active_order_allocations')->where('trip_id', $t->id)->count() !== ($loaded ? 2 : 0)) {
                throw new RuntimeException('Departure race receipt/claim invariant failed.');
            }
            foreach ($loadProducts as $i => $p) {
                $balance = (int) InventoryAccount::where('owner_key', 'trip:'.$t->id)->where('product_id', $p->id)->where('stock_state', 'available')->value('balance_quantity');
                if ($balance !== ($loaded ? ($i === 0 ? 4 : 2) : 0)) {
                    throw new RuntimeException('Departure race loaded SKU mismatch.');
                }
            }
            if ($loaded && (! $t->actual_departure_at || $t->loaded_weight_g !== 5000 || $t->loaded_volume_cm3 !== 6000)) {
                throw new RuntimeException('Departure metadata invalid.');
            }
        }
        foreach (InventoryAccount::all() as $account) {
            if ($account->balance_quantity !== (int) DB::table('inventory_entries')->where('inventory_account_id', $account->id)->sum('quantity_delta')) {
                throw new RuntimeException('Ledger balance mismatch after departure races.');
            }
        }
        foreach ($loadProducts as $p) {
            if ((int) InventoryAccount::where('product_id', $p->id)->sum('balance_quantity') !== 100) {
                throw new RuntimeException('Internal load transfer did not conserve SKU stock.');
            }
        }
        if ($verifyDeliveryResults ?? false) {
            config(['filesystems.disks.local.root' => storage_path('framework/testing/delivery-qa-'.substr($qa, 15))]);
            for ($round = 11; $round <= 13; $round++) {
                $t = $makeDeparture($round);
                app(TripDepartureService::class)->start($t->courier_id, $t->id, ['lock_version' => $t->lock_version, 'route_version_id' => (int) $t->selected_route_version_id, 'departure_review_id' => app(TripDepartureReviewService::class)->current($t)->id, 'manifest' => array_map(fn ($row) => ['product_id' => (int) $row['product_id'], 'quantity' => $row['quantity']], app(TripManifestService::class)->forTrip($t))]);
                $t->refresh();
                $stop = DB::table('trip_stops')->where('trip_id', $t->id)->orderBy('sequence_no')->first();
                $upload = Str::uuid()->toString();
                $path = 'delivery-proofs/'.$upload.'.png';
                $proofFiles[] = $path;
                Storage::disk('local')->put($path, base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='));
                DB::table('delivery_proof_uploads')->insert(['id' => $upload, 'trip_stop_id' => $stop->id, 'uploaded_by' => $t->courier_id, 'idempotency_key' => Str::uuid()->toString(), 'storage_key' => $path, 'mime_type' => 'image/png', 'file_size_bytes' => 68, 'checksum_sha256' => str_repeat('a', 64), 'status' => 'pending', 'expires_at' => now()->addDay(), 'created_at' => now(), 'updated_at' => now()]);
                $key = Str::uuid()->toString();
                $first = [$t->courier_id, $t->id, 'delivered', $t->lock_version, $key];
                $second = [$t->courier_id, $t->id, $round === 11 ? 'failed' : 'delivered', $t->lock_version, $round === 12 ? $key : Str::uuid()->toString()];
                $pair($round, [$first, $second], $round === 12 ? [200, 200] : [200, 409]);
                $result = DB::table('delivery_results')->where('trip_stop_id', $stop->id)->first();
                $delivered = $result?->outcome === 'delivered';
                if (! $result || DB::table('delivery_results')->where('order_id', $stop->order_id)->count() !== 1 || DB::table('payment_collections')->where('delivery_result_id', $result->id)->count() !== ($delivered ? 1 : 0) || DB::table('inventory_transactions')->where('order_id', $stop->order_id)->count() !== ($delivered ? 1 : 0)) {
                    throw new RuntimeException('Delivery/COD race duplicated effects.');
                }
                foreach ($loadProducts as $i => $p) {
                    $balance = (int) InventoryAccount::where('owner_key', 'trip:'.$t->id)->where('product_id', $p->id)->where('stock_state', 'available')->value('balance_quantity');
                    if ($balance !== ($delivered ? ($i === 0 ? 2 : 1) : ($i === 0 ? 4 : 2))) {
                        throw new RuntimeException('Delivery race SKU balance mismatch.');
                    }
                }
                $last = DB::table('trip_stops')->where('trip_id', $t->id)->orderByDesc('sequence_no')->first();
                app(DeliveryResultService::class)->record($t->courier_id, $t->id, $last->id, ['trip_version' => $t->refresh()->lock_version, 'order_version' => 3, 'outcome' => 'failed', 'cash_received_rp' => 0, 'failure_reason' => 'QA return', 'notes' => null, 'proof_upload_id' => null]);
                if ($t->refresh()->status !== 'awaiting_reconciliation' || DB::table('active_order_allocations')->where('trip_id', $t->id)->count() !== 2) {
                    throw new RuntimeException('Claims released before reconciliation.');
                }
                if ($verifyReconciliations ?? false) {
                    $before = [];
                    foreach ($loadProducts as $p) {
                        $before[$p->id] = (int) InventoryAccount::where('product_id', $p->id)->where('owner_key', 'depot')->where('stock_state', 'available')->value('balance_quantity');
                    }
                    $key = Str::uuid()->toString();
                    $otherAdmin = $round === 13 ? User::factory()->create(['role' => 'admin'])->id : $admin->id;
                    $pair($round + 10, [[$admin->id, $t->id, 'reconcile', $t->lock_version, $key], [$otherAdmin, $t->id, 'reconcile', $t->lock_version, $round === 12 ? $key : Str::uuid()->toString()]], $round === 12 ? [200, 200] : [200, 409]);
                    if ($t->refresh()->status !== 'completed' || ! $t->actual_return_at || DB::table('trip_reconciliations')->where('trip_id', $t->id)->count() !== 1 || DB::table('inventory_transactions')->where('event_key', 'reconciliation:'.$t->id)->count() !== 1) {
                        throw new RuntimeException('Reconciliation race duplicated or lost final effects.');
                    }
                    foreach (['active_order_allocations', 'courier_trip_locks', 'vehicle_trip_locks'] as $table) {
                        if (DB::table($table)->where('trip_id', $t->id)->exists()) {
                            throw new RuntimeException('Completed trip still holds claims.');
                        }
                    }
                    foreach ($loadProducts as $i => $p) {
                        $returned = $delivered ? ($i === 0 ? 2 : 1) : ($i === 0 ? 4 : 2);
                        $depot = (int) InventoryAccount::where('product_id', $p->id)->where('owner_key', 'depot')->where('stock_state', 'available')->value('balance_quantity');
                        if ($depot !== $before[$p->id] + $returned || (int) InventoryAccount::where('owner_key', 'trip:'.$t->id)->where('product_id', $p->id)->sum('balance_quantity') !== 0) {
                            throw new RuntimeException('Reconciliation stock returned more than once or trip stock not zero.');
                        }
                    }
                    $receipt = DB::table('trip_reconciliations')->where('trip_id', $t->id)->first();
                    if ((int) $receipt->expected_cash_rp !== ($delivered ? 48000 : 0) || (int) $receipt->cash_difference_rp !== 0) {
                        throw new RuntimeException('Reconciliation cash snapshot invalid.');
                    }
                }
            }
            foreach (InventoryAccount::all() as $account) {
                if ($account->balance_quantity !== (int) DB::table('inventory_entries')->where('inventory_account_id', $account->id)->sum('quantity_delta')) {
                    throw new RuntimeException('Delivery ledger mismatch.');
                }
            }
            echo "PASS: concurrent delivered/failed, delivered retries with same/different keys; exactly one result, proof, COD and multi-SKU ledger, claims retained for reconciliation.\n";
            if ($verifyReconciliations ?? false) {
                echo "PASS: MySQL concurrent reconciliation with same/different keys and different admins; one receipt/ledger, exact SKU returns/COD, zero trip stock and all claims released.\n";
            }
        }
        echo "PASS: MySQL parallel start/start, same-key replay, start/reopen, start/cancel; multi-SKU balances, single load receipt/event and retained claims verified.\n";
    }
    echo "PASS: MySQL migration rollback/reapply; parallel order/courier/vehicle assignment, same-key replay, reopen/cancel and customer-cancel/assign; claims, reservations, inventory and route FK verified.\n";
} catch (Throwable $e) {
    $failed = true;
    fwrite(STDERR, 'FAIL: '.$e->getMessage().PHP_EOL);
} finally {
    foreach ($proofFiles as $path) {
        Storage::disk('local')->delete($path);
    }
    foreach ($workers as $worker) {
        if (is_resource($worker)) {
            proc_terminate($worker);
            proc_close($worker);
        }
    }
    foreach ($barriers as $barrier) {
        foreach (['.ready0', '.ready1', '.go'] as $suffix) {
            if (is_file($barrier.$suffix)) {
                unlink($barrier.$suffix);
            }
        }
    }
    DB::purge('mysql');
    config(['database.connections.mysql.database' => $original]);
    if ($created && preg_match('/^shipx_qa_trips_[a-f0-9]{20}$/D',$qa)) {
        DB::statement('DROP DATABASE `'.$qa.'`');
        echo "Disposable trip QA database removed.\n";
    }
}
exit($failed ? 1 : 0);
