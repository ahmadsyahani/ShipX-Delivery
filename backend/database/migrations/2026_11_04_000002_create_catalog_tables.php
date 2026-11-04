<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('depots', function (Blueprint $table): void {
            $table->id();
            $table->string('name');
            $table->timestamps();
        });
        // Only the catalog identity is configured in this phase; location and
        // delivery settings will be collected before checkout is enabled.
        DB::table('depots')->insert(['id' => 1, 'name' => 'Depot utama', 'created_at' => now(), 'updated_at' => now()]);
        Schema::create('products', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('depot_id')->constrained()->restrictOnDelete();
            $table->string('sku', 64);
            $table->string('name', 160);
            $table->string('category', 80);
            $table->string('unit_label', 30);
            $table->unsignedInteger('unit_price_rp');
            $table->unsignedInteger('shipping_weight_g');
            $table->unsignedBigInteger('shipping_volume_cm3');
            $table->unsignedInteger('length_mm');
            $table->unsignedInteger('width_mm');
            $table->unsignedInteger('height_mm');
            $table->text('handling_notes')->nullable();
            $table->boolean('is_active')->default(false);
            $table->unsignedInteger('lock_version')->default(0);
            $table->timestamps();
            $table->unique(['depot_id', 'sku']);
            $table->index(['depot_id', 'is_active', 'name']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
        Schema::dropIfExists('depots');
    }
};
