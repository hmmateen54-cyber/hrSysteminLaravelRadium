<x-app-layout>
    <x-slot name="header"><h1>Salary details</h1><p>Your salary record for {{ $salary->salary_month->format('F Y') }}.</p></x-slot>
    <section class="page-intro"><div><div class="eyebrow">EMPLOYEE PORTAL</div><h2 class="page-title">Salary details</h2><p class="page-subtitle">{{ $salary->salary_month->format('F Y') }}</p></div><a class="btn btn-secondary" href="{{ route('my-salary.index') }}">Back to My Salary</a></section>
    <section class="panel" style="max-width:850px"><div class="panel-head"><div><h2 class="panel-title">Pay breakdown</h2><div class="panel-caption">Last updated {{ $salary->updated_at->format('d M Y, H:i') }}</div></div><span class="badge badge-{{ $salary->payment_status }}">{{ $salary->payment_status }}</span></div><div class="panel-body"><div class="detail-grid">
        <div class="detail-item"><div class="detail-label">Basic salary</div><div class="detail-value">{{ number_format((float) $salary->basic_salary, 2) }}</div></div>
        <div class="detail-item"><div class="detail-label">Allowances</div><div class="detail-value">{{ number_format((float) $salary->allowances, 2) }}</div></div>
        <div class="detail-item"><div class="detail-label">Deductions</div><div class="detail-value">{{ number_format((float) $salary->deductions, 2) }}</div></div>
        <div class="detail-item"><div class="detail-label">Net salary</div><div class="detail-value salary-net">{{ number_format((float) $salary->net_salary, 2) }}</div></div>
        <div class="detail-item"><div class="detail-label">Salary period</div><div class="detail-value">{{ $salary->salary_month->format('F Y') }}</div></div>
        <div class="detail-item"><div class="detail-label">Payment status</div><div class="detail-value"><span class="badge badge-{{ $salary->payment_status }}">{{ $salary->payment_status }}</span></div></div>
    </div><p class="salary-formula">Net salary is calculated as basic salary + allowances - deductions.</p></div></section>
</x-app-layout>
