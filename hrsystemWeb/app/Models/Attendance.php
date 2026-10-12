<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Models\Employee;

class Attendance extends Model
{
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
}
