<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('location_events', function (Blueprint $table) {
            $table->timestamp('synced_at')->nullable()->after('recorded_at');
        });
    }

    public function down(): void
    {
        Schema::table('location_events', function (Blueprint $table) {
            $table->dropColumn('synced_at');
        });
    }
};
