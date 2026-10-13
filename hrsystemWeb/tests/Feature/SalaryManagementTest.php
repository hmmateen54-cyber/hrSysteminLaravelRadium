<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\Salary;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SalaryManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_employee_can_only_view_their_own_salary_records(): void
    {
        [$employeeUser, $employee] = $this->employee('Amina Employee', 'EMP-301');
        [, $anotherEmployee] = $this->employee('Bilal Employee', 'EMP-302');
        $ownSalary = $this->salary($employee, '2026-08-01', 5200, 300, 100);
        $anotherSalary = $this->salary($anotherEmployee, '2026-08-01', 9000, 0, 0);

        $this->actingAs($employeeUser)
            ->get(route('employee.dashboard'))
            ->assertOk()
            ->assertSee('My Salary')
            ->assertSee('5,400.00');

        $this->actingAs($employeeUser)
            ->get(route('my-salary.index'))
            ->assertOk()
            ->assertSee('5,400.00')
            ->assertDontSee('9,000.00')
            ->assertDontSee('Bilal Employee');

        $this->get(route('my-salary.show', $ownSalary))->assertOk();
        $this->get(route('my-salary.show', $anotherSalary))->assertForbidden();
        $this->get(route('salaries.index'))->assertForbidden();
        $this->get(route('salaries.show', $anotherSalary))->assertForbidden();
        $this->post(route('salaries.store'), [])->assertForbidden();
    }

    public function test_hr_can_search_create_and_update_salary_records_with_server_calculated_net(): void
    {
        $hr = User::factory()->create(['role' => 'hr']);
        [, $employee] = $this->employee('Hana Staff', 'EMP-411');

        $data = [
            'employee_id' => $employee->id,
            'basic_salary' => '4000.00',
            'allowances' => '500.00',
            'deductions' => '250.00',
            'salary_month' => '2026-09',
            'payment_status' => 'pending',
            'net_salary' => '1.00',
        ];

        $this->actingAs($hr)->get(route('salaries.index'))->assertOk();
        $this->get(route('salaries.create'))->assertOk();
        $this->post(route('salaries.store'), $data)->assertRedirect(route('salaries.index'));

        $salary = Salary::firstOrFail();
        $this->assertSame('4250.00', $salary->net_salary);

        $this->get(route('salaries.index', ['q' => 'Hana', 'salary_month' => '2026-09']))
            ->assertOk()
            ->assertSee('Hana Staff');

        $this->put(route('salaries.update', $salary), [
            ...$data,
            'allowances' => '750.00',
            'payment_status' => 'paid',
            'net_salary' => '999999.00',
        ])->assertRedirect(route('salaries.show', $salary));

        $this->assertSame('4500.00', $salary->fresh()->net_salary);
        $this->assertSame('paid', $salary->fresh()->payment_status);
        $this->delete(route('salaries.destroy', $salary))->assertForbidden();
        $this->assertDatabaseHas('salaries', ['id' => $salary->id]);
    }

    public function test_admin_can_manage_and_delete_salary_records(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        [, $employee] = $this->employee('Mina Staff', 'EMP-501');
        $salary = $this->salary($employee, '2026-07-01', 6000, 0, 0);

        $this->actingAs($admin)
            ->get(route('salaries.show', $salary))
            ->assertOk()
            ->assertSee('Mina Staff');
        $this->get(route('salaries.edit', $salary))->assertOk();
        $this->delete(route('salaries.destroy', $salary))->assertRedirect(route('salaries.index'));

        $this->assertDatabaseMissing('salaries', ['id' => $salary->id]);
    }

    public function test_salary_inputs_are_validated_and_only_one_record_per_employee_month_is_allowed(): void
    {
        $hr = User::factory()->create(['role' => 'hr']);
        [, $employee] = $this->employee('Sara Staff', 'EMP-601');
        $payload = [
            'employee_id' => $employee->id,
            'basic_salary' => '-10',
            'allowances' => '0',
            'deductions' => '0',
            'salary_month' => '2026-13',
            'payment_status' => 'sent',
        ];

        $this->actingAs($hr)->post(route('salaries.store'), $payload)
            ->assertSessionHasErrors(['basic_salary', 'salary_month', 'payment_status']);
        $this->assertDatabaseCount('salaries', 0);

        $this->post(route('salaries.store'), [
            ...$payload,
            'basic_salary' => '100.00',
            'salary_month' => '2026-09',
            'deductions' => '101.00',
            'payment_status' => 'pending',
        ])->assertSessionHasErrors('deductions');
        $this->assertDatabaseCount('salaries', 0);

        $salary = $this->salary($employee, '2026-09-01', 3000, 0, 0);
        $this->post(route('salaries.store'), [
            ...$payload,
            'basic_salary' => '3000.00',
            'salary_month' => '2026-09',
            'payment_status' => 'pending',
        ])->assertSessionHasErrors('salary_month');
        $this->assertDatabaseCount('salaries', 1);
    }

    public function test_calculated_net_salary_must_fit_the_database_decimal_column(): void
    {
        $hr = User::factory()->create(['role' => 'hr']);
        [, $employee] = $this->employee('Raza Staff', 'EMP-701');
        $payload = [
            'employee_id' => $employee->id,
            'basic_salary' => '9999999999.99',
            'allowances' => '0.00',
            'deductions' => '0.00',
            'salary_month' => '2026-10',
            'payment_status' => 'pending',
        ];

        $this->actingAs($hr)->post(route('salaries.store'), $payload)
            ->assertRedirect(route('salaries.index'));
        $this->assertSame('9999999999.99', Salary::firstOrFail()->net_salary);

        $this->post(route('salaries.store'), [
            ...$payload,
            'allowances' => '0.01',
            'salary_month' => '2026-11',
        ])->assertSessionHasErrors('allowances');
        $this->assertDatabaseCount('salaries', 1);
    }

    private function employee(string $name, string $employeeId): array
    {
        $user = User::factory()->create(['name' => $name, 'role' => 'employee']);
        $employee = Employee::create([
            'user_id' => $user->id,
            'employee_id' => $employeeId,
        ]);

        return [$user, $employee];
    }

    private function salary(Employee $employee, string $month, int|float $basic, int|float $allowances, int|float $deductions): Salary
    {
        return Salary::create([
            'employee_id' => $employee->id,
            'basic_salary' => $basic,
            'allowances' => $allowances,
            'deductions' => $deductions,
            'net_salary' => $basic + $allowances - $deductions,
            'salary_month' => $month,
            'payment_status' => 'pending',
        ]);
    }
}
