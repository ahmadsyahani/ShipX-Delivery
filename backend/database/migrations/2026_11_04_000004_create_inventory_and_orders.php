<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('inventory_accounts', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('depot_id')->constrained()->restrictOnDelete();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->string('owner_key', 80)->default('depot');
            $table->enum('stock_state', ['available', 'quarantine']);
            $table->unsignedBigInteger('balance_quantity')->default(0);
            $table->unsignedInteger('lock_version')->default(0);
            $table->timestamps();
            $table->unique(['depot_id', 'owner_key', 'product_id', 'stock_state'], 'inventory_account_owner_unique');
        });
        DB::table('products')->orderBy('id')->each(function ($product): void {
            foreach (['available', 'quarantine'] as $state) {
                DB::table('inventory_accounts')->insert(['depot_id' => $product->depot_id, 'product_id' => $product->id, 'owner_key' => 'depot', 'stock_state' => $state, 'balance_quantity' => 0, 'created_at' => now(), 'updated_at' => now()]);
            }
        });
        Schema::create('orders', function (Blueprint $table): void {
            $table->id();
            $table->string('order_number', 50)->unique();
            $table->foreignId('depot_id')->constrained()->restrictOnDelete();
            $table->foreignId('customer_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('source_address_id')->nullable()->constrained('addresses')->restrictOnDelete();
            $table->foreignId('delivery_slot_id')->constrained()->restrictOnDelete();
            $table->string('status', 40)->default('pending');
            $table->string('payment_status', 30)->default('unpaid');
            $table->string('recipient_name', 160);
            $table->string('recipient_phone', 30);
            $table->text('address_text');
            $table->decimal('latitude', 10, 7);
            $table->decimal('longitude', 10, 7);
            $table->text('directions')->nullable();
            $table->string('timezone_snapshot', 50);
            $table->dateTime('window_start_at');
            $table->dateTime('window_end_at');
            foreach (['subtotal_rp', 'delivery_fee_rp', 'total_rp', 'total_weight_g', 'total_volume_cm3'] as $column) {
                $table->unsignedBigInteger($column);
            }
            $table->dateTime('pending_expires_at');
            $table->dateTime('confirmed_at')->nullable();
            $table->dateTime('cancelled_at')->nullable();
            $table->dateTime('closed_at')->nullable();
            $table->string('status_reason', 500)->nullable();
            $table->unsignedInteger('lock_version')->default(0);
            $table->timestamps();
            $table->index(['customer_id', 'created_at']);
            $table->index(['status', 'pending_expires_at']);
            $table->index(['depot_id', 'status', 'window_start_at']);
        });
        Schema::create('order_items', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('order_id')->constrained()->restrictOnDelete();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->string('product_name_snapshot', 160);
            $table->string('unit_label_snapshot', 30);
            $table->unsignedInteger('quantity');
            foreach (['unit_price_rp', 'line_total_rp', 'unit_weight_g', 'unit_volume_cm3'] as $column) {
                $table->unsignedBigInteger($column);
            }
            foreach (['length_mm_snapshot', 'width_mm_snapshot', 'height_mm_snapshot'] as $column) {
                $table->unsignedInteger($column);
            }
            $table->text('handling_notes_snapshot')->nullable();
            $table->timestamps();
            $table->unique(['order_id', 'product_id']);
        });
        Schema::create('stock_reservations', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('order_item_id')->unique()->constrained()->restrictOnDelete();
            $table->foreignId('inventory_account_id')->constrained()->restrictOnDelete();
            $table->unsignedInteger('quantity');
            $table->enum('status', ['active', 'released', 'consumed'])->default('active');
            $table->dateTime('released_at')->nullable();
            $table->dateTime('consumed_at')->nullable();
            $table->timestamps();
            $table->index(['inventory_account_id', 'status']);
        });
        Schema::create('inventory_transactions', function (Blueprint $table): void {
            $table->id();
            $table->string('event_key', 120)->unique();
            $table->string('kind', 30);
            $table->foreignId('order_id')->nullable()->constrained()->restrictOnDelete();
            $table->text('reason');
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->dateTime('occurred_at');
            $table->timestamps();
        });
        Schema::create('inventory_entries', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('inventory_transaction_id')->constrained()->restrictOnDelete();
            $table->foreignId('inventory_account_id')->constrained()->restrictOnDelete();
            $table->bigInteger('quantity_delta');
            $table->timestamps();
            $table->unique(['inventory_transaction_id', 'inventory_account_id'], 'inventory_entry_account_unique');
        });
        Schema::create('idempotency_records', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->string('operation', 80);
            $table->uuid('idempotency_key');
            $table->char('request_hash', 64);
            $table->string('status', 20);
            $table->unsignedSmallInteger('response_code')->nullable();
            $table->json('response_body')->nullable();
            $table->dateTime('expires_at');
            $table->timestamps();
            $table->unique(['user_id', 'operation', 'idempotency_key'], 'idempotency_operation_key_unique');
        });
    }

    public function down(): void
    {
        foreach (['idempotency_records', 'inventory_entries', 'inventory_transactions', 'stock_reservations', 'order_items', 'orders', 'inventory_accounts'] as $table) {
            Schema::dropIfExists($table);
        }
    }
};
