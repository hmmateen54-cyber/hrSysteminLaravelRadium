<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('performances') && Schema::hasColumn('performances', 'rating')) {
            Schema::table('performances', function (Blueprint $table) {
                $table->decimal('rating', 3, 1)->change();
            });
        }
    }

    public function down(): void
    {
        if (! Schema::hasTable('performances') || ! Schema::hasColumn('performances', 'rating')) {
            return;
        }

        if (DB::table('performances')->where('rating', '>', 9.9)->exists()) {
            throw new RuntimeException('Cannot shrink performance ratings while records above 9.9 exist.');
        }

        Schema::table('performances', function (Blueprint $table) {
            $table->decimal('rating', 2, 1)->change();
        });
    }
};
