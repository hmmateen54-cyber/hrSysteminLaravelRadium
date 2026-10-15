<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class TaskAssignment extends Model
{
    protected $fillable = [
        'task_id', 'employee_id', 'status', 'progress_notes', 'assigned_at',
        'progress_version', 'last_client_event_id',
    ];

    protected $hidden = ['last_client_event_id'];

    protected function casts(): array
    {
        return ['assigned_at' => 'datetime'];
    }

    public function task(): BelongsTo
    {
        return $this->belongsTo(Task::class);
    }

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }
}
