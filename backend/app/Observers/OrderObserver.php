<?php

namespace App\Observers;

use App\Models\Order;
use App\Models\User;
use App\Notifications\OperationalNotification;

class OrderObserver
{
    public function created(Order $order): void
    {
        $this->send($order);
    }

    public function updated(Order $order): void
    {
        if ($order->wasChanged('status')) {
            $this->send($order);
        }
    }

    private function send(Order $order): void
    {
        $message = match ($order->status) {
            'pending' => 'Pesanan diterima dan menunggu konfirmasi admin.',
            'confirmed' => 'Pesanan dikonfirmasi dan sedang disiapkan.',
            'assigned' => 'Pesanan sudah ditugaskan ke kurir.',
            'out_for_delivery' => 'Kurir berangkat membawa pesananmu. Pelacakan tersedia saat navigasi aktif.',
            'delivered' => 'Pesanan berhasil diantar.',
            'failed' => 'Pengantaran gagal. Periksa detail pesanan untuk alasannya.',
            'rejected' => 'Pesanan ditolak. Periksa alasan pada detail pesanan.',
            'cancelled' => 'Pesanan dibatalkan. Periksa detail pesanan.',
            default => null,
        };
        if ($message === null) {
            return;
        }
        $customer = User::where('role', 'customer')->where('is_active', true)->find($order->customer_id);
        $customer?->notify(new OperationalNotification(['title' => $order->order_number, 'message' => $message,
            'kind' => 'order', 'target_id' => (string) $order->id, 'status' => $order->status]));
    }

    public function assigned(Order $order): void
    {
        $this->send($order);
    }
}
