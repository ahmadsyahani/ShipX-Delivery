<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('trip_reconciliations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('trip_id')->unique()->constrained();
            $table->unsignedBigInteger('expected_cash_rp');
            $table->unsignedBigInteger('actual_cash_rp');
            $table->bigInteger('cash_difference_rp');
            $table->string('discrepancy_reason', 500)->nullable();
            $table->foreignId('approved_by')->constrained('users');
            $table->dateTime('approved_at');
            $table->foreignId('inventory_transaction_id')->unique()->constrained();
        });
        Schema::create('reconciliation_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('trip_reconciliation_id')->constrained();
            $table->foreignId('product_id')->constrained();
            $table->string('stock_state', 20);
            $table->unsignedInteger('expected_quantity');
            $table->unsignedInteger('actual_quantity');
            $table->bigInteger('difference');
            $table->string('discrepancy_reason', 500)->nullable();
            $table->unique(['trip_reconciliation_id', 'product_id', 'stock_state'], 'reconciliation_product_state_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reconciliation_items');
        Schema::dropIfExists('trip_reconciliations');
    }
};
