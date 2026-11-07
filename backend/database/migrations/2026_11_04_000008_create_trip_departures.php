<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('inventory_accounts', function (Blueprint $t) {
            $t->foreignId('trip_id')->nullable()->constrained()->restrictOnDelete();
        });
        Schema::table('inventory_transactions', function (Blueprint $t) {
            $t->foreignId('trip_id')->nullable()->constrained()->restrictOnDelete();
        });
        Schema::create('trip_departure_reviews', function (Blueprint $t) {
            $t->id();
            $t->foreignId('trip_id')->constrained();
            $t->unsignedBigInteger('route_version_id');
            $t->unsignedInteger('trip_version');
            $t->string('source', 40);
            $t->string('source_reference', 500);
            $t->json('leg_seconds');
            $t->json('schedule_snapshot');
            $t->json('master_versions');
            $t->foreignId('reviewed_by')->constrained('users');
            $t->string('reason', 500);
            $t->boolean('handling_checked');
            $t->dateTime('reviewed_at');
            $t->dateTime('expires_at');
            $t->unique(['trip_id', 'id']);
            $t->foreign(['trip_id', 'route_version_id'])->references(['trip_id', 'id'])->on('route_versions');
        });
        Schema::create('trip_load_confirmations', function (Blueprint $t) {
            $t->foreignId('trip_id')->primary()->constrained();
            $t->foreignId('courier_id')->constrained('users');
            $t->unsignedBigInteger('route_version_id');
            $t->unsignedBigInteger('departure_review_id');
            $t->foreignId('inventory_transaction_id')->unique()->constrained();
            $t->json('manifest');
            $t->json('departure_schedule');
            $t->dateTime('confirmed_at');
            $t->foreign(['trip_id', 'route_version_id'])->references(['trip_id', 'id'])->on('route_versions');
            $t->foreign(['trip_id', 'departure_review_id'], 'load_departure_review_fk')->references(['trip_id', 'id'])->on('trip_departure_reviews');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('trip_load_confirmations');
        Schema::dropIfExists('trip_departure_reviews');
        Schema::table('inventory_transactions', fn (Blueprint $t) => $t->dropConstrainedForeignId('trip_id'));
        Schema::table('inventory_accounts', fn (Blueprint $t) => $t->dropConstrainedForeignId('trip_id'));
    }
};
