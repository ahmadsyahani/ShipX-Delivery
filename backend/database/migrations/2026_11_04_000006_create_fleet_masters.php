<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->unsignedInteger('lock_version')->default(0);
        });
        Schema::create('vehicles', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('depot_id')->constrained()->restrictOnDelete();
            $table->string('code', 64);
            $table->string('name', 160);
            $table->string('plate_number', 16);
            $table->enum('travel_mode', ['motorcycle', 'car']);
            $table->unsignedBigInteger('max_load_weight_g');
            $table->unsignedBigInteger('max_load_volume_cm3');
            $table->boolean('is_active')->default(false);
            $table->unsignedInteger('lock_version')->default(0);
            $table->timestamps();
            $table->unique(['depot_id', 'code']);
            $table->unique(['depot_id', 'plate_number']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('vehicles');
        Schema::table('users', fn (Blueprint $table) => $table->dropColumn('lock_version'));
    }
};
