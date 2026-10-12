<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LocationEvent extends Model
{
    protected $fillable = [
        'user_id',
        'employee_id',
        'client_event_id',
        'latitude',
        'longitude',
        'recorded_at',
        'accuracy',
        'purpose',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'recorded_at' => 'datetime',
        'accuracy' => 'decimal:2',
    ];
}
