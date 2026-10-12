<?php

namespace App\Actions\Fortify;

use App\Models\User;
use App\Models\Employee;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Laravel\Fortify\Contracts\CreatesNewUsers;
use Laravel\Jetstream\Jetstream;

class CreateNewUser implements CreatesNewUsers
{
    use PasswordValidationRules;

    /**
     * Validate and create a newly registered user.
     *
     * @param  array<string, string>  $input
     */
    public function create(array $input): User
    {
        Validator::make($input, [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users'],
            'password' => $this->passwordRules(),
            'terms' => Jetstream::hasTermsAndPrivacyPolicyFeature() ? ['accepted', 'required'] : '',
        ])->validate();

        return DB::transaction(function () use ($input) {
            $user = User::create([
                'name' => $input['name'],
                'email' => $input['email'],
                'password' => Hash::make($input['password']),
                'role' => 'employee',
            ]);

            if (!$user->employee()->exists()) {
                $baseEmployeeId = 'EMP-'.str_pad((string) $user->id, 5, '0', STR_PAD_LEFT);
                $employeeId = $baseEmployeeId;
                $suffix = 1;

                while (Employee::where('employee_id', $employeeId)->exists()) {
                    $employeeId = $baseEmployeeId.'-'.$suffix++;
                }

                $user->employee()->create(['employee_id' => $employeeId]);
            }

            return $user;
        });
    }
}
