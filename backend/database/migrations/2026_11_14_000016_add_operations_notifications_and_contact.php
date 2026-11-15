<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notifications', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('type');
            $table->morphs('notifiable');
            $table->text('data');
            $table->timestamp('read_at')->nullable();
            $table->timestamps();
        });
        Schema::table('depots', fn (Blueprint $table) => $table->string('phone', 30)->nullable());
    }

    public function down(): void
    {
        Schema::table('depots', fn (Blueprint $table) => $table->dropColumn('phone'));
        Schema::dropIfExists('notifications');
    }
};
