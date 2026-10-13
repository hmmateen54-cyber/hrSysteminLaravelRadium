<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class EmployeeRegistrationWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_public_registration_creates_one_pending_employee_and_ignores_privileged_roles(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => 'New Employee',
            'email' => 'new.employee@example.test',
            'password' => 'long-password',
            'password_confirmation' => 'long-password',
            'role' => 'admin',
        ]);

        $response->assertCreated()
            ->assertJsonPath('account_status', 'pending')
            ->assertJsonPath('user.role', 'employee')
            ->assertJsonMissingPath('token')
            ->assertJsonMissingPath('user.password');

        $user = User::where('email', 'new.employee@example.test')->firstOrFail();

        $this->assertSame('employee', $user->role);
        $this->assertSame('pending', $user->account_status);
        $this->assertTrue(Hash::check('long-password', $user->password));
        $this->assertSame(1, Employee::where('user_id', $user->getKey())->count());
        $this->assertSame('EMP-'.str_pad((string) $user->getKey(), 5, '0', STR_PAD_LEFT), $user->employee->employee_id);
    }

    public function test_duplicate_email_is_rejected_with_field_errors(): void
    {
        User::factory()->create(['email' => 'already.used@example.test']);

        $this->postJson('/api/register', [
            'name' => 'Duplicate User',
            'email' => 'already.used@example.test',
            'password' => 'long-password',
            'password_confirmation' => 'long-password',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');

        $this->assertSame(1, User::where('email', 'already.used@example.test')->count());
    }

    public function test_jetstream_registration_also_starts_pending_and_shows_the_status_page(): void
    {
        $this->post('/register', [
            'name' => 'Web Employee',
            'email' => 'web.employee@example.test',
            'password' => 'long-password',
            'password_confirmation' => 'long-password',
        ])->assertRedirect(route('dashboard', absolute: false));

        $user = User::where('email', 'web.employee@example.test')->firstOrFail();
        $this->assertAuthenticatedAs($user);
        $this->assertSame('pending', $user->account_status);
        $this->assertSame(1, Employee::where('user_id', $user->getKey())->count());

        $this->get('/employee')->assertRedirect(route('employee.pending-profile'));
        $this->get(route('employee.pending-profile'))
            ->assertOk()
            ->assertSee('Your employee profile is pending');
    }

    public function test_pending_employee_cannot_login_or_use_protected_api_with_an_existing_token(): void
    {
        $user = User::factory()->create([
            'role' => 'employee',
            'account_status' => 'pending',
        ]);
        $employee = $user->employee()->create(['employee_id' => 'PENDING-1']);
        $token = $user->createToken('existing-mobile-token')->plainTextToken;

        $this->postJson('/api/login', [
            'email' => $user->email,
            'password' => 'password',
        ])->assertForbidden()
            ->assertJsonPath('message', 'Your account is registered, but your employee profile is awaiting HR completion. You will be able to log in once HR completes your profile.')
            ->assertJsonMissingPath('token');

        $this->withToken($token)->getJson('/api/user')->assertForbidden();
        $this->withToken($token)->getJson('/api/employee/profile')->assertForbidden();
        $this->assertSame($employee->getKey(), $user->employee()->firstOrFail()->getKey());
        $this->assertSame(1, $user->tokens()->count());
    }

    public function test_hr_keeps_incomplete_profile_pending_and_activates_complete_profile_without_salary(): void
    {
        $hr = User::factory()->create(['role' => 'hr']);
        $employeeUser = User::factory()->create([
            'role' => 'employee',
            'account_status' => 'pending',
        ]);
        $employee = $employeeUser->employee()->create(['employee_id' => 'EMP-TEST']);

        $incomplete = [
            'name' => $employeeUser->name,
            'email' => $employeeUser->email,
            'employee_id' => 'EMP-TEST',
            'phone' => '',
            'department' => '',
            'designation' => '',
            'joining_date' => '',
            'account_status' => 'active',
            'role' => 'admin',
        ];

        $this->actingAs($hr)
            ->put(route('employees.update', $employee), $incomplete)
            ->assertRedirect(route('employees.index'));

        $this->assertSame('pending', $employeeUser->fresh()->account_status);
        $this->assertSame('employee', $employeeUser->fresh()->role);

        $this->actingAs($hr)
            ->put(route('employees.update', $employee), [
                ...$incomplete,
                'phone' => '+1 555 0100',
                'department' => 'People',
                'designation' => 'Coordinator',
                'joining_date' => '2026-10-01',
                'salary' => '',
            ])
            ->assertRedirect(route('employees.index'));

        $this->assertSame('active', $employeeUser->fresh()->account_status);
        $this->assertNull($employee->fresh()->salary);
        $this->assertSame(1, Employee::where('user_id', $employeeUser->getKey())->count());
    }

    public function test_hr_and_admin_employee_lists_include_the_linked_user_name(): void
    {
        $employeeUser = User::factory()->create([
            'role' => 'employee',
            'name' => 'Real Employee Name',
        ]);
        $employee = $employeeUser->employee()->create([
            'employee_id' => 'LIST-TEST-1',
        ]);

        $hr = User::factory()->create(['role' => 'hr']);
        $this->withToken($hr->createToken('hr-list')->plainTextToken)
            ->getJson('/api/hr/employees')
            ->assertOk()
            ->assertJsonPath('employees.0.id', $employee->getKey())
            ->assertJsonPath('employees.0.user.name', 'Real Employee Name');

        $admin = User::factory()->create(['role' => 'admin']);
        $this->app['auth']->forgetGuards();
        $this->withToken($admin->createToken('admin-list')->plainTextToken)
            ->getJson('/api/admin/employees')
            ->assertOk()
            ->assertJsonPath('employees.0.id', $employee->getKey())
            ->assertJsonPath('employees.0.user.name', 'Real Employee Name');
    }

    public function test_existing_employee_hr_and_admin_accounts_remain_active_and_can_login(): void
    {
        foreach (['employee', 'hr', 'admin'] as $role) {
            $user = User::factory()->create(['role' => $role]);

            $this->assertSame('active', $user->fresh()->account_status);
            $this->postJson('/api/login', [
                'email' => $user->email,
                'password' => 'password',
            ])->assertOk()
                ->assertJsonPath('user.role', $role)
                ->assertJsonStructure(['token']);
        }
    }

    public function test_web_role_access_and_pending_profile_redirects_are_enforced(): void
    {
        $admin = User::factory()->create(['role' => 'admin', 'account_status' => 'active']);
        $hr = User::factory()->create(['role' => 'hr', 'account_status' => 'active']);
        $employee = User::factory()->create(['role' => 'employee', 'account_status' => 'active']);
        $pending = User::factory()->create([
            'role' => 'employee',
            'account_status' => 'pending',
        ]);

        $this->get('/employees')->assertRedirect(route('login'));
        $this->app['auth']->forgetGuards();
        $this->actingAs($employee)->get('/admin')->assertForbidden();
        $this->app['auth']->forgetGuards();
        $this->actingAs($hr)->get('/admin')->assertForbidden();
        $this->app['auth']->forgetGuards();
        $this->actingAs($admin)->get('/employees')->assertOk();
        $this->app['auth']->forgetGuards();
        $this->actingAs($hr)->get('/employees')->assertOk();
        $this->app['auth']->forgetGuards();
        $this->actingAs($pending)->get('/employee')->assertRedirect(route('employee.pending-profile'));
        $this->app['auth']->forgetGuards();
        $this->actingAs($pending)->get(route('employee.pending-profile'))
            ->assertOk()
            ->assertSee('Your employee profile is pending');
    }

    public function test_api_role_permissions_are_preserved_for_hr_and_admin(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $hr = User::factory()->create(['role' => 'hr']);

        $this->withToken($admin->createToken('admin')->plainTextToken)
            ->getJson('/api/admin/dashboard')->assertOk();

        $this->app['auth']->forgetGuards();
        $this->withToken($admin->createToken('admin-hr-check')->plainTextToken)
            ->getJson('/api/hr/dashboard')->assertForbidden();

        $this->app['auth']->forgetGuards();
        $this->withToken($hr->createToken('hr')->plainTextToken)
            ->getJson('/api/hr/dashboard')->assertOk();

        $this->app['auth']->forgetGuards();
        $this->withToken($hr->createToken('hr-admin-check')->plainTextToken)
            ->getJson('/api/admin/dashboard')->assertForbidden();
    }

    public function test_practice_routes_with_salary_data_require_hr_or_admin_access(): void
    {
        $this->get('/query-practice')->assertRedirect(route('login'));

        $employee = User::factory()->create(['role' => 'employee']);
        $this->actingAs($employee)->get('/query-practice')->assertForbidden();

        $this->app['auth']->forgetGuards();
        $hr = User::factory()->create(['role' => 'hr']);
        $this->actingAs($hr)->get('/query-practice')->assertOk();

        $this->app['auth']->forgetGuards();
        $admin = User::factory()->create(['role' => 'admin']);
        $this->actingAs($admin)->get('/query-practice2')->assertOk();
    }
}
