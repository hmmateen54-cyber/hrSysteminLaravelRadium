<x-app-layout>
    <x-slot name="header"><h1>Edit employee</h1><p>Update employee contact and profile details.</p></x-slot>
    <section class="page-intro"><div><div class="eyebrow">PEOPLE DIRECTORY</div><h2 class="page-title">Edit {{ $employee->user?->name ?? 'employee' }}</h2><p class="page-subtitle">Changes to the profile are saved with its linked account.</p></div><a class="btn btn-secondary" href="{{ route('employees.show', $employee) }}">← Employee profile</a></section>
    <section class="panel form-panel"><div class="panel-head"><div><h2 class="panel-title">Employee information</h2><div class="panel-caption">Employee ID, phone, department, designation, and joining date are required for account activation. Salary is optional.</div></div></div><div class="panel-body">
        <form action="{{ route('employees.update', $employee) }}" method="POST">@csrf @method('PUT')
            <div class="form-grid">
                <div class="field"><label for="name">Full name</label><input id="name" name="name" value="{{ old('name', $employee->user?->name) }}" required>@error('name')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="email">Work email</label><input id="email" type="email" name="email" value="{{ old('email', $employee->user?->email) }}" required>@error('email')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="employee_id">Employee ID</label><input id="employee_id" name="employee_id" value="{{ old('employee_id', $employee->employee_id) }}" required>@error('employee_id')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="phone">Phone <span class="optional">· optional</span></label><input id="phone" name="phone" value="{{ old('phone', $employee->phone) }}">@error('phone')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="department">Department</label><input id="department" name="department" value="{{ old('department', $employee->department) }}">@error('department')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="designation">Designation</label><input id="designation" name="designation" value="{{ old('designation', $employee->designation) }}">@error('designation')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="joining_date">Joining date</label><input id="joining_date" type="date" name="joining_date" value="{{ old('joining_date', $employee->joining_date?->format('Y-m-d')) }}">@error('joining_date')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="salary">Salary</label><input id="salary" type="number" min="0" step="0.01" name="salary" value="{{ old('salary', $employee->salary) }}">@error('salary')<p class="field-error">{{ $message }}</p>@enderror</div>
            </div>
            <div class="form-actions"><a class="btn btn-secondary" href="{{ route('employees.index') }}">Cancel</a><button class="btn btn-primary" type="submit">Save changes</button></div>
        </form>
    </div></section>
</x-app-layout>
