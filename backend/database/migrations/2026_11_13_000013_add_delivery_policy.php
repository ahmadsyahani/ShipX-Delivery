<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('depots', function (Blueprint $table) {
            $table->unsignedInteger('delivery_per_km_rp')->default(1000);
            $table->unsignedInteger('express_extra_percent')->default(50);
            $table->unsignedInteger('delivery_prep_minutes')->default(30);
            $table->unsignedInteger('delivery_speed_kmh')->default(20);
        });
        Schema::table('orders', function (Blueprint $table) {
            $table->string('delivery_type', 16)->default('regular');
            $table->unsignedInteger('delivery_distance_m')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('orders', fn (Blueprint $table) => $table->dropColumn(['delivery_type', 'delivery_distance_m']));
        Schema::table('depots', fn (Blueprint $table) => $table->dropColumn(['delivery_per_km_rp', 'express_extra_percent', 'delivery_prep_minutes', 'delivery_speed_kmh']));
    }
};
