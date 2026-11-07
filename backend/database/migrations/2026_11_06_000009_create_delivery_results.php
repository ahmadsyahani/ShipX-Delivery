<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('delivery_proof_uploads', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('trip_stop_id')->constrained();
            $table->foreignId('uploaded_by')->constrained('users');
            $table->uuid('idempotency_key');
            $table->string('storage_key')->unique();
            $table->string('mime_type', 40);
            $table->unsignedInteger('file_size_bytes');
            $table->char('checksum_sha256', 64);
            $table->string('status', 20)->default('pending');
            $table->dateTime('expires_at');
            $table->timestamps();
            $table->unique(['uploaded_by', 'idempotency_key'], 'proof_upload_key_unique');
        });
        Schema::create('delivery_results', function (Blueprint $table) {
            $table->id();
            $table->foreignId('trip_stop_id')->unique()->constrained();
            $table->foreignId('order_id')->unique()->constrained();
            $table->foreignId('recorded_by')->constrained('users');
            $table->string('outcome', 20);
            $table->string('failure_reason', 500)->nullable();
            $table->string('notes', 500)->nullable();
            $table->dateTime('occurred_at');
            $table->dateTime('recorded_at');
            $table->foreign(['order_id', 'trip_stop_id'])->references(['order_id', 'id'])->on('trip_stops');
            $table->unique(['id', 'order_id']);
        });
        Schema::create('delivery_result_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('delivery_result_id')->constrained();
            $table->foreignId('order_item_id')->constrained();
            $table->unsignedInteger('delivered_quantity');
            $table->unique(['delivery_result_id', 'order_item_id']);
        });
        Schema::create('delivery_proofs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('delivery_result_id')->unique()->constrained();
            $table->uuid('upload_id')->unique();
            $table->foreign('upload_id')->references('id')->on('delivery_proof_uploads');
            $table->string('storage_key')->unique();
            $table->string('mime_type', 40);
            $table->unsignedInteger('file_size_bytes');
            $table->char('checksum_sha256', 64);
            $table->foreignId('uploaded_by')->constrained('users');
        });
        Schema::create('payment_collections', function (Blueprint $table) {
            $table->id();
            $table->foreignId('delivery_result_id')->unique()->constrained();
            $table->foreignId('collected_by')->constrained('users');
            $table->unsignedBigInteger('amount_rp');
            $table->string('method', 16)->default('cash');
            $table->dateTime('collected_at');
        });
    }

    public function down(): void
    {
        foreach (['payment_collections', 'delivery_proofs', 'delivery_result_items', 'delivery_results', 'delivery_proof_uploads'] as $name) {
            Schema::dropIfExists($name);
        }
    }
};
