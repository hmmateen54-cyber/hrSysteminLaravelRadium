<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\Leave;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class EmployeeLeaveEditingTest extends TestCase
{
    use RefreshDatabase;

    public function test_employee_can_edit_their_own_pending_leave_on_web_and_api(): void
    {
        [$user, $employee] = $this->employee('leave-owner@example.test', 'EMP-701');
        $leave = $this->leave($employee);

        $this->actingAs($user)
            ->get(route('employee.leaves.edit', $leave))
            ->assertOk()
            ->assertSee('Edit request');

        $this->patch(route('employee.leaves.update', $leave), $this->updatedPayload())
            ->assertRedirect(route('employee.leaves.show', $leave));

        $this->assertSame('2026-11-12', $leave->fresh()->start_date->toDateString());
        $this->assertSame('2026-11-14', $leave->fresh()->end_date->toDateString());
        $this->assertSame('Annual', $leave->fresh()->leave_type);
        $this->assertSame('pending', $leave->fresh()->status);

        $token = $user->createToken('leave-edit-test')->plainTextToken;
        $this->withToken($token)
            ->patchJson("/api/employee/leaves/{$leave->id}", [
                ...$this->updatedPayload(),
                'start_date' => '2026-11-15',
                'end_date' => '2026-11-16',
            ])
            ->assertOk()
            ->assertJsonPath('leave.id', $leave->id);

        $this->assertSame('2026-11-15', $leave->fresh()->start_date->toDateString());
    }

    public function test_employee_cannot_edit_another_employees_leave(): void
    {
        [$owner, $ownerEmployee] = $this->employee('owner@example.test', 'EMP-702');
        [, $otherEmployee] = $this->employee('other@example.test', 'EMP-703');
        $leave = $this->leave($otherEmployee);
        $token = $owner->createToken('leave-edit-test')->plainTextToken;

        $this->withToken($token)
            ->patchJson("/api/employee/leaves/{$leave->id}", $this->updatedPayload())
            ->assertNotFound();

        $this->actingAs($owner)
            ->patch(route('employee.leaves.update', $leave), $this->updatedPayload())
            ->assertNotFound();

        $this->assertNotSame($ownerEmployee->id, $leave->employee_id);
        $this->assertSame('pending', $leave->fresh()->status);
    }

    public function test_approved_and_rejected_leave_requests_are_read_only(): void
    {
        [$user, $employee] = $this->employee('decided@example.test', 'EMP-704');
        $approved = $this->leave($employee, 'approved');
        $rejected = $this->leave($employee, 'rejected');
        $token = $user->createToken('leave-edit-test')->plainTextToken;

        foreach ([$approved, $rejected] as $leave) {
            $this->withToken($token)
                ->patchJson("/api/employee/leaves/{$leave->id}", $this->updatedPayload())
                ->assertStatus(409);

            $this->actingAs($user)
                ->get(route('employee.leaves.edit', $leave))
                ->assertStatus(409);
        }

        $this->assertSame('approved', $approved->fresh()->status);
        $this->assertSame('rejected', $rejected->fresh()->status);
    }

    public function test_invalid_dates_are_rejected_without_changing_the_pending_request(): void
    {
        [$user, $employee] = $this->employee('invalid-dates@example.test', 'EMP-705');
        $leave = $this->leave($employee);
        $token = $user->createToken('leave-edit-test')->plainTextToken;

        $this->withToken($token)
            ->patchJson("/api/employee/leaves/{$leave->id}", [
                ...$this->updatedPayload(),
                'start_date' => '2026-11-20',
                'end_date' => '2026-11-19',
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('end_date');

        $this->assertSame('2026-11-10', $leave->fresh()->start_date->toDateString());
    }

    public function test_hr_review_blocks_a_later_employee_edit(): void
    {
        [$user, $employee] = $this->employee('reviewed@example.test', 'EMP-706');
        $leave = $this->leave($employee);
        $hr = User::factory()->create(['role' => 'hr']);
        $hrToken = $hr->createToken('leave-review-test')->plainTextToken;
        $employeeToken = $user->createToken('leave-edit-test')->plainTextToken;

        $this->withToken($hrToken)
            ->patchJson("/api/hr/leaves/{$leave->id}/status", ['status' => 'approved'])
            ->assertOk();

        $this->app['auth']->forgetGuards();
        $this->withToken($employeeToken)
            ->patchJson("/api/employee/leaves/{$leave->id}", $this->updatedPayload())
            ->assertStatus(409);

        $this->assertSame('approved', $leave->fresh()->status);
    }

    private function employee(string $email, string $employeeId): array
    {
        $user = User::factory()->create(['email' => $email, 'role' => 'employee']);
        $employee = Employee::create([
            'user_id' => $user->id,
            'employee_id' => $employeeId,
        ]);
        return [$user, $employee];
    }

    private function leave(Employee $employee, string $status = 'pending'): Leave
    {
        return $employee->leaves()->create([
            'start_date' => '2026-11-10',
            'end_date' => '2026-11-11',
            'leave_type' => 'Casual',
            'reason' => 'Initial reason',
            'status' => $status,
        ]);
    }

    private function updatedPayload(): array
    {
        return [
            'start_date' => '2026-11-12',
            'end_date' => '2026-11-14',
            'leave_type' => 'Annual',
            'reason' => 'Updated dates',
        ];
    }
}
