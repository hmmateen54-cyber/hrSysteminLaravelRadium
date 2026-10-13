<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Employee extends Model
{
    use HasFactory;

    /**
     * Fields HR must complete before a self-registered account is activated.
     * Salary is intentionally excluded because it is maintained separately.
     *
     * @var array<string, string>
     */
    public const PROFILE_COMPLETION_FIELDS = [
        'employee_id' => 'employee ID',
        'phone' => 'phone',
        'department' => 'department',
        'designation' => 'designation',
        'joining_date' => 'joining date',
    ];

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

    /** @return list<string> */
    public function missingProfileCompletionFields(): array
    {
        return collect(self::PROFILE_COMPLETION_FIELDS)
            ->filter(fn (string $label, string $field) => blank($this->getAttribute($field)))
            ->values()
            ->all();
    }

    public function hasCompleteProfile(): bool
    {
        return $this->missingProfileCompletionFields() === [];
    }
}
