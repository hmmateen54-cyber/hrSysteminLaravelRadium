<?php

namespace App\Http\Controllers;

use App\Models\Employee;
use App\Models\Project;
use App\Models\Task;
use App\Models\TaskAssignment;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class TaskController extends Controller
{
    public function index(Request $request)
    {
        $query = Task::query()->with(['project', 'assignments.employee.user'])->latest();
        if ($request->filled('employee')) {
            $query->whereHas('assignments', fn ($q) => $q->where('employee_id', $request->integer('employee')));
        }
        if (in_array($request->query('status'), ['assigned', 'in_progress', 'completed', 'on_hold'], true)) {
            $status = $request->query('status');
            $query->whereHas('assignments', fn ($q) => $q->where('status', $status));
        }
        if (in_array($request->query('priority'), ['low', 'normal', 'high', 'urgent'], true)) {
            $query->where('priority', $request->query('priority'));
        }
        if ($request->query('due') === 'overdue') {
            $query->whereDate('due_date', '<', today())
                ->whereHas('assignments', fn ($q) => $q->where('status', '!=', 'completed'));
        }
        if ($request->query('assignment') === 'unassigned') {
            $query->doesntHave('assignments');
        }

        $tasks = $query->paginate(15)->withQueryString();
        $employees = Employee::with('user')->whereHas('user', fn ($q) => $q->where('role', 'employee'))->orderBy('employee_id')->get();

        return view('tasks.index', compact('tasks', 'employees'));
    }

    public function create()
    {
        return view('tasks.form', $this->formData(new Task));
    }

    public function store(Request $request)
    {
        [$data, $employeeIds] = $this->validatedTask($request);
        $task = DB::transaction(function () use ($request, $data, $employeeIds) {
            $task = Task::create($data + ['created_by' => $request->user()->id]);
            $this->syncAssignments($task, $employeeIds ?? []);
            return $task;
        });

        return redirect()->route('tasks.show', $task)->with('success', 'Task created and assignments saved.');
    }

    public function show(Task $task)
    {
        $task->load(['project', 'assignments.employee.user', 'creator']);
        return view('tasks.show', compact('task'));
    }

    public function edit(Task $task)
    {
        $task->load('assignments');
        return view('tasks.form', $this->formData($task));
    }

    public function update(Request $request, Task $task)
    {
        [$data, $employeeIds] = $this->validatedTask($request);
        DB::transaction(function () use ($task, $data, $employeeIds) {
            $locked = Task::query()->whereKey($task->id)->lockForUpdate()->firstOrFail();
            $locked->update($data);
            if ($employeeIds !== null) {
                $this->syncAssignments($locked, $employeeIds);
            }
        });

        return redirect()->route('tasks.show', $task)->with('success', 'Task details and assignments updated.');
    }

    public function myTasks(Request $request)
    {
        $employee = $request->user()->employee;
        abort_unless($employee, 404, 'Employee profile not found.');
        $assignments = $employee->taskAssignments()->with('task.project')->latest('assigned_at')->paginate(15);
        return view('tasks.mine', compact('assignments'));
    }

    public function myTask(TaskAssignment $assignment)
    {
        abort_unless(auth()->user()->employee?->id === $assignment->employee_id, 404);
        $assignment->load('task.project');
        return view('tasks.mine-show', compact('assignment'));
    }

    public function updateMyProgress(Request $request, TaskAssignment $assignment)
    {
        $validated = $request->validate([
            'status' => ['required', 'in:assigned,in_progress,completed,on_hold'],
            'progress_notes' => ['nullable', 'string', 'max:3000'],
        ]);
        DB::transaction(function () use ($request, $assignment, $validated) {
            $locked = TaskAssignment::query()
                ->whereKey($assignment->id)
                ->where('employee_id', $request->user()->employee?->id)
                ->lockForUpdate()
                ->firstOrFail();
            $locked->update($validated);
        });
        return back()->with('success', 'Task progress updated.');
    }

    public function apiIndex()
    {
        $request = request();
        $query = Task::with(['project:id,name', 'assignments.employee:id,employee_id'])
            ->withCount('assignments')
            ->latest();
        if (in_array($request->query('status'), ['assigned', 'in_progress', 'completed', 'on_hold'], true)) {
            $status = $request->query('status');
            $query->whereHas('assignments', fn ($builder) => $builder->where('status', $status));
        }
        if (in_array($request->query('priority'), ['low', 'normal', 'high', 'urgent'], true)) {
            $query->where('priority', $request->query('priority'));
        }
        if ($request->query('due') === 'overdue') {
            $query->whereDate('due_date', '<', today())
                ->whereHas('assignments', fn ($builder) => $builder->where('status', '!=', 'completed'));
        }
        if ($request->query('assignment') === 'unassigned') {
            $query->doesntHave('assignments');
        }
        $tasks = $query->paginate(25)->withQueryString();
        return response()->json(['tasks' => $tasks]);
    }

    public function apiOptions()
    {
        $employees = Employee::query()
            ->with('user:id,name')
            ->whereHas('user', fn ($query) => $query->where('role', 'employee'))
            ->orderBy('employee_id')
            ->get(['id', 'user_id', 'employee_id', 'department', 'designation'])
            ->map(fn (Employee $employee) => [
                'id' => $employee->id,
                'employee_id' => $employee->employee_id,
                'name' => $employee->user?->name,
                'department' => $employee->department,
                'designation' => $employee->designation,
            ]);

        $projects = Project::query()
            ->where('status', 'active')
            ->orderBy('name')
            ->get(['id', 'name']);

        return response()->json(['employees' => $employees, 'projects' => $projects]);
    }

    public function apiStore(Request $request)
    {
        [$data, $employeeIds] = $this->validatedTask($request);
        $task = DB::transaction(function () use ($request, $data, $employeeIds) {
            $task = Task::create($data + ['created_by' => $request->user()->id]);
            $this->syncAssignments($task, $employeeIds ?? []);
            return $task;
        });
        return response()->json(['task' => $task->load(['project', 'assignments.employee'])], 201);
    }

    public function apiUpdate(Request $request, Task $task)
    {
        [$data, $employeeIds] = $this->validatedTask($request);
        DB::transaction(function () use ($task, $data, $employeeIds) {
            $locked = Task::query()->whereKey($task->id)->lockForUpdate()->firstOrFail();
            $locked->update($data);
            if ($employeeIds !== null) {
                $this->syncAssignments($locked, $employeeIds);
            }
        });
        return response()->json(['task' => $task->fresh()->load(['project', 'assignments.employee'])]);
    }

    public function apiMyTasks(Request $request)
    {
        $employee = $request->user()->employee;
        if (!$employee) return response()->json(['message' => 'Employee profile not found.'], 404);
        return response()->json(['tasks' => $employee->taskAssignments()->with('task.project')->latest('assigned_at')->paginate(25)]);
    }

    public function apiMyTask(TaskAssignment $assignment)
    {
        abort_unless(auth()->user()->employee?->id === $assignment->employee_id, 404);
        return response()->json(['assignment' => $assignment->load('task.project')]);
    }

    public function apiUpdateMyProgress(Request $request, TaskAssignment $assignment)
    {
        $validated = $request->validate([
            'status' => ['required', 'in:assigned,in_progress,completed,on_hold'],
            'progress_notes' => ['nullable', 'string', 'max:3000'],
        ]);
        $updated = DB::transaction(function () use ($request, $assignment, $validated) {
            $locked = TaskAssignment::query()
                ->whereKey($assignment->id)
                ->where('employee_id', $request->user()->employee?->id)
                ->lockForUpdate()->firstOrFail();
            $locked->update($validated);
            return $locked->load('task.project');
        });
        return response()->json(['assignment' => $updated]);
    }

    private function validatedTask(Request $request): array
    {
        $data = $request->validate([
            'project_id' => ['nullable', 'integer', 'exists:projects,id'],
            'title' => ['required', 'string', 'max:180'],
            'description' => ['nullable', 'string', 'max:10000'],
            'priority' => ['required', 'in:low,normal,high,urgent'],
            'due_date' => ['nullable', 'date'],
            'employee_ids' => ['sometimes', 'array', 'max:100'],
            'employee_ids.*' => ['integer', 'distinct', 'exists:employees,id'],
            'employee_ids_present' => ['sometimes', 'boolean'],
        ]);
        $employeeIds = array_key_exists('employee_ids', $data)
            ? $data['employee_ids']
            : ($request->boolean('employee_ids_present') ? [] : null);
        unset($data['employee_ids']);
        unset($data['employee_ids_present']);
        return [$data, $employeeIds];
    }

    private function syncAssignments(Task $task, array $employeeIds): void
    {
        $current = $task->assignments()->get()->keyBy('employee_id');
        foreach ($employeeIds as $employeeId) {
            if (!$current->has($employeeId)) {
                $task->assignments()->create([
                    'employee_id' => $employeeId,
                    'status' => 'assigned',
                    'assigned_at' => now(),
                ]);
            }
        }
        $task->assignments()->whereNotIn('employee_id', $employeeIds ?: [0])->delete();
    }

    private function formData(Task $task): array
    {
        return [
            'task' => $task,
            'projects' => Project::orderBy('name')->get(),
            'employees' => Employee::with('user')->whereHas('user', fn ($q) => $q->where('role', 'employee'))->orderBy('employee_id')->get(),
            'assignedEmployeeIds' => $task->exists ? $task->assignments->pluck('employee_id')->all() : [],
        ];
    }
}
