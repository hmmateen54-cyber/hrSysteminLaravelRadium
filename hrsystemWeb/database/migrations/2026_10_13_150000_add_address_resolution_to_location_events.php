<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('location_events', function (Blueprint $table) {
            $table->text('address')->nullable()->after('longitude');
            $table->string('address_status', 20)->nullable()->after('address');
            $table->timestamp('address_resolved_at')->nullable()->after('address_status');
        });
    }

    public function down(): void
    {
        Schema::table('location_events', function (Blueprint $table) {
            $table->dropColumn(['address', 'address_status', 'address_resolved_at']);
        });
    }
};
