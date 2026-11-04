<?php

namespace App\Services;

use App\Exceptions\BusinessFailure;
use App\Models\Depot;
use App\Models\InventoryAccount;
use App\Models\Product;
use App\Models\StockReservation;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;

class InventoryService
{
    public function ensureAccounts(Product $product): void
    {
        foreach (['available', 'quarantine'] as $state) {
            InventoryAccount::firstOrCreate(['depot_id' => $product->depot_id, 'product_id' => $product->id, 'owner_key' => 'depot', 'stock_state' => $state], ['balance_quantity' => 0]);
        }
    }

    public function lockAccounts(array $productIds)
    {
        return InventoryAccount::where('depot_id', 1)->where('owner_key', 'depot')->whereIn('product_id', $productIds)->orderBy('id')->lockForUpdate()->get();
    }

    public function reserved(int $account): int
    {
        return (int) StockReservation::where('inventory_account_id', $account)->where('status', 'active')->sum('quantity');
    }

    public function decorate(Builder $query): Builder
    {
        return $query->select('products.*')->selectSub(
            DB::table('inventory_accounts')->select('balance_quantity')->whereColumn('product_id', 'products.id')->where('depot_id', 1)->where('owner_key', 'depot')->where('stock_state', 'available')->limit(1), 'physical_quantity'
        )->selectSub(DB::table('stock_reservations')->join('inventory_accounts', 'inventory_accounts.id', '=', 'stock_reservations.inventory_account_id')->selectRaw('COALESCE(SUM(stock_reservations.quantity),0)')->whereColumn('inventory_accounts.product_id', 'products.id')->where('inventory_accounts.depot_id', 1)->where('inventory_accounts.owner_key', 'depot')->where('inventory_accounts.stock_state', 'available')->where('stock_reservations.status', 'active'), 'reserved_quantity')
            ->selectSub(DB::table('inventory_accounts')->select('balance_quantity')->whereColumn('product_id', 'products.id')->where('depot_id', 1)->where('owner_key', 'depot')->where('stock_state', 'quarantine')->limit(1), 'quarantine_quantity');
    }

    public function adjust(int $actor, int $productId, string $state, int $delta, string $reason, string $key): array
    {
        return DB::transaction(function () use ($actor, $productId, $state, $delta, $reason, $key) {
            Depot::lockForUpdate()->findOrFail(1);
            $product = Product::where('depot_id', 1)->lockForUpdate()->findOrFail($productId);
            $this->ensureAccounts($product);
            $account = $this->lockAccounts([$productId])->firstWhere('stock_state', $state);
            $reserved = $this->reserved($account->id);
            $balance = $account->balance_quantity + $delta;
            if ($delta === 0 || $balance < 0 || $balance < $reserved) {
                throw new BusinessFailure('STOCK_CONFLICT', 'Saldo akhir tidak boleh negatif atau kurang dari stok yang sudah direservasi.');
            }
            $first = ! DB::table('inventory_entries')->where('inventory_account_id', $account->id)->exists();
            $transaction = DB::table('inventory_transactions')->insertGetId(['event_key' => 'stock:'.$actor.':'.$key, 'kind' => $first && $delta > 0 ? 'opening' : 'adjustment', 'reason' => $reason, 'created_by' => $actor, 'occurred_at' => now(), 'created_at' => now(), 'updated_at' => now()]);
            DB::table('inventory_entries')->insert(['inventory_transaction_id' => $transaction, 'inventory_account_id' => $account->id, 'quantity_delta' => $delta, 'created_at' => now(), 'updated_at' => now()]);
            $account->balance_quantity = $balance;
            $account->lock_version++;
            $account->save();

            return ['status' => 201, 'body' => ['data' => ['transaction_id' => (string) $transaction, 'balance_quantity' => $balance, 'available_quantity' => $balance - $reserved]]];
        });
    }
}
