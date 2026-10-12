
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('attendances', function (Blueprint $table) {
            $table->string('sync_id')->nullable();

            $table->unique(
                ['employee_id', 'sync_id'],
                'attendances_employee_sync_id_unique'
            );
        });
    }

    public function down(): void
    {
        Schema::table('attendances', function (Blueprint $table) {
            $table->dropUnique('attendances_employee_sync_id_unique');
            $table->dropColumn('sync_id');
        });
    }
};
