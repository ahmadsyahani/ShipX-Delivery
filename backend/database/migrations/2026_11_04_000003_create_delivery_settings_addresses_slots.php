<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('depots', function (Blueprint $table): void {
            $table->text('address_text')->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('timezone', 50)->default('Asia/Jakarta');
            $table->unsignedInteger('service_radius_m')->nullable();
            $table->unsignedInteger('delivery_fee_rp')->nullable();
            $table->unsignedInteger('pending_ttl_minutes')->default(30);
            $table->unsignedInteger('default_service_seconds')->default(300);
            $table->unsignedInteger('lock_version')->default(0);
        });
        Schema::create('addresses', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->string('label', 80);
            $table->string('recipient_name', 160);
            $table->string('phone', 30);
            $table->text('address_text');
            $table->decimal('latitude', 10, 7);
            $table->decimal('longitude', 10, 7);
            $table->text('directions')->nullable();
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('lock_version')->default(0);
            $table->timestamps();
            $table->index(['user_id', 'is_active']);
        });
        Schema::create('delivery_slots', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('depot_id')->constrained()->restrictOnDelete();
            $table->date('service_date');
            $table->dateTime('window_start_at');
            $table->dateTime('window_end_at');
            $table->dateTime('cutoff_at');
            $table->boolean('is_active')->default(true);
            $table->unsignedInteger('lock_version')->default(0);
            $table->timestamps();
            $table->unique(['depot_id', 'window_start_at', 'window_end_at'], 'delivery_slots_depot_window_unique');
            $table->index(['depot_id', 'service_date', 'is_active']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('delivery_slots');
        Schema::dropIfExists('addresses');
        Schema::table('depots', fn (Blueprint $table) => $table->dropColumn(['address_text', 'latitude', 'longitude', 'timezone', 'service_radius_m', 'delivery_fee_rp', 'pending_ttl_minutes', 'default_service_seconds', 'lock_version']));
    }
};
