<?php

namespace App\Models;


use App\Models\Attendance;
use App\Models\Leave;
use App\Models\Performance;
use App\Models\Salary;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Employee extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'employee_id',
        'phone',
        'department',
        'designation',
        'joining_date',
        'salary',
    ];

    protected function casts(): array
    {
        return [
            'joining_date' => 'date',
            'salary' => 'decimal:2',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function attendances()
    {
        return $this->hasMany(Attendance::class);
    }
     public function leaves()
    {
        return $this->hasMany(Leave::class);
    }

    public function performances()
    {
        return $this->hasMany(Performance::class);
    }

    public function salaries()
    {
        return $this->hasMany(Salary::class);
    }
}
