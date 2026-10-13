<?php

namespace Tests\Feature;

use App\Models\Attendance;
use App\Models\Employee;
use App\Models\Leave;
use App\Models\Performance;
use App\Models\Salary;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class EmployeeLifecycleTest extends TestCase
{
    use RefreshDatabase;

    public function test_hr_suspension_revokes_tokens_and_retains_employee_history(): void
    {
        $hr = User::factory()->create(['role' => 'hr']);
        [$employeeUser, $employee] = $this->employee('Hira Employee', 'EMP-901');
        $attendance = Attendance::create([
            'employee_id' => $employee->id,
            'attendance_date' => '2026-10-13',
            'status' => 'present',
            'check_in' => '09:00:00',
        ]);
        $leave = Leave::create([
            'employee_id' => $employee->id,
            'start_date' => '2026-11-01',
            'end_date' => '2026-11-02',
            'leave_type' => 'Annual',
            'status' => 'approved',
        ]);
        $salary = Salary::create([
            'employee_id' => $employee->id,
            'basic_salary' => '5000.00',
            'allowances' => '250.00',
            'deductions' => '0.00',
            'net_salary' => '5250.00',
            'salary_month' => '2026-10-01',
            'payment_status' => 'paid',
        ]);
        $performance = Performance::create([
            'employee_id' => $employee->id,
            'review_date' => '2026-10-01',
            'rating' => '8.5',
            'comments' => 'Review retained after suspension.',
        ]);
        $plainToken = $employeeUser->createToken('employee-mobile')->plainTextToken;
        $tokenId = explode('|', $plainToken, 2)[0];

        $this->actingAs($hr)
            ->delete(route('employees.destroy', $employee))
            ->assertRedirect(route('employees.index'))
            ->assertSessionHas('success', 'Employee account suspended. Profile and historical records have been retained.');

        $this->assertSame('suspended', $employeeUser->fresh()->account_status);
        $this->assertDatabaseHas('employees', ['id' => $employee->id, 'user_id' => $employeeUser->id]);
        $this->assertDatabaseHas('attendances', ['id' => $attendance->id]);
        $this->assertDatabaseHas('leaves', ['id' => $leave->id]);
        $this->assertDatabaseHas('salaries', ['id' => $salary->id]);
        $this->assertDatabaseHas('performances', ['id' => $performance->id]);
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $tokenId]);

        $this->app['auth']->forgetGuards();
        $this->withToken($plainToken)->getJson('/api/employee/profile')->assertUnauthorized();
        $this->postJson('/api/login', [
            'email' => $employeeUser->email,
            'password' => 'password',
        ])->assertForbidden()
            ->assertJsonPath('message', User::SUSPENDED_ACCOUNT_MESSAGE);

        $this->app['auth']->forgetGuards();
        $this->actingAs($employeeUser->fresh())
            ->get('/employee')
            ->assertRedirect(route('employee.pending-profile'));
        $this->get(route('employee.pending-profile'))
            ->assertOk()
            ->assertSee('Your employee account is suspended')
            ->assertSee(User::SUSPENDED_ACCOUNT_MESSAGE)
            ->assertDontSee('Your employee profile is pending');
    }

    public function test_hr_can_reactivate_complete_profiles_but_not_incomplete_profiles(): void
    {
        $hr = User::factory()->create(['role' => 'hr']);
        [$suspendedUser, $completeEmployee] = $this->employee('Rafi Employee', 'EMP-902', [
            'account_status' => 'suspended',
            'phone' => '+92 300 1234567',
            'department' => 'People',
            'designation' => 'Officer',
            'joining_date' => '2026-01-01',
        ]);
        [$otherUser, $incompleteEmployee] = $this->employee('Noor Employee', 'EMP-903', [
            'account_status' => 'suspended',
        ]);

        $this->actingAs($hr)->patch(route('employees.account-status', $completeEmployee), [
            'account_status' => 'active',
        ])->assertRedirect(route('employees.index'));
        $this->assertSame('active', $suspendedUser->fresh()->account_status);

        $this->patch(route('employees.account-status', $incompleteEmployee), [
            'account_status' => 'active',
        ])->assertSessionHasErrors('account_status');
        $this->assertSame('suspended', $otherUser->fresh()->account_status);
    }

    private function employee(string $name, string $employeeId, array $attributes = []): array
    {
        $accountStatus = $attributes['account_status'] ?? 'active';
        unset($attributes['account_status']);
        $user = User::factory()->create([
            'name' => $name,
            'role' => 'employee',
            'account_status' => $accountStatus,
        ]);
        $employee = Employee::create([
            'user_id' => $user->id,
            'employee_id' => $employeeId,
            ...$attributes,
        ]);

        return [$user, $employee];
    }
}
