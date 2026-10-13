<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\Leave;
use App\Models\LocationEvent;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MobileApiReliabilityTest extends TestCase
{
    use RefreshDatabase;

    public function test_current_sanctum_token_is_revoked_on_logout(): void
    {
        $user = User::factory()->create(['role' => 'employee']);
        $plainTextToken = $user->createToken('mobile-test')->plainTextToken;

        $this->withToken($plainTextToken)
            ->postJson('/api/logout')
            ->assertOk();

        $tokenId = explode('|', $plainTextToken, 2)[0];
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $tokenId]);
        $this->app['auth']->forgetGuards();
        $this->withToken($plainTextToken)
            ->getJson('/api/user')
            ->assertUnauthorized();
    }

    public function test_employee_profile_resolves_through_user_id_without_creating_a_record(): void
    {
        $user = User::factory()->create(['role' => 'employee']);
        $employee = Employee::create([
            'user_id' => $user->getKey(),
            'employee_id' => '121',
        ]);
        $token = $user->createToken('mobile-test')->plainTextToken;

        $this->withToken($token)
            ->getJson('/api/employee/profile')
            ->assertOk()
            ->assertJsonPath('employee.id', $employee->getKey())
            ->assertJsonPath('employee.employee_id', '121');

        $this->assertSame(1, Employee::where('user_id', $user->getKey())->count());
    }

    public function test_leave_request_is_owner_scoped_and_idempotent(): void
    {
        [$owner, $ownerEmployee] = $this->employeeAccount('employee@example.test', '121');
        [, $otherEmployee] = $this->employeeAccount('other@example.test', '122');
        $token = $owner->createToken('mobile-test')->plainTextToken;
        $syncId = 'c6a59acd-7a28-4b09-a920-3cb78e76d26d';
        $payload = [
            'start_date' => '2026-11-10',
            'end_date' => '2026-11-12',
            'leave_type' => 'Annual',
            'reason' => 'Planned leave',
            'sync_id' => $syncId,
            // Must be ignored; employee ownership comes from Sanctum.
            'employee_id' => $otherEmployee->getKey(),
            'status' => 'approved',
        ];

        $this->withToken($token)
            ->postJson('/api/employee/leaves', $payload)
            ->assertCreated()
            ->assertJsonPath('leave.employee_id', $ownerEmployee->getKey())
            ->assertJsonPath('leave.status', 'pending');

        $this->withToken($token)
            ->postJson('/api/employee/leaves', $payload)
            ->assertOk()
            ->assertJsonPath('leave.sync_id', $syncId);

        $this->assertSame(1, Leave::where('employee_id', $ownerEmployee->getKey())->count());

        $this->withToken($token)
            ->postJson('/api/employee/leaves', [
                ...$payload,
                'start_date' => '2026-11-13',
                'end_date' => '2026-11-12',
                'sync_id' => '8057fd1d-c99b-4ae9-b0af-1b5701f851c5',
            ])
            ->assertUnprocessable();
    }

    public function test_attendance_sync_is_idempotent_and_enforces_one_record_per_day(): void
    {
        [$user, $employee] = $this->employeeAccount('attendance-owner@example.test', '124');
        $token = $user->createToken('mobile-test')->plainTextToken;
        $payload = [
            'attendance_date' => '2026-10-13',
            'check_in' => '08:30:00',
            'sync_id' => '17dcdd87-f5d0-4c75-a7c5-522f615a6877',
        ];

        $this->withToken($token)
            ->postJson('/api/employee/attendance', $payload)
            ->assertCreated()
            ->assertJsonPath('attendance.employee_id', $employee->getKey());

        $this->withToken($token)
            ->postJson('/api/employee/attendance', $payload)
            ->assertOk();

        $this->withToken($token)
            ->postJson('/api/employee/attendance', [
                ...$payload,
                'sync_id' => '610ae1e0-a3e3-481c-b852-5d723814e28e',
            ])
            ->assertStatus(409);

        $this->assertSame(1, \App\Models\Attendance::where('employee_id', $employee->getKey())->count());
    }

    public function test_hr_and_admin_dashboard_counts_refresh_after_leave_review(): void
    {
        [$employeeUser, $employee] = $this->employeeAccount('leave-owner@example.test', '121');
        $leave = $employee->leaves()->create([
            'start_date' => '2026-11-10',
            'end_date' => '2026-11-11',
            'leave_type' => 'Annual',
            'status' => 'pending',
        ]);
        $hr = User::factory()->create(['role' => 'hr']);
        $admin = User::factory()->create(['role' => 'admin']);

        $this->withToken($hr->createToken('mobile-test')->plainTextToken)
            ->patchJson("/api/hr/leaves/{$leave->getKey()}/status", ['status' => 'approved'])
            ->assertOk();

        $this->withToken($hr->createToken('mobile-test')->plainTextToken)
            ->getJson('/api/hr/dashboard')
            ->assertOk()
            ->assertJsonPath('pending_leaves', 0)
            ->assertJsonPath('approved_leaves', 1)
            ->assertJsonPath('rejected_leaves', 0);

        $rejectedLeave = $employee->leaves()->create([
            'start_date' => '2026-11-15',
            'end_date' => '2026-11-16',
            'leave_type' => 'Casual',
            'status' => 'pending',
        ]);
        $this->app['auth']->forgetGuards();
        $adminToken = $admin->createToken('mobile-test')->plainTextToken;
        $this->withToken($adminToken)
            ->patchJson("/api/admin/leaves/{$rejectedLeave->getKey()}/status", ['status' => 'rejected'])
            ->assertOk();

        $this->app['auth']->forgetGuards();
        $this->withToken($adminToken)
            ->getJson('/api/admin/dashboard')
            ->assertOk()
            ->assertJsonPath('total_employees', 1)
            ->assertJsonPath('pending_leaves', 0)
            ->assertJsonPath('approved_leaves', 1)
            ->assertJsonPath('rejected_leaves', 1);

        $this->assertSame('approved', $leave->fresh()->status);
        $this->assertSame('employee', $employeeUser->fresh()->role);
    }

    public function test_location_events_validate_coordinates_and_deduplicate_by_owner(): void
    {
        [$user, $employee] = $this->employeeAccount('location-owner@example.test', '121');
        $token = $user->createToken('mobile-test')->plainTextToken;
        $payload = [
            'client_event_id' => 'a4b78a6a-a199-45c0-a3d2-762a2d764b57',
            'latitude' => 24.8607,
            'longitude' => 67.0011,
            'recorded_at' => '2026-10-09T08:00:00Z',
            'accuracy' => 8.5,
            'purpose' => 'Employee requested location check',
        ];

        $this->withToken($token)
            ->postJson('/api/employee/location-events', $payload)
            ->assertCreated()
            ->assertJsonMissingPath('event.latitude');

        $this->withToken($token)
            ->postJson('/api/employee/location-events', $payload)
            ->assertOk();

        $this->assertSame(1, LocationEvent::count());
        $this->assertSame($user->getKey(), LocationEvent::first()->user_id);
        $this->assertSame($employee->getKey(), LocationEvent::first()->employee_id);

        $this->withToken($token)
            ->postJson('/api/employee/location-events', [
                ...$payload,
                'client_event_id' => 'ae31f15f-71eb-42f9-92a7-8943ed8d6f0d',
                'latitude' => 91,
            ])
            ->assertUnprocessable();
    }

    public function test_web_dashboard_snapshot_refreshes_counts_and_scopes_employee_leaves(): void
    {
        [$owner, $ownerEmployee] = $this->employeeAccount('snapshot-owner@example.test', '121');
        [, $otherEmployee] = $this->employeeAccount('snapshot-other@example.test', '122');
        $ownerEmployee->leaves()->create([
            'start_date' => '2026-11-10',
            'end_date' => '2026-11-11',
            'leave_type' => 'Annual',
            'status' => 'approved',
        ]);
        $otherEmployee->leaves()->create([
            'start_date' => '2026-11-12',
            'end_date' => '2026-11-12',
            'leave_type' => 'Sick',
            'status' => 'pending',
        ]);
        $ownerEmployee->salaries()->create([
            'basic_salary' => 1500,
            'allowances' => 100,
            'deductions' => 0,
            'net_salary' => 1600,
            'salary_month' => '2026-10-01',
            'payment_status' => 'paid',
        ]);

        $this->actingAs($owner)
            ->getJson(route('dashboard.snapshot'))
            ->assertOk()
            ->assertJsonPath('metrics.pendingLeaves', 0)
            ->assertJsonPath('metrics.approvedLeaves', 1)
            ->assertJsonPath('salary.net_salary', '1,600.00')
            ->assertJsonPath('recent_leaves.0.status', 'approved')
            ->assertJsonMissing(['leave_type' => 'Sick']);
    }

    public function test_dashboard_page_renders_live_refresh_targets(): void
    {
        [$employeeUser] = $this->employeeAccount('dashboard-view@example.test', '123');

        $this->actingAs($employeeUser)
            ->get(route('employee.dashboard'))
            ->assertOk()
            ->assertSee('/dashboard/snapshot')
            ->assertSee('dashboard-recent-content')
            ->assertSee('data-dashboard-metric="pendingLeaves"', false);
    }

    /** @return array{User, Employee} */
    private function employeeAccount(string $email, string $employeeNumber): array
    {
        $user = User::factory()->create([
            'email' => $email,
            'role' => 'employee',
        ]);
        $employee = Employee::create([
            'user_id' => $user->getKey(),
            'employee_id' => $employeeNumber,
        ]);

        return [$user, $employee];
    }
}
