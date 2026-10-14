<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\Project;
use App\Models\Task;
use App\Models\TaskAssignment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TaskFormRenderingTest extends TestCase
{
    use RefreshDatabase;

    public function test_create_form_renders_employee_data_and_preserves_old_values_and_submission(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $employees = $this->employees();
        $project = Project::create([
            'name' => 'People Operations',
            'created_by' => $admin->id,
        ]);

        $response = $this->actingAs($admin)->get(route('tasks.create'));
        $response->assertOk()
            ->assertSee('Task title')
            ->assertSee('Description')
            ->assertSee('Project')
            ->assertSee('People Operations')
            ->assertSee('Priority')
            ->assertSee('Due date')
            ->assertSee('Assign employees')
            ->assertSee('name="employee_ids_present" value="1"', false);

        $this->assertEmployeeListRendered($response->getContent(), $employees);

        $invalidResponse = $this->from(route('tasks.create'))
            ->followingRedirects()
            ->post(route('tasks.store'), [
                'title' => 'Draft onboarding plan',
                'description' => 'Draft description',
                'project_id' => $project->id,
                'priority' => 'invalid',
                'due_date' => 'not-a-date',
                'employee_ids_present' => '1',
                'employee_ids' => [$employees[0]->id, $employees[2]->id],
            ]);

        $invalidResponse->assertOk()
            ->assertSee('Draft onboarding plan')
            ->assertSee('selected priority is invalid')
            ->assertSee('due date is not a valid date')
            ->assertSee('name="employee_ids[]" value="'.$employees[0]->id.'" checked', false)
            ->assertSee('name="employee_ids[]" value="'.$employees[2]->id.'" checked', false);

        $this->actingAs($admin)->post(route('tasks.store'), [
            'title' => 'Prepare onboarding cohort',
            'description' => 'Create the onboarding schedule.',
            'project_id' => $project->id,
            'priority' => 'high',
            'due_date' => '2026-12-01',
            'employee_ids_present' => '1',
            'employee_ids' => [$employees[0]->id, $employees[2]->id],
        ])->assertRedirect();

        $task = Task::where('title', 'Prepare onboarding cohort')->firstOrFail();
        $this->assertSame($project->id, $task->project_id);
        $this->assertSame('high', $task->priority);
        $this->assertSame('2026-12-01', $task->due_date->toDateString());
        $this->assertEqualsCanonicalizing(
            [$employees[0]->id, $employees[2]->id],
            $task->assignments()->pluck('employee_id')->all(),
        );
    }

    public function test_edit_form_checks_assigned_employees_and_restores_old_selection(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        $employees = $this->employees();
        $task = Task::create([
            'created_by' => $admin->id,
            'title' => 'Review onboarding material',
            'description' => 'Check the current onboarding documents.',
            'priority' => 'urgent',
            'due_date' => '2026-11-20',
        ]);
        TaskAssignment::create([
            'task_id' => $task->id,
            'employee_id' => $employees[1]->id,
            'assigned_at' => now(),
        ]);

        $response = $this->actingAs($admin)->get(route('tasks.edit', $task));
        $response->assertOk()
            ->assertSee('value="Review onboarding material"', false)
            ->assertSee('Check the current onboarding documents.')
            ->assertSee('value="2026-11-20"', false)
            ->assertSee('value="urgent" selected', false)
            ->assertSee('name="employee_ids[]" value="'.$employees[1]->id.'" checked', false);
        $this->assertEmployeeListRendered($response->getContent(), $employees);

        $this->withSession(['_old_input' => [
            'title' => 'Restored task title',
            'employee_ids' => [$employees[3]->id],
        ]])->get(route('tasks.edit', $task))
            ->assertOk()
            ->assertSee('value="Restored task title"', false)
            ->assertSee('name="employee_ids[]" value="'.$employees[3]->id.'" checked', false)
            ->assertDontSee('name="employee_ids[]" value="'.$employees[1]->id.'" checked', false);
    }

    /** @return list<Employee> */
    private function employees(): array
    {
        return collect(range(1, 4))->map(function (int $number): Employee {
            $user = User::factory()->create([
                'name' => 'Task Employee '.$number,
                'role' => 'employee',
            ]);

            return Employee::create([
                'user_id' => $user->id,
                'employee_id' => sprintf('TASK-%03d', $number),
                'department' => 'Department '.$number,
            ]);
        })->values()->all();
    }

    /** @param list<Employee> $employees */
    private function assertEmployeeListRendered(string $html, array $employees): void
    {
        preg_match_all('/<input\b[^>]*type="checkbox"[^>]*name="employee_ids\[\]"[^>]*>/s', $html, $matches);
        $this->assertCount(4, $matches[0]);

        foreach ($employees as $employee) {
            $this->assertStringContainsString($employee->user->name, $html);
            $this->assertStringContainsString('ID: '.$employee->employee_id, $html);
            $this->assertStringContainsString('Department: '.$employee->department, $html);
            $this->assertStringContainsString('name="employee_ids[]" value="'.$employee->id.'"', $html);
        }
    }
}
