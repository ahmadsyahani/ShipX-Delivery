<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use App\Models\Depot;
use App\Models\InventoryAccount;
use App\Models\Order;
use App\Models\Product;
use App\Models\Trip;
use App\Models\User;
use App\Models\Vehicle;
use Illuminate\Support\Facades\DB;

class TripReconciliationService
{
    public function summary(Trip $trip): array
    {
        $record = DB::table('trip_reconciliations')->where('trip_id', $trip->id)->first();
        if ($record) {
            $record->items = DB::table('reconciliation_items')->join('products', 'products.id', '=', 'reconciliation_items.product_id')->where('trip_reconciliation_id', $record->id)->orderBy('product_id')->orderBy('stock_state')->get(['reconciliation_items.*', 'products.name', 'products.sku']);
            foreach (['id', 'trip_id', 'approved_by', 'inventory_transaction_id'] as $field) {
                $record->$field = (string) $record->$field;
            }
            $record->items = $record->items->map(function ($item) {
                foreach (['id', 'trip_reconciliation_id', 'product_id'] as $field) {
                    $item->$field = (string) $item->$field;
                }

                return $item;
            });
            $record->approved_by_name = User::find($record->approved_by)?->name;
            $record->approved_at = \Carbon\CarbonImmutable::parse($record->approved_at, 'UTC')->toISOString();
        }
        $accounts = InventoryAccount::where('owner_key', 'trip:'.$trip->id)->where('depot_id', 1)->with('product')->orderBy('product_id')->get();

        return [
            'expected_cash_rp' => $record ? (int) $record->expected_cash_rp : $this->cash($trip),
            'items' => $accounts->map(fn ($account) => ['product_id' => (string) $account->product_id, 'name' => $account->product->name, 'sku' => $account->product->sku, 'stock_state' => $account->stock_state, 'expected_quantity' => (int) $account->balance_quantity])->values()->all(),
            'record' => $record,
        ];
    }

    private function cash(Trip $trip): int
    {
        return (int) DB::table('payment_collections')->join('delivery_results', 'delivery_results.id', '=', 'payment_collections.delivery_result_id')->join('trip_stops', 'trip_stops.id', '=', 'delivery_results.trip_stop_id')->where('trip_stops.trip_id', $trip->id)->where('route_version_id', $trip->selected_route_version_id)->sum('payment_collections.amount_rp');
    }

    public function close(int $admin, int $tripId, array $data): array
    {
        return DB::transaction(function () use ($admin, $tripId, $data) {
            // Same depot mutex and lock order as departure/results/stock mutations.
            Depot::lockForUpdate()->findOrFail(1);
            $actor = User::lockForUpdate()->findOrFail($admin);
            abort_unless($actor->is_active && $actor->role === 'admin', 403);
            $trip = Trip::where('depot_id', 1)->findOrFail($tripId);
            User::lockForUpdate()->findOrFail($trip->courier_id);
            Vehicle::lockForUpdate()->findOrFail($trip->vehicle_id);
            $products = Product::where('depot_id', 1)->whereIn('id', array_column($data['items'], 'product_id'))->orderBy('id')->lockForUpdate()->get();
            if ($products->count() !== count($data['items'])) {
                throw new BusinessFailure('INVALID_RETURN_ITEMS', 'Barang harus unik dan berasal dari depot trip.');
            }
            foreach ($products as $product) {
                app(InventoryService::class)->ensureAccounts($product);
            }
            $accounts = InventoryAccount::where('depot_id', 1)->where(fn ($q) => $q->where('owner_key', 'trip:'.$tripId)->orWhere(fn ($q) => $q->where('owner_key', 'depot')->whereIn('product_id', $products->pluck('id'))))->orderBy('id')->lockForUpdate()->get();
            $tripAccounts = $accounts->where('owner_key', 'trip:'.$tripId);
            $stops = DB::table('trip_stops')->where('trip_id', $tripId)->where('route_version_id', $trip->selected_route_version_id)->orderBy('order_id')->get();
            $orders = Order::whereIn('id', $stops->pluck('order_id'))->orderBy('id')->lockForUpdate()->get();
            $trip = Trip::lockForUpdate()->findOrFail($tripId);
            if ($trip->lock_version !== $data['lock_version']) {
                throw new BusinessFailure('STALE_VERSION', 'Trip berubah. Muat ulang sebelum merekonsiliasi.');
            }
            if ($trip->status !== 'awaiting_reconciliation' || ! $trip->actual_departure_at || DB::table('trip_reconciliations')->where('trip_id', $tripId)->exists()) {
                throw new BusinessFailure('RECONCILIATION_LOCKED', 'Trip belum siap atau sudah direkonsiliasi.');
            }
            if ($stops->isEmpty() || $orders->count() !== $stops->count()) {
                throw new BusinessFailure('RESULTS_INCOMPLETE', 'Hasil tujuan belum lengkap.');
            }
            foreach ($stops as $stop) {
                $order = $orders->firstWhere('id', $stop->order_id);
                $result = DB::table('delivery_results')->where('trip_stop_id', $stop->id)->where('order_id', $stop->order_id)->first();
                if (! $result || ! in_array($stop->status, ['delivered', 'failed'], true) || $order->status !== $stop->status || $result->outcome !== $stop->status) {
                    throw new BusinessFailure('RESULTS_INCOMPLETE', 'Semua tujuan harus mempunyai hasil final yang sesuai.');
                }
                $payment = DB::table('payment_collections')->where('delivery_result_id', $result->id)->first();
                if (($stop->status === 'delivered' && (! $payment || (int) $payment->amount_rp !== $order->total_rp)) || ($stop->status === 'failed' && $payment)) {
                    throw new BusinessFailure('COLLECTION_CONFLICT', 'Catatan penerimaan COD tidak sesuai hasil pengiriman.');
                }
            }
            if (DB::table('active_order_allocations')->where('trip_id', $tripId)->count() !== $stops->count()
                || ! DB::table('courier_trip_locks')->where('courier_id', $trip->courier_id)->where('trip_id', $tripId)->exists()
                || ! DB::table('vehicle_trip_locks')->where('vehicle_id', $trip->vehicle_id)->where('trip_id', $tripId)->exists()) {
                throw new BusinessFailure('ALLOCATION_CONFLICT', 'Alokasi trip tidak lengkap.');
            }
            $input = collect($data['items'])->keyBy('product_id');
            foreach ($tripAccounts as $account) {
                if (! $input->has($account->product_id) || (int) $account->trip_id !== $tripId) {
                    throw new BusinessFailure('INVALID_RETURN_ITEMS', 'Hitung semua barang yang dimuat, termasuk yang bersaldo nol.');
                }
            }
            if ($tripAccounts->isEmpty()) {
                throw new BusinessFailure('STOCK_CONFLICT', 'Catatan muatan trip tidak tersedia.');
            }
            $cash = $this->cash($trip);
            $cashDifference = $data['actual_cash_rp'] - $cash;
            if ($cashDifference !== 0 && ! filled($data['discrepancy_reason'])) {
                throw new BusinessFailure('DISCREPANCY_REASON_REQUIRED', 'Alasan selisih uang wajib diisi.');
            }
            $rows = [];
            foreach ($data['items'] as $item) {
                foreach (['available', 'quarantine'] as $state) {
                    $expected = (int) ($tripAccounts->first(fn ($a) => (int) $a->product_id === $item['product_id'] && $a->stock_state === $state)?->balance_quantity ?? 0);
                    $actual = $item[$state.'_quantity'];
                    $difference = $actual - $expected;
                    if ($difference !== 0 && ! filled($item['discrepancy_reason'])) {
                        throw new BusinessFailure('DISCREPANCY_REASON_REQUIRED', 'Alasan selisih atau perubahan kondisi barang wajib diisi per barang.');
                    }
                    $rows[] = ['product_id' => $item['product_id'], 'stock_state' => $state, 'expected_quantity' => $expected, 'actual_quantity' => $actual, 'difference' => $difference, 'discrepancy_reason' => $difference !== 0 ? $item['discrepancy_reason'] : null];
                }
            }
            $now = now();
            $transaction = DB::table('inventory_transactions')->insertGetId(['trip_id' => $tripId, 'event_key' => 'reconciliation:'.$tripId, 'kind' => 'reconciliation', 'reason' => 'Barang kembali dan selisih disetujui admin', 'created_by' => $admin, 'occurred_at' => $now, 'created_at' => $now, 'updated_at' => $now]);
            foreach ($tripAccounts as $account) {
                if ($account->balance_quantity !== 0) {
                    $this->entry($transaction, $account, -$account->balance_quantity);
                }
            }
            foreach ($rows as $row) {
                if ($row['actual_quantity'] > 0) {
                    $account = $accounts->first(fn ($a) => $a->owner_key === 'depot' && (int) $a->product_id === $row['product_id'] && $a->stock_state === $row['stock_state']);
                    $this->entry($transaction, $account, $row['actual_quantity']);
                }
            }
            $id = DB::table('trip_reconciliations')->insertGetId(['trip_id' => $tripId, 'expected_cash_rp' => $cash, 'actual_cash_rp' => $data['actual_cash_rp'], 'cash_difference_rp' => $cashDifference, 'discrepancy_reason' => $cashDifference !== 0 ? $data['discrepancy_reason'] : null, 'approved_by' => $admin, 'approved_at' => $now, 'inventory_transaction_id' => $transaction]);
            foreach ($rows as $row) {
                DB::table('reconciliation_items')->insert(['trip_reconciliation_id' => $id, ...$row]);
            }
            $trip->status = 'completed';
            $trip->actual_return_at = $now;
            $trip->lock_version++;
            $trip->save();
            foreach (['active_order_allocations', 'courier_trip_locks', 'vehicle_trip_locks'] as $table) {
                DB::table($table)->where('trip_id', $tripId)->delete();
            }
            DB::table('trip_events')->insert(['trip_id' => $tripId, 'actor_id' => $admin, 'action' => 'reconciled', 'trip_version' => $trip->lock_version, 'reason' => $data['discrepancy_reason'] ?: 'Barang dan COD diterima; trip ditutup', 'created_at' => $now]);

            return ['status' => 200, 'body' => ['data' => ['id' => (string) $tripId, 'reconciliation_id' => (string) $id, 'status' => 'completed', 'lock_version' => $trip->lock_version]]];
        });
    }

    private function entry(int $transaction, InventoryAccount $account, int $delta): void
    {
        DB::table('inventory_entries')->insert(['inventory_transaction_id' => $transaction, 'inventory_account_id' => $account->id, 'quantity_delta' => $delta, 'created_at' => now(), 'updated_at' => now()]);
        $account->balance_quantity += $delta;
        $account->lock_version++;
        $account->save();
    }
}
