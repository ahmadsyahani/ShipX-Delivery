<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('trips', function (Blueprint $t) {
            $t->id();
            $t->string('trip_number', 64)->unique();
            $t->foreignId('depot_id')->constrained();
            $t->foreignId('courier_id')->constrained('users');
            $t->foreignId('vehicle_id')->constrained();
            $t->string('status', 32)->default('draft');
            $t->dateTime('planned_departure_at');
            $t->dateTime('actual_departure_at')->nullable();
            $t->dateTime('actual_return_at')->nullable();
            $t->string('timezone_snapshot', 64);
            $t->unsignedBigInteger('capacity_weight_g_snapshot');
            $t->unsignedBigInteger('capacity_volume_cm3_snapshot');
            $t->unsignedBigInteger('planned_weight_g');
            $t->unsignedBigInteger('planned_volume_cm3');
            $t->unsignedBigInteger('loaded_weight_g')->default(0);
            $t->unsignedBigInteger('loaded_volume_cm3')->default(0);
            $t->foreignId('created_by')->constrained('users');
            $t->unsignedBigInteger('selected_route_version_id')->nullable();
            $t->unsignedInteger('lock_version')->default(0);
            $t->timestamps();
        });
        Schema::create('route_versions', function (Blueprint $t) {
            $t->id();
            $t->foreignId('trip_id')->constrained();
            $t->unsignedInteger('version_number');
            $t->string('source', 32)->default('manual');
            $t->string('feasibility_status', 32)->default('not_evaluated');
            $t->json('input_snapshot');
            $t->json('selected_snapshot');
            $t->foreignId('created_by')->constrained('users');
            $t->timestamps();
            $t->unique(['trip_id', 'version_number']);
            $t->unique(['trip_id', 'id']);
        });
        Schema::table('trips', function (Blueprint $t) {
            $t->foreign(['id', 'selected_route_version_id'], 'trip_selected_route_fk')->references(['trip_id', 'id'])->on('route_versions');
        });
        Schema::create('trip_stops', function (Blueprint $t) {
            $t->id();
            $t->foreignId('trip_id')->constrained();
            $t->unsignedBigInteger('route_version_id');
            $t->foreignId('order_id')->constrained();
            $t->unsignedSmallInteger('sequence_no');
            $t->string('status', 24)->default('pending');
            $t->dateTime('estimated_arrival_at')->nullable();
            $t->dateTime('estimated_service_start_at')->nullable();
            $t->unsignedInteger('planned_service_seconds');
            $t->dateTime('voided_at')->nullable();
            $t->string('void_reason', 500)->nullable();
            $t->timestamps();
            $t->foreign(['trip_id', 'route_version_id'])->references(['trip_id', 'id'])->on('route_versions');
            $t->unique(['trip_id', 'route_version_id', 'sequence_no'], 'stop_sequence_unique');
            $t->unique(['trip_id', 'route_version_id', 'order_id'], 'stop_order_unique');
            $t->unique(['order_id', 'trip_id', 'id'], 'stop_claim_unique');
            $t->unique(['order_id', 'id']);
        });
        Schema::create('active_order_allocations', function (Blueprint $t) {
            $t->foreignId('order_id')->primary()->constrained();
            $t->foreignId('trip_id')->constrained();
            $t->unsignedBigInteger('trip_stop_id')->unique();
            $t->foreign(['order_id', 'trip_id', 'trip_stop_id'], 'allocation_stop_fk')->references(['order_id', 'trip_id', 'id'])->on('trip_stops');
        });
        foreach (['courier' => 'users', 'vehicle' => 'vehicles'] as $owner => $table) {
            Schema::create($owner.'_trip_locks', function (Blueprint $t) use ($owner, $table) {
                $t->foreignId($owner.'_id')->primary()->constrained($table);
                $t->foreignId('trip_id')->unique()->constrained();
            });
        }
        Schema::create('trip_events', function (Blueprint $t) {
            $t->id();
            $t->foreignId('trip_id')->constrained();
            $t->foreignId('actor_id')->constrained('users');
            $t->string('action', 32);
            $t->unsignedInteger('trip_version');
            $t->string('reason', 500)->nullable();
            $t->timestamp('created_at');
        });
    }

    public function down(): void
    {
        foreach (['trip_events', 'vehicle_trip_locks', 'courier_trip_locks', 'active_order_allocations', 'trip_stops'] as $table) {
            Schema::dropIfExists($table);
        }
        Schema::table('trips', fn (Blueprint $t) => $t->dropForeign('trip_selected_route_fk'));
        Schema::dropIfExists('route_versions');
        Schema::dropIfExists('trips');
    }
};
