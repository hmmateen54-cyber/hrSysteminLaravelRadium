<x-app-layout>
    <x-slot name="header"><h1>Salary record</h1><p>Salary details for {{ $salary->employee?->user?->name ?? 'employee' }}.</p></x-slot>
    <section class="page-intro"><div><div class="eyebrow">PEOPLE OPERATIONS</div><h2 class="page-title">Salary details</h2><p class="page-subtitle">{{ $salary->salary_month->format('F Y') }}</p></div><div class="page-actions"><a class="btn btn-secondary" href="{{ route('salaries.index') }}">Back to salaries</a><a class="btn btn-primary" href="{{ route('salaries.edit', $salary) }}">Edit record</a></div></section>
    <section class="panel" style="max-width:900px"><div class="panel-head"><div><h2 class="panel-title">{{ $salary->employee?->user?->name ?? 'Employee unavailable' }}</h2><div class="panel-caption">Employee ID: {{ $salary->employee?->employee_id ?? '—' }} · Last updated {{ $salary->updated_at->format('d M Y, H:i') }}</div></div><span class="badge badge-{{ $salary->payment_status }}">{{ $salary->payment_status }}</span></div><div class="panel-body"><div class="detail-grid">
        <div class="detail-item"><div class="detail-label">Salary period</div><div class="detail-value">{{ $salary->salary_month->format('F Y') }}</div></div>
        <div class="detail-item"><div class="detail-label">Payment status</div><div class="detail-value"><span class="badge badge-{{ $salary->payment_status }}">{{ $salary->payment_status }}</span></div></div>
        <div class="detail-item"><div class="detail-label">Basic salary</div><div class="detail-value">{{ number_format((float) $salary->basic_salary, 2) }}</div></div>
        <div class="detail-item"><div class="detail-label">Allowances</div><div class="detail-value">{{ number_format((float) $salary->allowances, 2) }}</div></div>
        <div class="detail-item"><div class="detail-label">Deductions</div><div class="detail-value">{{ number_format((float) $salary->deductions, 2) }}</div></div>
        <div class="detail-item"><div class="detail-label">Net salary</div><div class="detail-value salary-net">{{ number_format((float) $salary->net_salary, 2) }}</div></div>
    </div><p class="salary-formula">Net salary is calculated as basic salary + allowances - deductions.</p></div></section>
</x-app-layout>
