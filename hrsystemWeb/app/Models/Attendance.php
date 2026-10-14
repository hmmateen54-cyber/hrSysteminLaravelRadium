<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use App\Models\Employee;

class Attendance extends Model
{
    protected $hidden = ['latitude', 'longitude'];

    protected $fillable = [
        'employee_id',
        'attendance_date',
        'status',
        'check_in',
        'check_out',
        'remarks',
        'latitude',
        'longitude',
        'sync_id',
    ];

    protected $casts = [
        'attendance_date' => 'date',
    ];

    public function employee()
    {
        return $this->belongsTo(Employee::class, 'employee_id');
    }

    public function locationEvents(): HasMany
    {
        return $this->hasMany(LocationEvent::class);
    }

    public function checkInLocationEvent(): HasOne
    {
        // The check-in event records the location associated with the attendance start.
        return $this->hasOne(LocationEvent::class, 'attendance_id')
            ->where('event_type', 'check_in');
    }
}
