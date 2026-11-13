<?php

use App\Models\Depot;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schedule;
use Illuminate\Support\Facades\Storage;

Schedule::command('shipx:expire-orders')->everyMinute()->withoutOverlapping();
Schedule::command('shipx:cleanup-delivery-proofs')->daily()->withoutOverlapping();

Artisan::command('shipx:cleanup-delivery-proofs', function () {
    $disk = Storage::disk('local');
    DB::table('delivery_proof_uploads')->where(function ($query) {
        $query->where('status', 'expired')->orWhere(fn ($pending) => $pending->where('status', 'pending')->where('expires_at', '<=', now()));
    })->orderBy('id')->chunkById(100, function ($uploads) use ($disk) {
        foreach ($uploads as $upload) {
            $path = DB::transaction(function () use ($upload) {
                Depot::lockForUpdate()->findOrFail(1);
                $fresh = DB::table('delivery_proof_uploads')->lockForUpdate()->find($upload->id);
                if (! $fresh || $fresh->status === 'attached') {
                    return null;
                }
                if ($fresh->status === 'pending' && $fresh->expires_at > now()->format('Y-m-d H:i:s')) {
                    return null;
                }
                DB::table('delivery_proof_uploads')->where('id', $fresh->id)->update(['status' => 'expired', 'updated_at' => now()]);

                return $fresh->storage_key;
            });
            if ($path) {
                $disk->delete($path);
            }
        }
    });
    foreach ($disk->files('delivery-proofs') as $path) {
        if (preg_match('~^delivery-proofs/[a-f0-9-]{36}\.(jpg|png)$~D', $path) && $disk->lastModified($path) < now()->subDay()->timestamp && ! DB::table('delivery_proof_uploads')->where('storage_key', $path)->exists()) {
            $disk->delete($path);
        }
    }
    $this->info('Unggahan sementara yang kedaluwarsa sudah diperiksa.');
});

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Schedule::command('shipx:sync-holidays')->dailyAt('00:05')->withoutOverlapping();
Schedule::command('shipx:prepare-delivery-schedule')->dailyAt('00:15')->withoutOverlapping();

Artisan::command('shipx:sync-holidays', function () {
    foreach ([now()->year, now()->year + 1] as $year) {
        try {
            $count = app(\App\Services\NationalHolidayCalendar::class)->sync($year);
            $this->info("Kalender $year diperbarui ($count hari).");
        } catch (\Throwable $error) {
            $this->error("Kalender $year memakai salinan tersimpan. ".$error->getMessage());
        }
    }
});
Artisan::command('shipx:prepare-delivery-schedule', function () {
    $count = app(\App\Services\DeliveryScheduleGenerator::class)->generate();
    $this->info("$count slot pengiriman disiapkan.");
});
