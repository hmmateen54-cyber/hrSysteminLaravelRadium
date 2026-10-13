<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LocationEvent extends Model
{
    protected $fillable = [
        'user_id',
        'employee_id',
        'client_event_id',
        'latitude',
        'longitude',
        'recorded_at',
        'synced_at',
        'accuracy',
        'purpose',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'recorded_at' => 'datetime',
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
}
