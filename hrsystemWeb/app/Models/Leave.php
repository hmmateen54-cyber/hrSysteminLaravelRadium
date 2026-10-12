<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use App\Models\Employee;

class Leave extends Model
{
    protected $fillable = [
        'employee_id',
        'start_date',
        'end_date',
        'leave_type',
        'reason',
        'status',
        'admin_remarks',
        'sync_id',
    ];

    protected $casts = [
        'start_date' => 'date',
        'end_date' => 'date',
    ];

    public function employee()
    {
        return $this->belongsTo(Employee::class, 'employee_id');
    }
   
}
