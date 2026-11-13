<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('trip_optimizations', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('trip_id')->constrained()->cascadeOnDelete();
            $table->foreignId('actor_id')->constrained('users');
            $table->unsignedInteger('trip_version');
            $table->unsignedBigInteger('route_version_id');
            $table->string('snapshot_hash', 64);
            $table->json('input');
            $table->json('result');
            $table->timestamp('expires_at')->index();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('trip_optimizations');
    }
};
