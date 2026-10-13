<x-app-layout>
    <x-slot name="header"><h1>Add employee</h1><p>Create an employee account and profile.</p></x-slot>
    <section class="page-intro"><div><div class="eyebrow">PEOPLE DIRECTORY</div><h2 class="page-title">Add employee</h2><p class="page-subtitle">A sign-in account and linked employee profile will be created together.</p></div><a class="btn btn-secondary" href="{{ route('employees.index') }}">← Back to employees</a></section>
    <section class="panel form-panel"><div class="panel-head"><div><h2 class="panel-title">Employee information</h2><div class="panel-caption">Employee ID, phone, department, designation, and joining date are required for account activation. Salary is optional.</div></div></div><div class="panel-body">
        <form action="{{ route('employees.store') }}" method="POST">@csrf
            <div class="form-grid">
                <div class="field"><label for="name">Full name</label><input id="name" name="name" value="{{ old('name') }}" autocomplete="name" required>@error('name')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="email">Work email</label><input id="email" type="email" name="email" value="{{ old('email') }}" autocomplete="email" required>@error('email')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="password">Initial password</label><input id="password" type="password" name="password" autocomplete="new-password" required>@error('password')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="employee_id">Employee ID</label><input id="employee_id" name="employee_id" value="{{ old('employee_id') }}" required>@error('employee_id')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="phone">Phone <span class="optional">· optional</span></label><input id="phone" name="phone" value="{{ old('phone') }}">@error('phone')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="department">Department <span class="optional">· optional</span></label><input id="department" name="department" value="{{ old('department') }}">@error('department')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="designation">Designation <span class="optional">· optional</span></label><input id="designation" name="designation" value="{{ old('designation') }}">@error('designation')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="joining_date">Joining date <span class="optional">· optional</span></label><input id="joining_date" type="date" name="joining_date" value="{{ old('joining_date') }}">@error('joining_date')<p class="field-error">{{ $message }}</p>@enderror</div>
                <div class="field"><label for="salary">Salary <span class="optional">· optional</span></label><input id="salary" type="number" name="salary" min="0" step="0.01" value="{{ old('salary') }}">@error('salary')<p class="field-error">{{ $message }}</p>@enderror</div>
            </div>
            <div class="form-actions"><a class="btn btn-secondary" href="{{ route('employees.index') }}">Cancel</a><button class="btn btn-primary" type="submit">Create employee</button></div>
        </form>
    </div></section>
</x-app-layout>
