<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('location_events', function (Blueprint $table) {
            $table->foreignId('attendance_id')
                ->nullable()
                ->after('employee_id')
                ->constrained('attendances')
                ->nullOnDelete();
            $table->string('event_type', 20)->nullable()->after('attendance_id');
            $table->timestamp('action_at')->nullable()->after('recorded_at');
            $table->unique(['attendance_id', 'event_type'], 'location_events_attendance_action_unique');
        });
    }

    public function down(): void
    {
        Schema::table('location_events', function (Blueprint $table) {
            $table->dropUnique('location_events_attendance_action_unique');
            $table->dropConstrainedForeignId('attendance_id');
            $table->dropColumn(['event_type', 'action_at']);
        });
    }
};
