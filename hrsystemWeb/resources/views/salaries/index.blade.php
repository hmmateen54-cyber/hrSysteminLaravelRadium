<x-app-layout>
    <x-slot name="header"><h1>Salary management</h1><p>Review monthly pay records and payment status.</p></x-slot>

    <section class="page-intro">
        <div><div class="eyebrow">PEOPLE OPERATIONS</div><h2 class="page-title">Salary records</h2><p class="page-subtitle">{{ $salaries->total() }} records in the salary history</p></div>
        <a class="btn btn-primary" href="{{ route('salaries.create') }}">Add salary record</a>
    </section>

    <section class="panel">
        <div class="panel-head"><div><h2 class="panel-title">All salaries</h2><div class="panel-caption">Search by employee name, employee ID or email.</div></div></div>
        <form class="salary-filter-form" method="GET" action="{{ route('salaries.index') }}">
            <label class="salary-filter salary-search"><span>Employee</span><input type="search" name="q" value="{{ $filters['q'] ?? '' }}" placeholder="Name, ID or email"></label>
            <label class="salary-filter"><span>Salary month</span><input type="month" name="salary_month" value="{{ $filters['salary_month'] ?? '' }}"></label>
            <label class="salary-filter"><span>Payment status</span><select name="payment_status"><option value="">All statuses</option>@foreach(\App\Models\Salary::PAYMENT_STATUSES as $status)<option value="{{ $status }}" @selected(($filters['payment_status'] ?? '') === $status)>{{ ucfirst($status) }}</option>@endforeach</select></label>
            <div class="salary-filter-actions"><button class="btn btn-primary" type="submit">Filter</button><a class="btn btn-secondary" href="{{ route('salaries.index') }}">Clear</a></div>
        </form>

        @if($salaries->isEmpty())
            <div class="empty-state"><div class="empty-mark">$</div><strong>No salary records found</strong><p>Add a monthly salary record or adjust the search filters.</p><a class="btn btn-primary btn-small" href="{{ route('salaries.create') }}">Add salary record</a></div>
        @else
            <div class="table-wrap"><table class="data-table"><thead><tr><th>Employee</th><th>Basic</th><th>Allowances</th><th>Deductions</th><th>Net salary</th><th>Month</th><th>Status</th><th>Actions</th></tr></thead><tbody>
                @foreach($salaries as $salary)
                    <tr>
                        <td><span class="table-primary">{{ $salary->employee?->user?->name ?? 'Employee unavailable' }}</span><div class="table-secondary">{{ $salary->employee?->employee_id ?? '—' }}</div></td>
                        <td>{{ number_format((float) $salary->basic_salary, 2) }}</td><td>{{ number_format((float) $salary->allowances, 2) }}</td><td>{{ number_format((float) $salary->deductions, 2) }}</td>
                        <td><span class="table-primary">{{ number_format((float) $salary->net_salary, 2) }}</span></td><td>{{ $salary->salary_month->format('M Y') }}</td>
                        <td><span class="badge badge-{{ $salary->payment_status }}">{{ $salary->payment_status }}</span></td>
                        <td><div class="table-actions"><a class="btn btn-secondary btn-small" href="{{ route('salaries.show', $salary) }}">View</a><a class="btn btn-secondary btn-small" href="{{ route('salaries.edit', $salary) }}">Edit</a>@if(auth()->user()->role === 'admin')<form action="{{ route('salaries.destroy', $salary) }}" method="POST" onsubmit="return confirm('Delete this salary record?')">@csrf @method('DELETE')<button class="btn btn-danger btn-small" type="submit">Delete</button></form>@endif</div></td>
                    </tr>
                @endforeach
            </tbody></table></div>
            @if($salaries->hasPages())<div class="pagination-wrap">{{ $salaries->links() }}</div>@endif
        @endif
    </section>
</x-app-layout>
