<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('projects', function (Blueprint $table) {
            $table->id();
            $table->string('name', 160);
            $table->text('description')->nullable();
            $table->enum('status', ['active', 'completed', 'on_hold'])->default('active');
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->timestamps();
            $table->index(['status', 'updated_at']);
        });

        Schema::create('tasks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('project_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->string('title', 180);
            $table->text('description')->nullable();
            $table->enum('priority', ['low', 'normal', 'high', 'urgent'])->default('normal');
            $table->date('due_date')->nullable();
            $table->timestamps();
            $table->index(['project_id', 'due_date']);
            $table->index(['priority', 'due_date']);
        });

        Schema::create('task_assignments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('task_id')->constrained()->cascadeOnDelete();
            $table->foreignId('employee_id')->constrained()->cascadeOnDelete();
            $table->enum('status', ['assigned', 'in_progress', 'completed', 'on_hold'])->default('assigned');
            $table->text('progress_notes')->nullable();
            $table->timestamp('assigned_at');
            $table->timestamps();
            $table->unique(['task_id', 'employee_id']);
            $table->index(['employee_id', 'status']);
        });

        Schema::create('feedback', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->uuid('client_submission_id')->nullable();
            $table->string('category', 40);
            $table->string('subject', 160);
            $table->text('message');
            $table->unsignedTinyInteger('rating')->nullable();
            $table->enum('status', ['new', 'reviewing', 'resolved'])->default('new');
            $table->text('internal_remarks')->nullable();
            $table->timestamps();
            $table->unique(['user_id', 'client_submission_id'], 'feedback_user_client_submission_unique');
            $table->index(['status', 'category', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('feedback');
        Schema::dropIfExists('task_assignments');
        Schema::dropIfExists('tasks');
        Schema::dropIfExists('projects');
    }
};
