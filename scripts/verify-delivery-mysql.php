<?php

// Run: php scripts/verify-delivery-mysql.php
// Exercises the API kernel on the existing MySQL connection in one transaction.
// All fixture and depot changes roll back, including on assertion failure.
require __DIR__.'/../backend/vendor/autoload.php';
$app = require __DIR__.'/../backend/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$db = Illuminate\Support\Facades\DB::connection();
if ($db->getDriverName() !== 'mysql') {
    throw new RuntimeException('This check requires the existing development MySQL connection.');
}
$db->beginTransaction();
try {
    $depot = App\Models\Depot::lockForUpdate()->findOrFail(1);
    $depot->fill(['address_text'=>'Temporary QA location','latitude'=>-7.25,'longitude'=>112.75,'service_radius_m'=>5000,'delivery_fee_rp'=>3000])->save();
    $user = App\Models\User::create(['name'=>'ShipX Transaction QA','email'=>'shipx-delivery-'.Illuminate\Support\Str::uuid().'@example.test','phone'=>'080000000000','password'=>Illuminate\Support\Str::random(40)]);
    $token = $user->createToken('transaction-check')->plainTextToken;
    $call = function(string $method,string $path,array $data=[],int $expected=200)use($app,$kernel,$token):array{
        $app['auth']->forgetGuards();
        $request=Illuminate\Http\Request::create('http://localhost/api/v1'.$path,$method,$data,[],[],['HTTP_ACCEPT'=>'application/json','HTTP_AUTHORIZATION'=>'Bearer '.$token]);
        $response=$kernel->handle($request);
        if($response->getStatusCode()!==$expected){throw new RuntimeException('Unexpected '.$response->getStatusCode().' for '.$method.' '.$path);}
        return json_decode($response->getContent(),true)??[];
    };
    $settings=$call('GET','/delivery-settings');
    if(!$settings['data']['configured']){throw new RuntimeException('Depot fixture should be configured.');}
    $created=$call('POST','/addresses',['label'=>'QA','recipient_name'=>'QA','phone'=>'080000000000','address_text'=>'Temporary address','latitude'=>-7.251,'longitude'=>112.751],201);
    $id=$created['data']['id'];
    $updated=$call('PATCH','/addresses/'.$id,['lock_version'=>0,'label'=>'Updated QA']);
    if($updated['data']['lock_version']!==1){throw new RuntimeException('Version must increase.');}
    $call('PATCH','/addresses/'.$id,['lock_version'=>0,'label'=>'Stale'],409);
    $call('PATCH','/addresses/'.$id,['lock_version'=>1,'latitude'=>0],422);
    $local=Carbon\CarbonImmutable::now($depot->timezone)->addDays(2)->setTime(10,0);
    $slot=new App\Models\DeliverySlot(['service_date'=>$local->format('Y-m-d'),'window_start_at'=>$local->utc(),'window_end_at'=>$local->addHours(2)->utc(),'cutoff_at'=>$local->subHour()->utc(),'is_active'=>true]);
    $slot->depot_id=1;$slot->save();
    $slots=$call('GET','/delivery-slots?date='.$local->format('Y-m-d').'&per_page=100');
    if(!collect($slots['data'])->contains(fn($row)=>$row['id']===(string)$slot->id)){throw new RuntimeException('Slot must appear on its local date.');}
    $call('DELETE','/addresses/'.$id,['lock_version'=>1],204);
    $call('DELETE','/addresses/'.$id,['lock_version'=>1],204);
    echo "PASS: MySQL API kernel: settings, address create/update, stale version, radius, slot local date, soft delete.\n";
} finally {
    $db->rollBack();
    echo "Rolled back all QA data and depot fixture changes.\n";
}
