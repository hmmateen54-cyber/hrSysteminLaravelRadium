<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\Feedback;
use App\Models\Project;
use App\Models\Task;
use App\Models\TaskAssignment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TaskAndFeedbackApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_employee_feedback_hides_internal_remarks_and_submission_retries_are_idempotent(): void
    {
        [$user] = $this->employee('feedback@example.test', 'EMP-801');
        Feedback::create([
            'user_id' => $user->id,
            'category' => 'workplace',
            'subject' => 'Workstation',
            'message' => 'Please add an adjustable chair.',
            'status' => 'reviewing',
            'internal_remarks' => 'HR vendor quote is confidential.',
        ]);
        $token = $user->createToken('feedback-test')->plainTextToken;

        $this->withToken($token)
            ->getJson('/api/employee/feedback')
            ->assertOk()
            ->assertJsonPath('feedback.data.0.status', 'reviewing')
            ->assertDontSee('HR vendor quote is confidential.');

        $submissionId = '2db0c65c-2fe2-4474-a606-7a5f8df8e784';
        $payload = [
            'client_submission_id' => $submissionId,
            'category' => 'benefits',
            'subject' => 'Dental cover',
            'message' => 'Could the plan include dental visits?',
            'rating' => 4,
        ];

        $this->withToken($token)
            ->postJson('/api/employee/feedback', $payload)
            ->assertCreated()
            ->assertJsonPath('feedback.status', 'new');
        $this->withToken($token)
            ->postJson('/api/employee/feedback', $payload)
            ->assertOk();
        $this->withToken($token)
            ->postJson('/api/employee/feedback', [
                ...$payload,
                'message' => 'A different submission payload.',
            ])
            ->assertStatus(409);

        $this->assertSame(2, Feedback::where('user_id', $user->id)->count());
    }

    public function test_web_feedback_retries_with_the_same_submission_id_do_not_create_duplicates(): void
    {
        [$user] = $this->employee('web-feedback@example.test', 'EMP-805');
        $payload = [
            'client_submission_id' => 'fba69696-8c2f-42b5-9495-abba1980a98c',
            'category' => 'workplace',
            'subject' => 'Quiet room',
            'message' => 'Please add a small quiet room.',
            'rating' => '',
        ];

        $this->actingAs($user)
            ->post(route('employee.feedback.store'), $payload)
            ->assertRedirect(route('employee.feedback.index'));
        $this->post(route('employee.feedback.store'), $payload)
            ->assertRedirect(route('employee.feedback.index'));
        $this->post(route('employee.feedback.store'), [
            ...$payload,
            'message' => 'Changed text with a stale submission ID.',
        ])->assertSessionHasErrors('client_submission_id');

        $this->assertSame(1, Feedback::where('user_id', $user->id)->count());
    }

    public function test_employee_task_api_only_returns_and_updates_their_assignments(): void
    {
        [$owner, $ownerEmployee] = $this->employee('task-owner@example.test', 'EMP-802');
        [, $anotherEmployee] = $this->employee('task-other@example.test', 'EMP-803');
        $admin = User::factory()->create(['role' => 'admin']);
        $task = Task::create([
            'created_by' => $admin->id,
            'title' => 'Quarterly controls review',
            'description' => 'Review assigned process controls.',
            'priority' => 'high',
            'due_date' => '2026-11-30',
        ]);
        $ownAssignment = TaskAssignment::create([
            'task_id' => $task->id,
            'employee_id' => $ownerEmployee->id,
            'assigned_at' => now(),
        ]);
        $otherAssignment = TaskAssignment::create([
            'task_id' => $task->id,
            'employee_id' => $anotherEmployee->id,
            'assigned_at' => now(),
        ]);
        $token = $owner->createToken('task-test')->plainTextToken;

        $this->withToken($token)
            ->getJson('/api/employee/tasks')
            ->assertOk()
            ->assertJsonCount(1, 'tasks.data')
            ->assertJsonPath('tasks.data.0.id', $ownAssignment->id);

        $this->withToken($token)
            ->getJson("/api/employee/tasks/{$otherAssignment->id}")
            ->assertNotFound();
        $this->withToken($token)
            ->patchJson("/api/employee/tasks/{$otherAssignment->id}/progress", [
                'status' => 'completed',
                'progress_notes' => 'Not authorized.',
            ])
            ->assertNotFound();
        $this->withToken($token)
            ->patchJson("/api/employee/tasks/{$ownAssignment->id}/progress", [
                'status' => 'in_progress',
                'progress_notes' => 'Review is underway.',
            ])
            ->assertOk()
            ->assertJsonPath('assignment.status', 'in_progress');

        $this->assertSame('assigned', $otherAssignment->fresh()->status);
    }

    public function test_hr_can_create_tasks_and_assignments_but_employees_cannot_use_management_api(): void
    {
        [$employeeUser, $employee] = $this->employee('assigned@example.test', 'EMP-804');
        $hr = User::factory()->create(['role' => 'hr']);
        $hrToken = $hr->createToken('task-management-test')->plainTextToken;

        $this->withToken($hrToken)
            ->postJson('/api/management/projects', [
                'name' => 'Controls remediation',
                'description' => 'Track remediation assignments.',
                'status' => 'active',
            ])
            ->assertCreated()
            ->assertJsonPath('project.name', 'Controls remediation');
        $project = Project::firstOrFail();
        $payload = [
            'project_id' => $project->id,
            'title' => 'Policy refresh',
            'description' => 'Review the new internal policy.',
            'priority' => 'normal',
            'due_date' => '2026-12-01',
            'employee_ids' => [$employee->id],
        ];
        $this->withToken($hrToken)
            ->postJson('/api/management/tasks', $payload)
            ->assertCreated()
            ->assertJsonPath('task.assignments.0.employee_id', $employee->id)
            ->assertJsonPath('task.project_id', $project->id);

        $this->withToken($hrToken)
            ->getJson('/api/management/task-options')
            ->assertOk()
            ->assertJsonPath('employees.0.id', $employee->id)
            ->assertJsonPath('projects.0.id', $project->id);

        $this->app['auth']->forgetGuards();
        $employeeToken = $employeeUser->createToken('task-management-test')->plainTextToken;
        $this->withToken($employeeToken)
            ->getJson('/api/management/tasks')
            ->assertForbidden();
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
}
