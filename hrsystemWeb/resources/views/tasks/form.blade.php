<x-app-layout>
    <x-slot name="header"><h1>{{ $task->exists ? 'Edit task' : 'Create task' }}</h1><p>Set clear ownership, priority and due dates.</p></x-slot>
    <section class="page-intro"><div><div class="eyebrow">WORK MANAGEMENT</div><h2 class="page-title">{{ $task->exists ? 'Task details' : 'New task' }}</h2><p class="page-subtitle">Assignments retain individual progress for each employee.</p></div><a class="btn btn-secondary" href="{{ route('tasks.index') }}">Back to tasks</a></section>
    <section class="panel"><form class="panel-body form-grid task-form" method="POST" action="{{ $task->exists ? route('tasks.update', $task) : route('tasks.store') }}">
        @csrf <input type="hidden" name="employee_ids_present" value="1"> @if($task->exists)@method('PATCH')@endif
        <label class="field field-span-2"><span>Task title</span><input name="title" maxlength="180" required value="{{ old('title', $task->title) }}">@error('title')<small class="field-error">{{ $message }}</small>@enderror</label>
        <label class="field field-span-2"><span>Description</span><textarea name="description" rows="4" maxlength="10000">{{ old('description', $task->description) }}</textarea>@error('description')<small class="field-error">{{ $message }}</small>@enderror</label>
        <label class="field"><span>Project</span><select name="project_id"><option value="">No project</option>@foreach($projects as $project)<option value="{{ $project->id }}" @selected(old('project_id', $task->project_id) == $project->id)>{{ $project->name }}</option>@endforeach</select>@error('project_id')<small class="field-error">{{ $message }}</small>@enderror</label>
        <label class="field"><span>Priority</span><select name="priority" required>@foreach(['low','normal','high','urgent'] as $priority)<option value="{{ $priority }}" @selected(old('priority', $task->priority ?: 'normal') === $priority)>{{ ucfirst($priority) }}</option>@endforeach</select>@error('priority')<small class="field-error">{{ $message }}</small>@enderror</label>
        <label class="field"><span>Due date</span><input type="date" name="due_date" value="{{ old('due_date', $task->due_date?->format('Y-m-d')) }}">@error('due_date')<small class="field-error">{{ $message }}</small>@enderror</label>
        <fieldset class="field field-span-2 employee-assignment-field">
            <legend>Assign employees</legend>
            @if($employees->isEmpty())
                <p>No employees found.</p>
            @else
                <div class="employee-check-grid">
                    @foreach($employees as $employee)
                        <label class="check-row">
                            <input type="checkbox" name="employee_ids[]" value="{{ $employee->id }}" @checked(in_array($employee->id, old('employee_ids', $assignedEmployeeIds)))>
                            <span>
                                <strong>{{ $employee->user?->name ?? 'Unknown employee' }}</strong>
                                <small>ID: {{ $employee->employee_id }} · Department: {{ $employee->department ?: 'Not assigned' }}</small>
                            </span>
                        </label>
                    @endforeach
                </div>
            @endif
            @error('employee_ids')<small class="field-error">{{ $message }}</small>@enderror
        </fieldset>

        <div class="field field-span-2 form-actions"><button class="btn btn-primary">{{ $task->exists ? 'Save task' : 'Create task' }}</button><a class="btn btn-secondary" href="{{ route('tasks.index') }}">Cancel</a></div>
    </form></section>
</x-app-layout>
