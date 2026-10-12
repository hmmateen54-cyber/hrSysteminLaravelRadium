<x-app-layout>
    <x-slot name="header"><h1>My Salary</h1><p>Your private salary history and payment details.</p></x-slot>

    <section class="page-intro"><div><div class="eyebrow">EMPLOYEE PORTAL</div><h2 class="page-title">My Salary</h2><p class="page-subtitle">Only salary records linked to your employee profile are shown here.</p></div></section>

    @unless($employee)
        <div class="alert alert-error" role="alert">Your account is not linked to an employee profile. Please contact HR.</div>
    @endunless

    <section class="panel">
        <div class="panel-head"><div><h2 class="panel-title">Salary history</h2><div class="panel-caption">{{ $salaries->total() }} monthly records</div></div></div>
        @if($salaries->isEmpty())
            <div class="empty-state"><div class="empty-mark">$</div><strong>No salary records yet</strong><p>HR will add your salary information here when it is available.</p></div>
        @else
            <div class="table-wrap"><table class="data-table"><thead><tr><th>Salary period</th><th>Basic salary</th><th>Allowances</th><th>Deductions</th><th>Net salary</th><th>Payment status</th><th>Last updated</th><th></th></tr></thead><tbody>
                @foreach($salaries as $salary)
                    <tr><td><span class="table-primary">{{ $salary->salary_month->format('F Y') }}</span></td><td>{{ number_format((float) $salary->basic_salary, 2) }}</td><td>{{ number_format((float) $salary->allowances, 2) }}</td><td>{{ number_format((float) $salary->deductions, 2) }}</td><td><span class="table-primary">{{ number_format((float) $salary->net_salary, 2) }}</span></td><td><span class="badge badge-{{ $salary->payment_status }}">{{ $salary->payment_status }}</span></td><td>{{ $salary->updated_at->format('d M Y') }}</td><td><a class="btn btn-secondary btn-small" href="{{ route('my-salary.show', $salary) }}">Details</a></td></tr>
                @endforeach
            </tbody></table></div>
            @if($salaries->hasPages())<div class="pagination-wrap">{{ $salaries->links() }}</div>@endif
        @endif
    </section>
</x-app-layout>
