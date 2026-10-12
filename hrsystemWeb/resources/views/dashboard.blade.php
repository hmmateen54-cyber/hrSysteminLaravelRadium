<x-app-layout>
    <x-slot name="header">
        <h1>{{ $role === 'employee' ? 'Welcome back' : ucfirst($role).' overview' }}</h1>
        <p>{{ $role === 'employee' ? 'Here is your personal work overview.' : 'A clear view of your people operations.' }}</p>
    </x-slot>

    @if($role === 'employee')
        <section class="page-intro">
            <div><div class="eyebrow">EMPLOYEE PORTAL</div><h2 class="page-title">Good {{ now()->hour < 12 ? 'morning' : (now()->hour < 18 ? 'afternoon' : 'evening') }}, {{ str($employee?->user?->name ?? auth()->user()->name)->before(' ') }}</h2><p class="page-subtitle">Your leave and performance activity at a glance.</p></div>
            <div class="page-actions"><a class="btn btn-primary" href="{{ route('employee.leave.create') }}">＋ Request leave</a></div>
        </section>
        <div class="metric-grid">
            <div class="metric-card"><div class="metric-top"><span class="metric-label">My employee ID</span><span class="metric-icon">ID</span></div><div class="metric-value" style="font-size:21px">{{ $employee?->employee_id ?? '—' }}</div><div class="metric-note">{{ $employee?->department ?? 'Profile not linked yet' }}</div></div>
            <div class="metric-card accent-amber"><div class="metric-top"><span class="metric-label">Pending leaves</span><span class="metric-icon">…</span></div><div class="metric-value">{{ $pendingLeaves }}</div><div class="metric-note">Waiting for a decision</div></div>
            <div class="metric-card accent-green"><div class="metric-top"><span class="metric-label">Approved leaves</span><span class="metric-icon">✓</span></div><div class="metric-value">{{ $approvedLeaves }}</div><div class="metric-note">Approved requests</div></div>
            <div class="metric-card accent-rose"><div class="metric-top"><span class="metric-label">Rejected leaves</span><span class="metric-icon">–</span></div><div class="metric-value">{{ $rejectedLeaves }}</div><div class="metric-note">Review your request history</div></div>
        </div>
        <div class="content-grid">
            <section class="panel">
                <div class="panel-head"><div><h2 class="panel-title">Recent leave requests</h2><div class="panel-caption">Your latest submissions and decisions</div></div><a class="panel-link" href="{{ route('employee.leaves.index') }}">View all →</a></div>
                @if($recentLeaves->isEmpty())<div class="empty-state"><div class="empty-mark">LV</div><strong>No leave requests yet</strong><p>Your requests and their status will appear here.</p><a class="btn btn-primary btn-small" href="{{ route('employee.leave.create') }}">Create a request</a></div>
                @else
                    <div class="table-wrap"><table class="data-table"><thead><tr><th>Leave type</th><th>Dates</th><th>Submitted</th><th>Status</th><th></th></tr></thead><tbody>
                        @foreach($recentLeaves as $leave)<tr><td><span class="table-primary">{{ $leave->leave_type }}</span></td><td>{{ $leave->start_date->format('d M Y') }} – {{ $leave->end_date->format('d M Y') }}</td><td>{{ $leave->created_at->format('d M Y') }}</td><td><span class="badge badge-{{ $leave->status }}">{{ $leave->status }}</span></td><td><a class="btn-link" href="{{ route('employee.leaves.show', $leave) }}">Details</a></td></tr>@endforeach
                    </tbody></table></div>
                @endif
            </section>
            <section class="panel employee-profile-panel">
                <div class="panel-head"><div><h2 class="panel-title">Your profile</h2><div class="panel-caption">Work details on file</div></div></div>
                <div class="panel-body">
                    <div class="detail-item"><div class="detail-label">Department</div><div class="detail-value">{{ $employee?->department ?: 'Not assigned' }}</div></div>
                    <div class="detail-item"><div class="detail-label">Designation</div><div class="detail-value">{{ $employee?->designation ?: 'Not assigned' }}</div></div>
                    <div class="detail-item"><div class="detail-label">Performance reviews</div><div class="detail-value">{{ $performanceCount }} records @if($averageRating)<span class="rating"> · {{ number_format((float) $averageRating, 1) }}/5 average</span>@endif</div></div>
                    <a class="quick-link" href="{{ route('employee.performance.index') }}"><span>View my performance</span><span>→</span></a>
                    @unless($employee)<div class="alert alert-error" style="margin:14px 0 0">Your account is not linked to an employee profile. Please contact HR.</div>@endunless
                </div>
            </section>
        </div>
        <section class="panel dashboard-salary-panel">
            <div class="panel-head"><div><h2 class="panel-title">My Salary</h2><div class="panel-caption">Your latest salary period and payment details</div></div><a class="panel-link" href="{{ route('my-salary.index') }}">View salary history</a></div>
            @if($latestSalary)
                <div class="panel-body"><div class="detail-grid">
                    <div class="detail-item"><div class="detail-label">Net salary</div><div class="detail-value salary-net">{{ number_format((float) $latestSalary->net_salary, 2) }}</div></div>
                    <div class="detail-item"><div class="detail-label">Salary period</div><div class="detail-value">{{ $latestSalary->salary_month->format('F Y') }}</div></div>
                    <div class="detail-item"><div class="detail-label">Payment status</div><div class="detail-value"><span class="badge badge-{{ $latestSalary->payment_status }}">{{ $latestSalary->payment_status }}</span></div></div>
                    <div class="detail-item"><div class="detail-label">Last updated</div><div class="detail-value">{{ $latestSalary->updated_at->format('d M Y') }}</div></div>
                </div></div>
            @else
                <div class="empty-state"><div class="empty-mark">$</div><strong>No salary records available</strong><p>Your salary information will appear here after HR records it.</p><a class="btn btn-secondary btn-small" href="{{ route('my-salary.index') }}">Open My Salary</a></div>
            @endif
        </section>
    @else
        <section class="page-intro">
            <div><div class="eyebrow">{{ $role === 'admin' ? 'ADMINISTRATION' : 'PEOPLE OPERATIONS' }}</div><h2 class="page-title">{{ $role === 'admin' ? 'System overview' : 'HR overview' }}</h2><p class="page-subtitle">Monitor your team and keep requests moving.</p></div>
            <div class="page-actions"><a class="btn btn-secondary" href="{{ route('leaves.index') }}">Review leave requests</a><a class="btn btn-primary" href="{{ route('employees.create') }}">＋ Add employee</a></div>
        </section>
        <div class="metric-grid metric-5">
            <div class="metric-card"><div class="metric-top"><span class="metric-label">Total employees</span><span class="metric-icon">EM</span></div><div class="metric-value">{{ $totalEmployees }}</div><div class="metric-note">Active employee profiles</div></div>
            @if($role === 'admin')<div class="metric-card"><div class="metric-top"><span class="metric-label">Attendance records</span><span class="metric-icon">AT</span></div><div class="metric-value">{{ $totalAttendance }}</div><div class="metric-note">All recorded attendance</div></div>@else<div class="metric-card"><div class="metric-top"><span class="metric-label">Today's attendance</span><span class="metric-icon">AT</span></div><div class="metric-value">{{ $todayAttendance }}</div><div class="metric-note">Records for {{ today()->format('d M Y') }}</div></div>@endif
            <div class="metric-card accent-amber"><div class="metric-top"><span class="metric-label">Pending leaves</span><span class="metric-icon">…</span></div><div class="metric-value">{{ $pendingLeaves }}</div><div class="metric-note">Need a decision</div></div>
            <div class="metric-card accent-green"><div class="metric-top"><span class="metric-label">Approved leaves</span><span class="metric-icon">✓</span></div><div class="metric-value">{{ $approvedLeaves }}</div><div class="metric-note">Approved requests</div></div>
            <div class="metric-card"><div class="metric-top"><span class="metric-label">Performance reviews</span><span class="metric-icon">PR</span></div><div class="metric-value">{{ $performanceRecords }}</div><div class="metric-note">Recorded reviews</div></div>
        </div>
        <section class="panel">
            <div class="panel-head"><div><h2 class="panel-title">Latest leave requests</h2><div class="panel-caption">Recent employee submissions that may need attention</div></div><a class="panel-link" href="{{ route('leaves.index') }}">Manage leaves →</a></div>
            @if($recentLeaves->isEmpty())<div class="empty-state"><div class="empty-mark">LV</div><strong>Nothing to review</strong><p>New leave requests will appear here.</p></div>
            @else<div class="table-wrap"><table class="data-table"><thead><tr><th>Employee</th><th>Leave type</th><th>Dates</th><th>Submitted</th><th>Status</th><th></th></tr></thead><tbody>
                @foreach($recentLeaves as $leave)<tr><td><span class="table-primary">{{ $leave->employee?->user?->name ?? 'Unknown employee' }}</span><div class="table-secondary">{{ $leave->employee?->employee_id ?? '—' }}</div></td><td>{{ $leave->leave_type }}</td><td>{{ $leave->start_date->format('d M') }} – {{ $leave->end_date->format('d M Y') }}</td><td>{{ $leave->created_at->format('d M Y') }}</td><td><span class="badge badge-{{ $leave->status }}">{{ $leave->status }}</span></td><td><a class="btn-link" href="{{ route('leaves.show', $leave) }}">Review</a></td></tr>@endforeach
            </tbody></table></div>@endif
        </section>
    @endif
</x-app-layout>
