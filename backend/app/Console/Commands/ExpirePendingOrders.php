<?php

namespace App\Console\Commands;

use App\Services\OrderLifecycleService;
use Illuminate\Console\Command;

class ExpirePendingOrders extends Command
{
    protected $signature = 'shipx:expire-orders';

    protected $description = 'Batalkan pending yang lewat batas konfirmasi dan lepaskan reservation sekali';

    public function handle(OrderLifecycleService $service): int
    {
        $total = 0;
        do {
            $count = $service->expireDue();
            $total += $count;
        } while ($count === 500);
        $this->info($total.' pesanan kedaluwarsa diproses.');

        return self::SUCCESS;
    }
}
