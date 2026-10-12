<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Performance extends Model
{
    protected $fillable = [
        'employee_id',
        'review_date',
        'rating',
        'comments',
    ];

    protected function casts(): array
    {
        return [
            'review_date' => 'date',
            'rating' => 'decimal:1',
        ];
    }

    public function employee()
    {
        return $this->belongsTo(Employee::class, 'employee_id');
    }
}
