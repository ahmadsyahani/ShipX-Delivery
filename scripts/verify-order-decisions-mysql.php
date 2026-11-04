<?php

// Real parallel workers against one disposable MySQL database. Never resets shipx.
if (($argv[1] ?? '') === 'worker') {
    $qa = $argv[2] ?? '';
    if (!preg_match('/^shipx_qa_decisions_[a-f0-9]{20}$/D', $qa)) throw new RuntimeException('Invalid QA database.');
    putenv('DB_DATABASE='.$qa); $_ENV['DB_DATABASE'] = $qa; $_SERVER['DB_DATABASE'] = $qa;
}
require __DIR__.'/../backend/vendor/autoload.php';
$app = require __DIR__.'/../backend/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Str;
use App\Models\OrderDecision;
use App\Models\StockReservation;
use App\Services\OrderLifecycleService;

if (($argv[1] ?? '') === 'worker') {
    try {
        [, , $database, $round, $actor, $orderId, $action, $key, $index] = $argv;
        if (!in_array($round, ['1', '2', '3'], true) || !in_array($index, ['0', '1'], true)) throw new RuntimeException('Invalid worker.');
        $barrier = storage_path('app/decisions-qa-'.substr($database, 19).'-'.$round);
        file_put_contents($barrier.'.ready'.$index, 'ready');
        $deadline = microtime(true) + 20;
        while (!is_file($barrier.'.go')) { if (microtime(true) > $deadline) throw new RuntimeException('Barrier timeout.'); usleep(20000); }
        $lifecycle = app(OrderLifecycleService::class);
        $result = app(App\Services\IdempotencyService::class)->run((int)$actor, 'qa.'.$action.':'.$orderId, $key, ['lock_version'=>0], function () use ($lifecycle, $action, $actor, $orderId) {
            if ($action === 'cancel') {
                $order = $lifecycle->cancel((int)$actor, (int)$orderId, 0, 'QA customer cancellation');
                return ['status'=>200, 'body'=>['data'=>['status'=>$order->status]]];
            }
            if (!in_array($action, ['confirmed', 'rejected'], true)) throw new RuntimeException('Invalid action.');
            return $lifecycle->decide((int)$actor, (int)$orderId, 0, $action, $action === 'rejected' ? 'QA rejection' : null);
        });
        echo json_encode(['status'=>$result['status'], 'code'=>$result['body']['code']??null], JSON_THROW_ON_ERROR);
        exit(0);
    } catch (Throwable $error) { echo json_encode(['error'=>$error->getMessage()]); exit(1); }
}

$qa = 'shipx_qa_decisions_'.bin2hex(random_bytes(10));
$original = config('database.connections.mysql.database');
$created = false; $workers = []; $barriers = []; $failed = false;
try {
    if (DB::connection()->getDriverName() !== 'mysql') throw new RuntimeException('MySQL is required.');
    DB::statement('CREATE DATABASE `'.$qa.'` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'); $created = true;
    DB::purge('mysql'); config(['database.connections.mysql.database'=>$qa]); Artisan::call('migrate', ['--force'=>true]);
    App\Models\Depot::findOrFail(1)->fill(['address_text'=>'QA depot', 'latitude'=>-7.25, 'longitude'=>112.75, 'service_radius_m'=>5000, 'delivery_fee_rp'=>3000])->save();
    $admins = App\Models\User::factory()->count(2)->create(['role'=>'admin']);
    $customer = App\Models\User::factory()->create();
    $address = new App\Models\Address(['label'=>'QA', 'recipient_name'=>'QA', 'phone'=>'080000', 'address_text'=>'QA address', 'latitude'=>-7.25, 'longitude'=>112.75]); $address->user_id=$customer->id; $address->save();
    $start = Carbon\CarbonImmutable::now('Asia/Jakarta')->addDays(2)->setTime(10, 0);
    $slot = new App\Models\DeliverySlot(['service_date'=>$start->toDateString(), 'window_start_at'=>$start->utc(), 'window_end_at'=>$start->addHour()->utc(), 'cutoff_at'=>$start->subHour()->utc(), 'is_active'=>true]); $slot->depot_id=1; $slot->save();
    $product = new App\Models\Product(['sku'=>'QA-DECISION', 'name'=>'QA Decision', 'category'=>'QA', 'unit_label'=>'pak', 'unit_price_rp'=>15000, 'shipping_weight_g'=>1000, 'length_mm'=>100, 'width_mm'=>100, 'height_mm'=>100, 'is_active'=>true]); $product->depot_id=1; $product->calculateVolume(); $product->save();
    app(App\Services\InventoryService::class)->adjust($admins[0]->id, $product->id, 'available', 5, 'QA opening', Str::uuid()->toString());
    $makeOrder = fn () => app(App\Services\CheckoutService::class)->checkout($customer->id, ['address_id'=>$address->id, 'delivery_slot_id'=>$slot->id, 'items'=>[['product_id'=>$product->id, 'quantity'=>2]], 'expected_total_rp'=>33000]);
    $pair = function (int $round, $order, array $actions, ?Closure $unlock = null) use ($qa, &$workers, &$barriers) {
        $barrier = storage_path('app/decisions-qa-'.substr($qa, 19).'-'.$round); $barriers[]=$barrier;
        $pipes=[];
        foreach ($actions as $index=>[$actor, $action]) {
            $workers[$index] = proc_open([PHP_BINARY, __FILE__, 'worker', $qa, (string)$round, (string)$actor, (string)$order->id, $action, Str::uuid()->toString(), (string)$index], [0=>['pipe','r'],1=>['pipe','w'],2=>['pipe','w']], $pipes[$index], base_path());
            if (!is_resource($workers[$index])) throw new RuntimeException('Could not start worker.');
            fclose($pipes[$index][0]);
        }
        $timeout=microtime(true)+20;
        while (!is_file($barrier.'.ready0') || !is_file($barrier.'.ready1')) { if(microtime(true)>$timeout) throw new RuntimeException('Workers not ready.'); usleep(20000); }
        file_put_contents($barrier.'.go','go');
        if($unlock) $unlock();
        $results=[];
        foreach($actions as $index=>$unused) {
            $raw=stream_get_contents($pipes[$index][1]); stream_get_contents($pipes[$index][2]); fclose($pipes[$index][1]); fclose($pipes[$index][2]);
            $code=proc_close($workers[$index]); unset($workers[$index]); $result=json_decode($raw,true);
            if($code!==0 || !isset($result['status'])) throw new RuntimeException('Worker failed: '.$raw);
            $results[]=$result;
        }
        return $results;
    };
    foreach([1,2] as $round) {
        $order=$makeOrder();
        $actions=$round===1 ? [[$admins[0]->id,'confirmed'],[$admins[1]->id,'rejected']] : [[$admins[0]->id,'confirmed'],[$customer->id,'cancel']];
        $results=$pair($round,$order,$actions); $statuses=array_column($results,'status'); sort($statuses);
        if($statuses!==[200,409]) throw new RuntimeException('Competing decisions did not have exactly one winner.');
        $order->refresh(); $active=(int)StockReservation::whereIn('order_item_id',$order->items()->pluck('id'))->where('status','active')->sum('quantity');
        if($active!==($order->status==='confirmed'?2:0) || OrderDecision::where('order_id',$order->id)->count()!==($order->status==='cancelled'?0:1)) throw new RuntimeException('Decision/reservation invariant failed.');
        if($order->status==='confirmed') app(OrderLifecycleService::class)->cancel($customer->id,$order->id,$order->lock_version,'QA cleanup');
    }
    $order=$makeOrder(); $order->update(['pending_expires_at'=>now()->addSeconds(5)]);
    DB::beginTransaction(); App\Models\Depot::lockForUpdate()->findOrFail(1);
    $results=$pair(3,$order,[[$admins[0]->id,'confirmed'],[$admins[1]->id,'rejected']],function () use ($order) {
        $wait=$order->pending_expires_at->getTimestamp()-microtime(true);
        if($wait<=0) throw new RuntimeException('Workers did not reach the lock before expiry.');
        usleep((int)(($wait+0.2)*1000000)); DB::commit();
    });
    if(array_column($results,'status')!==[409,409] || $order->refresh()->status!=='cancelled' || $order->status_reason!=='PENDING_EXPIRED' || $order->lock_version!==1 || OrderDecision::where('order_id',$order->id)->exists()) throw new RuntimeException('Expired waiter incorrectly decided the order.');
    if(StockReservation::where('status','active')->exists()) throw new RuntimeException('Reservation leaked.');
    foreach(App\Models\InventoryAccount::all() as $account) if($account->balance_quantity!==(int)DB::table('inventory_entries')->where('inventory_account_id',$account->id)->sum('quantity_delta')) throw new RuntimeException('Ledger changed during decision.');
    echo "PASS: MySQL parallel confirm/reject, confirm/cancel, expiry while waiting on lock; single decision and reservation/ledger invariants.\n";
} catch(Throwable $error) { $failed=true; fwrite(STDERR,'FAIL: '.$error->getMessage().PHP_EOL); }
finally {
    foreach($workers as $worker) if(is_resource($worker)) { proc_terminate($worker); proc_close($worker); }
    foreach($barriers as $barrier) foreach(['.ready0','.ready1','.go'] as $suffix) if(is_file($barrier.$suffix)) unlink($barrier.$suffix);
    if(DB::transactionLevel()>0) DB::rollBack();
    DB::purge('mysql'); config(['database.connections.mysql.database'=>$original]);
    if($created && preg_match('/^shipx_qa_decisions_[a-f0-9]{20}$/D',$qa)) { DB::statement('DROP DATABASE `'.$qa.'`'); echo "Disposable decision QA database removed.\n"; }
}
exit($failed?1:0);
