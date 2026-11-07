<?php

// Isolated end-to-end environment for Flutter QA on loopback port 8001.
// Starts no background service; keep this process running during the test.
require __DIR__.'/../backend/vendor/autoload.php';
$app=require __DIR__.'/../backend/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Str;

$stopFile = storage_path('app/checkout-ui-qa.stop');
if (($argv[1] ?? '') === 'stop') {
    file_put_contents($stopFile, 'stop');
    echo "Stop requested for the isolated UI QA server.\n";
    exit(0);
}
if (is_file($stopFile)) unlink($stopFile);

if(DB::connection()->getDriverName()!=='mysql')throw new RuntimeException('MySQL is required.');
$original=config('database.connections.mysql.database');$qa='shipx_qa_ui_'.bin2hex(random_bytes(10));$created=false;$process=null;
$cleanup=function()use(&$process,&$created,$qa,$original,$stopFile){
    if(is_resource($process)){proc_terminate($process);proc_close($process);$process=null;}
    $qaProofRoot=storage_path('framework/testing/ui-proof-qa-'.substr($qa,-20));
    $resolvedProofs=realpath($qaProofRoot.'/delivery-proofs');
    $resolvedRoot=realpath($qaProofRoot);
    if($resolvedProofs && $resolvedRoot && str_starts_with(str_replace('\\','/',$resolvedProofs),str_replace('\\','/',$resolvedRoot).'/')){
        foreach(glob($resolvedProofs.'/*')?:[] as $file){
            if(is_file($file)&&preg_match('/^[a-f0-9-]{36}\.(jpg|png)$/D',basename($file)))unlink($file);
        }
    }
    DB::purge('mysql');config(['database.connections.mysql.database'=>$original]);
    if($created&&preg_match('/^shipx_qa_ui_[a-f0-9]{20}$/D',$qa)){DB::statement('DROP DATABASE IF EXISTS `'.$qa.'`');$created=false;echo "Isolated UI QA database removed.\n";}
    if(is_file($stopFile)) unlink($stopFile);
};
register_shutdown_function($cleanup);
try{
    DB::statement('CREATE DATABASE `'.$qa.'` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');$created=true;
    DB::purge('mysql');config(['database.connections.mysql.database'=>$qa]);Artisan::call('migrate',['--force'=>true]);
    $timezone='Asia/Jakarta';foreach(['Asia/Jakarta','Asia/Makassar','Asia/Jayapura']as $zone){if((int)now($zone)->format('G')<=21){$timezone=$zone;break;}}
    App\Models\Depot::findOrFail(1)->fill(['name'=>'Depot QA terisolasi','address_text'=>'Lokasi pengujian','latitude'=>-7.25,'longitude'=>112.75,'service_radius_m'=>5000,'delivery_fee_rp'=>3000,'timezone'=>$timezone])->save();
    $admin=App\Models\User::factory()->create(['role'=>'admin','name'=>'QA Admin','email'=>'admin-ui@example.test','password'=>Illuminate\Support\Facades\Hash::make('ShipX-QA-Admin-2026!')]);
    App\Models\User::factory()->create(['role'=>'courier','name'=>'QA Kurir','email'=>'courier-ui@example.test','password'=>Illuminate\Support\Facades\Hash::make('ShipX-QA-Courier-2026!')]);
    foreach([['QA Air',15000],['QA Sabun',12000]]as $i=>[$name,$price]){
        $p=new App\Models\Product(['sku'=>'QA-'.$i,'name'=>$name,'category'=>'Uji checkout','unit_label'=>'pak','unit_price_rp'=>$price,'shipping_weight_g'=>1000,'length_mm'=>100,'width_mm'=>100,'height_mm'=>100,'is_active'=>true]);$p->depot_id=1;$p->calculateVolume();$p->save();app(App\Services\InventoryService::class)->adjust($admin->id,$p->id,'available',5,'Stok uji terisolasi',Str::uuid()->toString());
    }
    $local=Carbon\CarbonImmutable::now($timezone)->addHour()->startOfMinute();
    $slot=new App\Models\DeliverySlot(['service_date'=>$local->toDateString(),'window_start_at'=>$local->utc(),'window_end_at'=>$local->addMinutes(30)->utc(),'cutoff_at'=>$local->subMinutes(15)->utc(),'is_active'=>true]);$slot->depot_id=1;$slot->save();
    $env=getenv();$env['DB_DATABASE']=$qa;$env['DB_CONNECTION']='mysql';$env['SHIPX_QA_HTTP']='1';
    $env['LOCAL_PRIVATE_STORAGE_PATH']=storage_path('framework/testing/ui-proof-qa-'.substr($qa,-20));
    if (in_array(($argv[1] ?? ''), ['trips','departures'], true)) {
        App\Models\User::factory()->create(['role'=>'admin','name'=>'QA Trip Admin','email'=>'trips-admin-ui@example.test','password'=>Illuminate\Support\Facades\Hash::make('ShipX-QA-Admin-2026!')]);
        $courier=App\Models\User::where('email','courier-ui@example.test')->firstOrFail();
        $v=new App\Models\Vehicle(['code'=>'QA-TRIP','name'=>'Motor QA trip','plate_number'=>'B2026QA','travel_mode'=>'motorcycle','max_load_weight_g'=>10000,'max_load_volume_cm3'=>10000,'is_active'=>true]);$v->depot_id=1;$v->save();
        $customer=App\Models\User::factory()->create(['name'=>'QA Trip Customer']);
        $address=new App\Models\Address(['label'=>'QA trip','recipient_name'=>'Penerima QA trip','phone'=>'080000','address_text'=>'Alamat QA khusus trip','latitude'=>-7.25,'longitude'=>112.75]);$address->user_id=$customer->id;$address->save();
        $start=Carbon\CarbonImmutable::now($timezone)->addDays(2)->setTime(10,0);
        $wave=new App\Models\DeliverySlot(['service_date'=>$start->toDateString(),'window_start_at'=>$start->utc(),'window_end_at'=>$start->addHour()->utc(),'cutoff_at'=>$start->subHour()->utc(),'is_active'=>true]);$wave->depot_id=1;$wave->save();
        $p=new App\Models\Product(['sku'=>'QA-TRIP','name'=>'QA Barang trip','category'=>'QA','unit_label'=>'pak','unit_price_rp'=>15000,'shipping_weight_g'=>1000,'length_mm'=>100,'width_mm'=>100,'height_mm'=>100,'is_active'=>true]);$p->depot_id=1;$p->calculateVolume();$p->save();
        app(App\Services\InventoryService::class)->adjust($admin->id,$p->id,'available',10,'QA trip opening',Str::uuid()->toString());
        for($i=0;$i<2;$i++){
            $o=app(App\Services\CheckoutService::class)->checkout($customer->id,['address_id'=>$address->id,'delivery_slot_id'=>$wave->id,'items'=>[['product_id'=>$p->id,'quantity'=>2]],'expected_total_rp'=>33000]);
            app(App\Services\OrderLifecycleService::class)->decide($admin->id,$o->id,0,'confirmed');
        }
        echo "Manual trip QA: two confirmed orders, courier and vehicle ready.\n";
    }
    if (($argv[1] ?? '') === 'departures') {
        App\Models\User::factory()->create(['role'=>'admin','name'=>'QA Departure Admin','email'=>'departures-admin-ui@example.test','password'=>Illuminate\Support\Facades\Hash::make('ShipX-QA-Admin-2026!')]);
        $courier=App\Models\User::factory()->create(['role'=>'courier','name'=>'QA Departure Courier','email'=>'departures-courier-ui@example.test','password'=>Illuminate\Support\Facades\Hash::make('ShipX-QA-Courier-2026!')]);
        $customer=App\Models\User::factory()->create(['name'=>'QA Departure Customer','email'=>'departures-customer-ui@example.test','password'=>Illuminate\Support\Facades\Hash::make('ShipX-QA-Customer-2026!')]);
        $v=new App\Models\Vehicle(['code'=>'QA-DEPARTURE','name'=>'Motor QA muatan','plate_number'=>'B2026LOAD','travel_mode'=>'motorcycle','max_load_weight_g'=>10000,'max_load_volume_cm3'=>10000,'is_active'=>true]);$v->depot_id=1;$v->save();
        $address=new App\Models\Address(['label'=>'QA muatan','recipient_name'=>'Penerima QA muatan','phone'=>'080000','address_text'=>'Alamat QA khusus keberangkatan','latitude'=>-7.25,'longitude'=>112.75]);$address->user_id=$customer->id;$address->save();
        $start=Carbon\CarbonImmutable::now($timezone)->addHour()->startOfMinute();
        $wave=new App\Models\DeliverySlot(['service_date'=>$start->toDateString(),'window_start_at'=>$start->utc(),'window_end_at'=>$start->addHour()->utc(),'cutoff_at'=>$start->subMinutes(15)->utc(),'is_active'=>true]);$wave->depot_id=1;$wave->save();
        $products=[];
        foreach([1000,500]as $i=>$weight){
            $p=new App\Models\Product(['sku'=>'QA-LOAD-'.$i,'name'=>'QA Muatan '.($i===0?'A':'B'),'category'=>'QA','unit_label'=>'pak','unit_price_rp'=>15000,'shipping_weight_g'=>$weight,'length_mm'=>100,'width_mm'=>100,'height_mm'=>100,'is_active'=>true]);$p->depot_id=1;$p->calculateVolume();$p->save();
            app(App\Services\InventoryService::class)->adjust($admin->id,$p->id,'available',20,'QA departure opening',Str::uuid()->toString());$products[]=$p;
        }
        $orders=[];
        for($i=0;$i<2;$i++){
            $o=app(App\Services\CheckoutService::class)->checkout($customer->id,['address_id'=>$address->id,'delivery_slot_id'=>$wave->id,'items'=>[['product_id'=>$products[0]->id,'quantity'=>2],['product_id'=>$products[1]->id,'quantity'=>1]],'expected_total_rp'=>48000]);
            app(App\Services\OrderLifecycleService::class)->decide($admin->id,$o->id,0,'confirmed');$orders[]=$o->refresh();
        }
        $clock=Carbon\CarbonImmutable::now($timezone);Illuminate\Support\Facades\Date::setTestNow($clock->subMinutes(3));
        try {
            $r=app(App\Services\ManualTripService::class)->save($admin->id,['courier_id'=>$courier->id,'vehicle_id'=>$v->id,'departure_local'=>$clock->subMinute()->format('Y-m-d\TH:i'),'orders'=>array_map(fn($o)=>['id'=>$o->id,'lock_version'=>1],$orders)]);
            app(App\Services\ManualTripService::class)->act($admin->id,(int)$r['body']['data']['id'],0,'assign');
        }finally{Illuminate\Support\Facades\Date::setTestNow();}
        echo "Departure QA: assigned trip with two SKUs ready for admin road review and courier start.\n";
    }
    echo "Isolated checkout fixtures ready on http://127.0.0.1:8001 (two products, five units each).\n";
    // Direct built-in server process so cleanup stops exactly the process owned here.
    $router=__DIR__.'/checkout-qa-router.php';
    $process=proc_open([PHP_BINARY,'-S','127.0.0.1:8001',$router],[0=>STDIN,1=>STDOUT,2=>STDERR],$pipes,public_path(),$env);
    if(!is_resource($process))throw new RuntimeException('Could not start isolated QA server.');
    while(proc_get_status($process)['running'] && !is_file($stopFile)){usleep(200000);}
}finally{$cleanup();}
