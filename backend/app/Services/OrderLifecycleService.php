<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use App\Models\Depot;
use App\Models\InventoryAccount;
use App\Models\Order;
use App\Models\OrderDecision;
use App\Models\StockReservation;
use Illuminate\Support\Facades\DB;

class OrderLifecycleService
{
    public function expireAllDue(): int
    {
        $total = 0;
        do {
            $count = $this->expireDue();
            $total += $count;
        } while ($count === 500);

        return $total;
    }

    public function expireDue(int $limit = 500): int
    {
        return DB::transaction(function () use ($limit) {
            Depot::lockForUpdate()->findOrFail(1);
            $ids = Order::where('depot_id', 1)->where('status', 'pending')->where('pending_expires_at', '<=', now())->orderBy('id')->limit($limit)->pluck('id');
            if ($ids->isEmpty()) {
                return 0;
            }
            $accounts = DB::table('stock_reservations')->join('order_items', 'order_items.id', '=', 'stock_reservations.order_item_id')->whereIn('order_items.order_id', $ids)->pluck('inventory_account_id');
            InventoryAccount::whereIn('id', $accounts)->orderBy('id')->lockForUpdate()->get();
            $orders = Order::whereIn('id', $ids)->orderBy('id')->lockForUpdate()->get();
            $count = 0;
            foreach ($orders as $order) {
                if ($order->status === 'pending' && $order->pending_expires_at <= now()) {
                    $this->expire($order);
                    $count++;
                }
            }

            return $count;
        });
    }

    public function cancel(int $customer, int $id, int $version, string $reason): Order
    {
        return DB::transaction(function () use ($customer, $id, $version, $reason) {
            Depot::lockForUpdate()->findOrFail(1);
            $order = Order::where('customer_id', $customer)->findOrFail($id);
            $accounts = DB::table('stock_reservations')->join('order_items', 'order_items.id', '=', 'stock_reservations.order_item_id')->where('order_items.order_id', $id)->pluck('inventory_account_id');
            InventoryAccount::whereIn('id', $accounts)->orderBy('id')->lockForUpdate()->get();
            $order = Order::where('customer_id', $customer)->lockForUpdate()->findOrFail($id);
            if ($order->lock_version !== $version) {
                throw new BusinessFailure('STALE_VERSION', 'Pesanan telah berubah. Muat ulang sebelum membatalkan.');
            }
            if (! in_array($order->status, ['pending', 'confirmed'], true)) {
                throw new BusinessFailure('ORDER_NOT_CANCELLABLE', 'Pesanan ini tidak dapat dibatalkan.');
            }
            $this->release($order);
            $order->status = 'cancelled';
            $order->status_reason = $reason;
            $order->cancelled_at = now();
            $order->closed_at = now();
            $order->lock_version++;
            $order->save();

            return $order->load('items');
        });
    }

    private function release(Order $order): void
    {
        StockReservation::whereIn('order_item_id', $order->items()->pluck('id'))->where('status', 'active')->update(['status' => 'released', 'released_at' => now(), 'updated_at' => now()]);
    }

    public function decide(int $admin, int $id, int $version, string $decision, ?string $reason = null): array
    {
        return DB::transaction(function () use ($admin, $id, $version, $decision, $reason) {
            Depot::lockForUpdate()->findOrFail(1);
            $order = Order::where('depot_id', 1)->findOrFail($id);
            $accountIds = DB::table('stock_reservations')->join('order_items', 'order_items.id', '=', 'stock_reservations.order_item_id')->where('order_items.order_id', $id)->pluck('inventory_account_id');
            $accounts = InventoryAccount::whereIn('id', $accountIds)->orderBy('id')->lockForUpdate()->get()->keyBy('id');
            $order = Order::where('depot_id', 1)->lockForUpdate()->findOrFail($id);
            // Check time AFTER waiting for locks. Expiry and its conflict response
            // must commit together, rather than rolling the release back.
            if ($order->status === 'pending' && $order->pending_expires_at <= now()) {
                $this->expire($order);

                return ['status' => 409, 'body' => ['code' => 'ORDER_EXPIRED', 'message' => 'Batas konfirmasi habis. Pesanan dibatalkan dan reservasi stok dilepas.']];
            }
            if ($order->lock_version !== $version) {
                throw new BusinessFailure('STALE_VERSION', 'Pesanan telah berubah. Muat ulang sebelum mengambil keputusan.');
            }
            if ($order->status !== 'pending') {
                throw new BusinessFailure('ORDER_NOT_PENDING', 'Hanya pesanan yang menunggu konfirmasi dapat dikonfirmasi atau ditolak.');
            }
            if ($decision === 'confirmed') {
                $items = $order->items()->get();
                $reservations = StockReservation::whereIn('order_item_id', $items->pluck('id'))->get()->keyBy('order_item_id');
                foreach ($items as $item) {
                    $reservation = $reservations->get($item->id);
                    $account = $reservation ? $accounts->get($reservation->inventory_account_id) : null;
                    if (! $reservation || $reservation->status !== 'active' || $reservation->quantity !== $item->quantity || ! $account || (int) $account->product_id !== (int) $item->product_id || (int) $account->depot_id !== 1 || $account->owner_key !== 'depot' || $account->stock_state !== 'available' || $account->balance_quantity < (int) StockReservation::where('inventory_account_id', $account->id)->where('status', 'active')->sum('quantity')) {
                        throw new BusinessFailure('RESERVATION_CONFLICT', 'Reservasi stok tidak sesuai. Periksa stok sebelum mengonfirmasi pesanan.');
                    }
                }
                if ($items->isEmpty()) {
                    throw new BusinessFailure('RESERVATION_CONFLICT', 'Pesanan tidak memiliki barang untuk dikonfirmasi.');
                }
                $order->confirmed_at = now();
            } elseif ($decision === 'rejected' && filled($reason)) {
                $this->release($order);
                $order->status_reason = $reason;
                $order->closed_at = now();
            } else {
                throw new BusinessFailure('INVALID_DECISION', 'Keputusan pesanan tidak valid.');
            }
            $order->status = $decision;
            $order->lock_version++;
            $order->save();
            OrderDecision::create(['order_id' => $order->id, 'admin_id' => $admin, 'decision' => $decision, 'reason' => $decision === 'rejected' ? $reason : null, 'order_version' => $order->lock_version, 'decided_at' => now()]);

            return ['status' => 200, 'body' => ['data' => ['id' => (string) $order->id, 'status' => $order->status, 'lock_version' => $order->lock_version]]];
        });
    }

    private function expire(Order $order): void
    {
        $this->release($order);
        $order->status = 'cancelled';
        $order->status_reason = 'PENDING_EXPIRED';
        $order->cancelled_at = now();
        $order->closed_at = now();
        $order->lock_version++;
        $order->save();
    }
}
