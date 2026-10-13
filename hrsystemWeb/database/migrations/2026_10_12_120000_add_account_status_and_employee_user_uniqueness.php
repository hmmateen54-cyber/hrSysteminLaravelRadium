<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('users', 'account_status')) {
            Schema::table('users', function (Blueprint $table) {
                // Existing accounts stay active; registration sets pending explicitly.
                $table->string('account_status')->default('active');
            });
        }

        if (Schema::hasTable('employees')) {
            $hasDuplicateUsers = DB::table('employees')
                ->select('user_id')
                ->groupBy('user_id')
                ->havingRaw('COUNT(*) > 1')
                ->exists();

            if ($hasDuplicateUsers) {
                throw new RuntimeException(
                    'Cannot enforce one employee profile per user while duplicate employee user links exist.'
                );
            }

            Schema::table('employees', function (Blueprint $table) {
                $table->unique('user_id', 'employees_user_id_unique');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('employees')) {
            Schema::table('employees', function (Blueprint $table) {
                $table->dropUnique('employees_user_id_unique');
            });
        }

        if (Schema::hasColumn('users', 'account_status')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('account_status');
            });
        }
    }
};
