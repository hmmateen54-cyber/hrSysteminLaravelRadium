<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('task_assignments', function (Blueprint $table) {
            $table->unsignedBigInteger('progress_version')->default(0);
            $table->uuid('last_client_event_id')->nullable()->unique();
        });
    }

    public function down(): void
    {
        Schema::table('task_assignments', function (Blueprint $table) {
            $table->dropUnique(['last_client_event_id']);
            $table->dropColumn(['progress_version', 'last_client_event_id']);
        });
    }
};
