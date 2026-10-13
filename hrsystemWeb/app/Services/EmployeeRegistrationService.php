<?php

namespace App\Services;

use App\Models\Employee;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class EmployeeRegistrationService
{
    /**
     * Create a public employee account and its initial linked profile.
     * The role and pending state are set only by the server.
     *
     * @param  array{name: string, email: string, password: string}  $attributes
     */
    public function register(array $attributes): User
    {
        return DB::transaction(function () use ($attributes): User {
            $user = User::create([
                'name' => trim($attributes['name']),
                'email' => Str::lower(trim($attributes['email'])),
                'password' => Hash::make($attributes['password']),
                'role' => 'employee',
                'account_status' => 'pending',
            ]);

            $user->employee()->create([
                'employee_id' => $this->generateEmployeeId((int) $user->getKey()),
            ]);

            return $user->load('employee');
        });
    }

    private function generateEmployeeId(int $userId): string
    {
        $baseEmployeeId = 'EMP-'.str_pad((string) $userId, 5, '0', STR_PAD_LEFT);
        $employeeId = $baseEmployeeId;
        $suffix = 1;

        while (Employee::where('employee_id', $employeeId)->exists()) {
            $employeeId = $baseEmployeeId.'-'.$suffix++;
        }

        return $employeeId;
    }
}
