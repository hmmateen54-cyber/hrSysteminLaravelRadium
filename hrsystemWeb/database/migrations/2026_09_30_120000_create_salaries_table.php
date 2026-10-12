<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('salaries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('employee_id')->constrained()->cascadeOnDelete();
            $table->decimal('basic_salary', 12, 2);
            $table->decimal('allowances', 12, 2)->default(0);
            $table->decimal('deductions', 12, 2)->default(0);
            $table->decimal('net_salary', 12, 2);
            $table->date('salary_month');
            $table->string('payment_status', 20)->default('pending');
            $table->timestamps();

            $table->unique(['employee_id', 'salary_month']);
            $table->index(['salary_month', 'payment_status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('salaries');
    }
};
