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
    foreach([['QA Air',15000],['QA Sabun',12000]]as $i=>[$name,$price]){
        $p=new App\Models\Product(['sku'=>'QA-'.$i,'name'=>$name,'category'=>'Uji checkout','unit_label'=>'pak','unit_price_rp'=>$price,'shipping_weight_g'=>1000,'length_mm'=>100,'width_mm'=>100,'height_mm'=>100,'is_active'=>true]);$p->depot_id=1;$p->calculateVolume();$p->save();app(App\Services\InventoryService::class)->adjust($admin->id,$p->id,'available',5,'Stok uji terisolasi',Str::uuid()->toString());
    }
    $local=Carbon\CarbonImmutable::now($timezone)->addHour()->startOfMinute();
    $slot=new App\Models\DeliverySlot(['service_date'=>$local->toDateString(),'window_start_at'=>$local->utc(),'window_end_at'=>$local->addMinutes(30)->utc(),'cutoff_at'=>$local->subMinutes(15)->utc(),'is_active'=>true]);$slot->depot_id=1;$slot->save();
    $env=getenv();$env['DB_DATABASE']=$qa;$env['DB_CONNECTION']='mysql';$env['SHIPX_QA_HTTP']='1';
    echo "Isolated checkout fixtures ready on http://127.0.0.1:8001 (two products, five units each).\n";
    // Direct built-in server process so cleanup stops exactly the process owned here.
    $router=__DIR__.'/checkout-qa-router.php';
    $process=proc_open([PHP_BINARY,'-S','127.0.0.1:8001',$router],[0=>STDIN,1=>STDOUT,2=>STDERR],$pipes,public_path(),$env);
    if(!is_resource($process))throw new RuntimeException('Could not start isolated QA server.');
    while(proc_get_status($process)['running'] && !is_file($stopFile)){usleep(200000);}
}finally{$cleanup();}
