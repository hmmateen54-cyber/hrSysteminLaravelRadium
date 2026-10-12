<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('leaves', function (Blueprint $table) {
            $table->dropUnique('leaves_sync_id_unique');
            $table->unique(['employee_id', 'sync_id'], 'leaves_employee_sync_id_unique');
        });

        Schema::create('location_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('employee_id')->constrained()->cascadeOnDelete();
            $table->uuid('client_event_id');
            $table->decimal('latitude', 10, 7);
            $table->decimal('longitude', 10, 7);
            $table->timestamp('recorded_at');
            $table->decimal('accuracy', 10, 2)->nullable();
            $table->string('purpose', 120)->nullable();
            $table->timestamps();
            $table->unique(['user_id', 'client_event_id'], 'location_events_user_client_id_unique');
            $table->index(['employee_id', 'recorded_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('location_events');

        // Keep the account-scoped leave index and data intact on rollback.
        // Reinstating a global unique index could fail if accounts now share an ID.
    }
};
