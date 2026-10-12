<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Salary extends Model
{
    public const PAYMENT_STATUSES = ['pending', 'paid'];

    protected $fillable = [
        'employee_id',
        'basic_salary',
        'allowances',
        'deductions',
        'net_salary',
        'salary_month',
        'payment_status',
    ];

    protected function casts(): array
    {
        return [
            'basic_salary' => 'decimal:2',
            'allowances' => 'decimal:2',
            'deductions' => 'decimal:2',
            'net_salary' => 'decimal:2',
            'salary_month' => 'date',
        ];
    }

    public function employee()
    {
        return $this->belongsTo(Employee::class);
    }
}
