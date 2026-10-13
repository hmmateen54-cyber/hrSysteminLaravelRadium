<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LocationEvent extends Model
{
    protected $fillable = [
        'user_id',
        'employee_id',
        'attendance_id',
        'client_event_id',
        'event_type',
        'latitude',
        'longitude',
        'address',
        'address_status',
        'address_resolved_at',
        'recorded_at',
        'action_at',
        'synced_at',
        'accuracy',
        'purpose',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'address_resolved_at' => 'datetime',
        'recorded_at' => 'datetime',
        'action_at' => 'datetime',
        'synced_at' => 'datetime',
        'accuracy' => 'decimal:2',
    ];

    public function employee(): BelongsTo
    {
        return $this->belongsTo(Employee::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function attendance(): BelongsTo
    {
        return $this->belongsTo(Attendance::class);
    }
}
