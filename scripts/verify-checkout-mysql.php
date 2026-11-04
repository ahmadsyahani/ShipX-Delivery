<?php

// A disposable MySQL database is used; the user's shipx database is never reset.
// Run: php scripts/verify-checkout-mysql.php
if (($argv[1] ?? '') === 'worker') {
    $database=$argv[2]??'';
    if(!preg_match('/^shipx_qa_[a-f0-9]{20}$/D',$database))throw new RuntimeException('Invalid QA database name.');
    putenv('DB_DATABASE='.$database);$_ENV['DB_DATABASE']=$database;$_SERVER['DB_DATABASE']=$database;
}
require __DIR__.'/../backend/vendor/autoload.php';
$app=require __DIR__.'/../backend/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

function apiCall($app,int $user,string $method,string $path,array $payload=[],?string $key=null):array{
    $app['auth']->forgetGuards();
    $token=App\Models\User::findOrFail($user)->createToken('isolated-qa')->plainTextToken;
    $server=['HTTP_ACCEPT'=>'application/json','HTTP_AUTHORIZATION'=>'Bearer '.$token];
    if($key!==null)$server['HTTP_IDEMPOTENCY_KEY']=$key;
    $request=Illuminate\Http\Request::create('http://localhost/api/v1'.$path,$method,$payload,[],[],$server);
    $response=$app->make(Illuminate\Contracts\Http\Kernel::class)->handle($request);
    return ['status'=>$response->getStatusCode(),'body'=>json_decode($response->getContent(),true)??[]];
}
if(($argv[1]??'')==='worker'){
    try{
        [$unused,$mode,$database,$user,$address,$slot,$product,$key,$barrier,$index]=$argv;
        $expected=storage_path('app/checkout-qa-'.substr($database,9));
        if($barrier!==$expected)throw new RuntimeException('Invalid barrier location.');
        file_put_contents($barrier.'.ready'.$index,'ready');
        $deadline=microtime(true)+20;
        while(!file_exists($barrier.'.go')){if(microtime(true)>$deadline)throw new RuntimeException('Barrier timeout.');usleep(20000);}
        $payload=['address_id'=>(int)$address,'delivery_slot_id'=>(int)$slot,'items'=>[['product_id'=>(int)$product,'quantity'=>1]],'expected_total_rp'=>18000];
        for($attempt=0;$attempt<5;$attempt++){
            $result=apiCall($app,(int)$user,'POST','/orders',$payload,$key);
            if(($result['body']['code']??'')!=='REQUEST_IN_PROGRESS')break;
            usleep(100000);
        }
        echo json_encode(['status'=>$result['status'],'code'=>$result['body']['code']??null,'id'=>$result['body']['data']['id']??null],JSON_THROW_ON_ERROR);
        exit(0);
    }catch(Throwable $error){echo json_encode(['error'=>$error->getMessage()],JSON_THROW_ON_ERROR);exit(2);}
}

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Str;

if(DB::connection()->getDriverName()!=='mysql')throw new RuntimeException('This check requires MySQL.');
$original=config('database.connections.mysql.database');
$qa='shipx_qa_'.bin2hex(random_bytes(10));
$barrier=storage_path('app/checkout-qa-'.substr($qa,9));
$processes=[];$pipes=[];$created=false;
try{
    DB::statement('CREATE DATABASE `'.$qa.'` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');$created=true;
    DB::purge('mysql');config(['database.connections.mysql.database'=>$qa,'database.default'=>'mysql']);
    Artisan::call('migrate',['--force'=>true]);
    App\Models\Depot::findOrFail(1)->fill(['address_text'=>'Isolated QA depot','latitude'=>-7.25,'longitude'=>112.75,'service_radius_m'=>5000,'delivery_fee_rp'=>3000])->save();
    $admin=App\Models\User::factory()->create(['role'=>'admin']);
    $users=App\Models\User::factory()->count(3)->create();$addresses=[];
    foreach($users as $user){$a=new App\Models\Address(['label'=>'QA','recipient_name'=>'QA','phone'=>'0800000000','address_text'=>'Isolated address','latitude'=>-7.25,'longitude'=>112.75]);$a->user_id=$user->id;$a->save();$addresses[]=$a;}
    $local=Carbon\CarbonImmutable::now('Asia/Jakarta')->addDays(2)->setTime(10,0);
    $slot=new App\Models\DeliverySlot(['service_date'=>$local->format('Y-m-d'),'window_start_at'=>$local->utc(),'window_end_at'=>$local->addHours(2)->utc(),'cutoff_at'=>$local->subHour()->utc(),'is_active'=>true]);$slot->depot_id=1;$slot->save();
    $products=[];foreach(['A','B']as $sku){$p=new App\Models\Product(['sku'=>$sku,'name'=>'QA '.$sku,'category'=>'QA','unit_label'=>'pak','unit_price_rp'=>15000,'shipping_weight_g'=>1000,'length_mm'=>100,'width_mm'=>100,'height_mm'=>100,'is_active'=>true]);$p->depot_id=1;$p->calculateVolume();$p->save();app(App\Services\InventoryService::class)->ensureAccounts($p);$products[]=$p;}
    app(App\Services\InventoryService::class)->adjust($admin->id,$products[0]->id,'available',1,'Isolated opening',Str::uuid()->toString());
    $keys=[Str::uuid()->toString(),Str::uuid()->toString()];
    foreach([0,1]as $i){
        $args=[PHP_BINARY,__FILE__,'worker',$qa,(string)$users[$i]->id,(string)$addresses[$i]->id,(string)$slot->id,(string)$products[0]->id,$keys[$i],$barrier,(string)$i];
        $processes[$i]=proc_open($args,[0=>['pipe','r'],1=>['pipe','w'],2=>['pipe','w']],$pipes[$i],base_path());
        if(!is_resource($processes[$i]))throw new RuntimeException('Could not start concurrency worker.');
        fclose($pipes[$i][0]);
    }
    $deadline=microtime(true)+20;
    while(!file_exists($barrier.'.ready0')||!file_exists($barrier.'.ready1')){if(microtime(true)>$deadline)throw new RuntimeException('Workers did not become ready.');usleep(20000);}
    file_put_contents($barrier.'.go','go');$results=[];
    foreach([0,1]as $i){$raw=stream_get_contents($pipes[$i][1]);$stderr=stream_get_contents($pipes[$i][2]);fclose($pipes[$i][1]);fclose($pipes[$i][2]);$code=proc_close($processes[$i]);unset($processes[$i]);$results[$i]=json_decode($raw,true);if($code!==0||!is_array($results[$i]))throw new RuntimeException('Concurrency worker failed. '.$raw);}
    $statuses=array_column($results,'status');sort($statuses);
    if($statuses!==[201,409]||App\Models\Order::count()!==1||App\Models\StockReservation::where('status','active')->sum('quantity')!=1)throw new RuntimeException('Last-unit race invariant failed: '.json_encode($results));
    $winner=$results[0]['status']===201?0:1;$orderId=$results[$winner]['id'];
    $payload=['address_id'=>$addresses[$winner]->id,'delivery_slot_id'=>$slot->id,'items'=>[['product_id'=>$products[0]->id,'quantity'=>1]],'expected_total_rp'=>18000];
    $replay=apiCall($app,$users[$winner]->id,'POST','/orders',$payload,$keys[$winner]);
    if($replay['status']!==201||$replay['body']['data']['id']!==$orderId||App\Models\Order::count()!==1)throw new RuntimeException('Replay duplicated order.');
    $cancel=apiCall($app,$users[$winner]->id,'POST','/orders/'.$orderId.'/cancel',['lock_version'=>0,'reason'=>'QA cancel'],Str::uuid()->toString());
    if($cancel['status']!==200||App\Models\StockReservation::where('status','active')->count()!==0)throw new RuntimeException('Cancel did not release once.');
    $multi=['address_id'=>$addresses[2]->id,'delivery_slot_id'=>$slot->id,'items'=>[['product_id'=>$products[0]->id,'quantity'=>1],['product_id'=>$products[1]->id,'quantity'=>1]],'expected_total_rp'=>33000];
    $failed=apiCall($app,$users[2]->id,'POST','/orders',$multi,Str::uuid()->toString());
    if(($failed['body']['code']??'')!=='OUT_OF_STOCK'||App\Models\Order::count()!==1||App\Models\StockReservation::where('status','active')->count()!==0)throw new RuntimeException('Multi-SKU rollback failed.');
    $payload['address_id']=$addresses[2]->id;$new=apiCall($app,$users[2]->id,'POST','/orders',$payload,Str::uuid()->toString());
    if($new['status']!==201)throw new RuntimeException('Released stock could not be purchased again.');
    App\Models\Order::findOrFail($new['body']['data']['id'])->update(['pending_expires_at'=>now()->subSecond()]);
    Artisan::call('shipx:expire-orders');Artisan::call('shipx:expire-orders');
    if(App\Models\StockReservation::where('status','active')->count()!==0)throw new RuntimeException('Expiry did not release stock.');
    foreach(App\Models\InventoryAccount::all()as $account){if($account->balance_quantity!==(int)DB::table('inventory_entries')->where('inventory_account_id',$account->id)->sum('quantity_delta'))throw new RuntimeException('Ledger balance mismatch.');}
    echo "PASS: isolated MySQL race: two buyers/one unit -> one order; replay, multi-SKU rollback, cancel, expiry, ledger passed.\n";
}catch(Throwable $error){
    fwrite(STDERR, 'FAIL: '.$error->getMessage().PHP_EOL);
    $verificationFailed = true;
}finally{
    foreach($processes as $process){if(is_resource($process))proc_terminate($process);}
    foreach(['.ready0','.ready1','.go']as $suffix){$path=$barrier.$suffix;if(is_file($path))unlink($path);}
    DB::purge('mysql');config(['database.connections.mysql.database'=>$original]);
    if($created&&preg_match('/^shipx_qa_[a-f0-9]{20}$/D',$qa)){DB::statement('DROP DATABASE `'.$qa.'`');echo "Disposable QA database removed; original database preserved.\n";}
}
exit(isset($verificationFailed) ? 1 : 0);
