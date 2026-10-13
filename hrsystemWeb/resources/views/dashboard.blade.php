<x-app-layout>
    <x-slot name="header">
        <h1>{{ $role === 'employee' ? 'Welcome back' : ucfirst($role).' overview' }}</h1>
        <p>{{ $role === 'employee' ? 'Here is your personal work overview.' : 'A clear view of your people operations.' }}</p>
    </x-slot>

    @if($role === 'employee')
        <section class="page-intro">
            <div><div class="eyebrow">EMPLOYEE PORTAL</div><h2 class="page-title">Good {{ now()->hour < 12 ? 'morning' : (now()->hour < 18 ? 'afternoon' : 'evening') }}, {{ str($employee?->user?->name ?? auth()->user()->name)->before(' ') }}</h2><p class="page-subtitle">Your leave, performance, and assigned work at a glance.</p></div>
            <div class="page-actions"><a class="btn btn-primary" href="{{ route('employee.leave.create') }}">＋ Request leave</a></div>
        </section>
        <div class="metric-grid">
            <div class="metric-card"><div class="metric-top"><span class="metric-label">My employee ID</span><span class="metric-icon">ID</span></div><div class="metric-value" style="font-size:21px" data-dashboard-employee-field="employee_id">{{ $employee?->employee_id ?? '—' }}</div><div class="metric-note" data-dashboard-employee-field="department">{{ $employee?->department ?? 'Profile not linked yet' }}</div></div>
            <div class="metric-card accent-amber"><div class="metric-top"><span class="metric-label">Pending leaves</span><span class="metric-icon">…</span></div><div class="metric-value" data-dashboard-metric="pendingLeaves">{{ $pendingLeaves }}</div><div class="metric-note">Waiting for a decision</div></div>
            <div class="metric-card accent-green"><div class="metric-top"><span class="metric-label">Approved leaves</span><span class="metric-icon">✓</span></div><div class="metric-value" data-dashboard-metric="approvedLeaves">{{ $approvedLeaves }}</div><div class="metric-note">Approved requests</div></div>
            <div class="metric-card accent-rose"><div class="metric-top"><span class="metric-label">Rejected leaves</span><span class="metric-icon">–</span></div><div class="metric-value" data-dashboard-metric="rejectedLeaves">{{ $rejectedLeaves }}</div><div class="metric-note">Review your request history</div></div>
            <a class="metric-card accent-green" href="{{ route('employee.tasks.index') }}"><div class="metric-top"><span class="metric-label">Open tasks</span><span class="metric-icon">TK</span></div><div class="metric-value" data-dashboard-metric="openTaskCount">{{ $openTaskCount }}</div><div class="metric-note">Of <span data-dashboard-metric="taskCount">{{ $taskCount }}</span> assigned tasks</div></a>
            <a class="metric-card" href="{{ route('employee.feedback.index') }}"><div class="metric-top"><span class="metric-label">My feedback</span><span class="metric-icon">FB</span></div><div class="metric-value" data-dashboard-metric="feedbackCount">{{ $feedbackCount }}</div><div class="metric-note">Submissions to the company</div></a>
        </div>
        <div class="content-grid">
            <section class="panel">
                <div class="panel-head"><div><h2 class="panel-title">Recent leave requests</h2><div class="panel-caption">Your latest submissions and decisions</div></div><a class="panel-link" href="{{ route('employee.leaves.index') }}">View all →</a></div>
                <div id="dashboard-recent-content">
                @if($recentLeaves->isEmpty())<div class="empty-state"><div class="empty-mark">LV</div><strong>No leave requests yet</strong><p>Your requests and their status will appear here.</p><a class="btn btn-primary btn-small" href="{{ route('employee.leave.create') }}">Create a request</a></div>
                @else
                    <div class="table-wrap"><table class="data-table"><thead><tr><th>Leave type</th><th>Dates</th><th>Submitted</th><th>Status</th><th></th></tr></thead><tbody>
                        @foreach($recentLeaves as $leave)<tr><td><span class="table-primary">{{ $leave->leave_type }}</span></td><td>{{ $leave->start_date->format('d M Y') }} – {{ $leave->end_date->format('d M Y') }}</td><td>{{ $leave->created_at->format('d M Y') }}</td><td><span class="badge badge-{{ $leave->status }}">{{ $leave->status }}</span></td><td><a class="btn-link" href="{{ route('employee.leaves.show', $leave) }}">Details</a></td></tr>@endforeach
                    </tbody></table></div>
                @endif
                            </div>
</section>
            <section class="panel employee-profile-panel">
                <div class="panel-head"><div><h2 class="panel-title">Your profile</h2><div class="panel-caption">Work details on file</div></div></div>
                <div class="panel-body">
                    <div class="detail-item"><div class="detail-label">Department</div><div class="detail-value" data-dashboard-employee-field="department">{{ $employee?->department ?: 'Not assigned' }}</div></div>
                    <div class="detail-item"><div class="detail-label">Designation</div><div class="detail-value" data-dashboard-employee-field="designation">{{ $employee?->designation ?: 'Not assigned' }}</div></div>
                    <div class="detail-item"><div class="detail-label">Performance reviews</div><div class="detail-value"><span data-dashboard-metric="performanceCount">{{ $performanceCount }}</span> records <span class="rating"> · <span data-dashboard-metric="averageRating">{{ $averageRating ? number_format((float) $averageRating, 1) : '—' }}</span>/5 average</span></div></div>
                    <a class="quick-link" href="{{ route('employee.performance.index') }}"><span>View my performance</span><span>→</span></a>
                    @unless($employee)<div class="alert alert-error" style="margin:14px 0 0">Your account is not linked to an employee profile. Please contact HR.</div>@endunless
                </div>
            </section>
        </div>
        <section class="panel dashboard-salary-panel">
            <div class="panel-head"><div><h2 class="panel-title">My Salary</h2><div class="panel-caption">Your latest salary period and payment details</div></div><a class="panel-link" href="{{ route('my-salary.index') }}">View salary history</a></div>
            <div id="dashboard-salary-content">
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
            </div>
        </section>
    @else
        <section class="page-intro">
            <div><div class="eyebrow">{{ $role === 'admin' ? 'ADMINISTRATION' : 'PEOPLE OPERATIONS' }}</div><h2 class="page-title">{{ $role === 'admin' ? 'System overview' : 'HR overview' }}</h2><p class="page-subtitle">Monitor your team and keep requests moving.</p></div>
            <div class="page-actions"><a class="btn btn-secondary" href="{{ route('leaves.index') }}">Review leave requests</a><a class="btn btn-primary" href="{{ route('employees.create') }}">＋ Add employee</a></div>
        </section>
        <div class="metric-grid metric-5">
            <div class="metric-card"><div class="metric-top"><span class="metric-label">Total employees</span><span class="metric-icon">EM</span></div><div class="metric-value" data-dashboard-metric="totalEmployees">{{ $totalEmployees }}</div><div class="metric-note">Active employee profiles</div></div>
            @if($role === 'admin')<div class="metric-card"><div class="metric-top"><span class="metric-label">Attendance records</span><span class="metric-icon">AT</span></div><div class="metric-value" data-dashboard-metric="totalAttendance">{{ $totalAttendance }}</div><div class="metric-note">All recorded attendance</div></div>@else<div class="metric-card"><div class="metric-top"><span class="metric-label">Today's attendance</span><span class="metric-icon">AT</span></div><div class="metric-value" data-dashboard-metric="todayAttendance">{{ $todayAttendance }}</div><div class="metric-note">Records for {{ today()->format('d M Y') }}</div></div>@endif
            <div class="metric-card accent-amber"><div class="metric-top"><span class="metric-label">Pending leaves</span><span class="metric-icon">…</span></div><div class="metric-value" data-dashboard-metric="pendingLeaves">{{ $pendingLeaves }}</div><div class="metric-note">Need a decision</div></div>
            <div class="metric-card accent-green"><div class="metric-top"><span class="metric-label">Approved leaves</span><span class="metric-icon">✓</span></div><div class="metric-value" data-dashboard-metric="approvedLeaves">{{ $approvedLeaves }}</div><div class="metric-note">Approved requests</div></div>
            <div class="metric-card"><div class="metric-top"><span class="metric-label">Performance reviews</span><span class="metric-icon">PR</span></div><div class="metric-value" data-dashboard-metric="performanceRecords">{{ $performanceRecords }}</div><div class="metric-note">Recorded reviews</div></div>
        </div>
        <div class="metric-grid metric-4">
            <a class="metric-card" href="{{ route('tasks.index') }}"><div class="metric-top"><span class="metric-label">Tasks</span><span class="metric-icon">TK</span></div><div class="metric-value" data-dashboard-metric="totalTasks">{{ $totalTasks }}</div><div class="metric-note">Internal work assignments</div></a>
            <a class="metric-card accent-amber" href="{{ route('tasks.index', ['assignment' => 'unassigned']) }}"><div class="metric-top"><span class="metric-label">Unassigned tasks</span><span class="metric-icon">!</span></div><div class="metric-value" data-dashboard-metric="unassignedTasks">{{ $unassignedTasks }}</div><div class="metric-note">Awaiting an employee assignment</div></a>
            <a class="metric-card accent-rose" href="{{ route('tasks.index', ['due' => 'overdue']) }}"><div class="metric-top"><span class="metric-label">Overdue tasks</span><span class="metric-icon">!</span></div><div class="metric-value" data-dashboard-metric="overdueTasks">{{ $overdueTasks }}</div><div class="metric-note">Due dates have passed</div></a>
            <a class="metric-card accent-green" href="{{ route('feedback.index', ['status' => 'new']) }}"><div class="metric-top"><span class="metric-label">New feedback</span><span class="metric-icon">FB</span></div><div class="metric-value" data-dashboard-metric="newFeedback">{{ $newFeedback }}</div><div class="metric-note">Submissions to review</div></a>
            <a class="metric-card accent-green" href="{{ route('location-events.index') }}"><div class="metric-top"><span class="metric-label">Locations recorded</span><span class="metric-icon">LC</span></div><div class="metric-value" data-dashboard-metric="locationsReceived">{{ $locationsReceived }}</div><div class="metric-note">Server-confirmed events</div></a>
        </div>
        <section class="panel">
            <div class="panel-head"><div><h2 class="panel-title">Latest leave requests</h2><div class="panel-caption">Recent employee submissions that may need attention</div></div><a class="panel-link" href="{{ route('leaves.index') }}">Manage leaves →</a></div>
            <div id="dashboard-recent-content">
                @if($recentLeaves->isEmpty())<div class="empty-state"><div class="empty-mark">LV</div><strong>Nothing to review</strong><p>New leave requests will appear here.</p></div>
            @else<div class="table-wrap"><table class="data-table"><thead><tr><th>Employee</th><th>Leave type</th><th>Dates</th><th>Submitted</th><th>Status</th><th></th></tr></thead><tbody>
                @foreach($recentLeaves as $leave)<tr><td><span class="table-primary">{{ $leave->employee?->user?->name ?? 'Unknown employee' }}</span><div class="table-secondary">{{ $leave->employee?->employee_id ?? '—' }}</div></td><td>{{ $leave->leave_type }}</td><td>{{ $leave->start_date->format('d M') }} – {{ $leave->end_date->format('d M Y') }}</td><td>{{ $leave->created_at->format('d M Y') }}</td><td><span class="badge badge-{{ $leave->status }}">{{ $leave->status }}</span></td><td><a class="btn-link" href="{{ route('leaves.show', $leave) }}">Review</a></td></tr>@endforeach
            </tbody></table></div>@endif
                        </div>
</section>
    @endif
    <div id="dashboard-live" data-url="{{ route('dashboard.snapshot') }}" data-role="{{ $role }}" hidden></div>
    <script>
        (() => {
            const live = document.getElementById('dashboard-live');
            if (!live) return;
            let inFlight = false;
            let timer = null;
            let activeController = null;

            const cell = (row, value) => {
                const item = document.createElement('td');
                item.textContent = value ?? '';
                row.appendChild(item);
            };

            const renderRecentLeaves = (items) => {
                const content = document.getElementById('dashboard-recent-content');
                if (!content) return;
                content.replaceChildren();
                const employeeView = live.dataset.role === 'employee';
                if (!Array.isArray(items) || items.length === 0) {
                    const empty = document.createElement('div');
                    empty.className = 'empty-state';
                    const mark = document.createElement('div');
                    mark.className = 'empty-mark';
                    mark.textContent = 'LV';
                    const title = document.createElement('strong');
                    title.textContent = employeeView ? 'No leave requests yet' : 'Nothing to review';
                    const description = document.createElement('p');
                    description.textContent = employeeView
                        ? 'Your requests and their status will appear here.'
                        : 'New leave requests will appear here.';
                    empty.append(mark, title, description);
                    if (employeeView) {
                        const request = document.createElement('a');
                        request.className = 'btn btn-primary btn-small';
                        request.href = "{{ route('employee.leave.create') }}";
                        request.textContent = 'Create a request';
                        empty.appendChild(request);
                    }
                    content.appendChild(empty);
                    return;
                }

                const wrap = document.createElement('div');
                wrap.className = 'table-wrap';
                const table = document.createElement('table');
                table.className = 'data-table';
                const head = document.createElement('thead');
                const headings = employeeView
                    ? ['Leave type', 'Dates', 'Submitted', 'Status', '']
                    : ['Employee', 'Leave type', 'Dates', 'Submitted', 'Status', ''];
                const header = document.createElement('tr');
                headings.forEach((value) => {
                    const item = document.createElement('th');
                    item.textContent = value;
                    header.appendChild(item);
                });
                head.appendChild(header);
                const body = document.createElement('tbody');

                items.forEach((leave) => {
                    const row = document.createElement('tr');
                    if (!employeeView) {
                        const employee = document.createElement('td');
                        const name = document.createElement('span');
                        name.className = 'table-primary';
                        name.textContent = leave.employee_name ?? 'Unknown employee';
                        const number = document.createElement('div');
                        number.className = 'table-secondary';
                        number.textContent = 'ID ' + (leave.employee_number ?? '—');
                        employee.append(name, number);
                        row.appendChild(employee);
                    }
                    cell(row, leave.leave_type);
                    cell(row, (leave.start_date ?? '') + ' – ' + (leave.end_date ?? ''));
                    cell(row, leave.created_at);
                    const statusCell = document.createElement('td');
                    const badge = document.createElement('span');
                    badge.className = 'badge badge-' + (leave.status ?? 'pending');
                    badge.textContent = leave.status ?? 'pending';
                    statusCell.appendChild(badge);
                    row.appendChild(statusCell);
                    const actionCell = document.createElement('td');
                    const link = document.createElement('a');
                    link.className = 'btn-link';
                    link.href = leave.url;
                    link.textContent = employeeView ? 'Details' : 'Review';
                    actionCell.appendChild(link);
                    row.appendChild(actionCell);
                    body.appendChild(row);
                });

                table.append(head, body);
                wrap.appendChild(table);
                content.appendChild(wrap);
            };

            const renderSalary = (salary) => {
                const content = document.getElementById('dashboard-salary-content');
                if (!content) return;
                content.replaceChildren();
                if (!salary) {
                    const empty = document.createElement('div');
                    empty.className = 'empty-state';
                    const title = document.createElement('strong');
                    title.textContent = 'No salary records available';
                    const description = document.createElement('p');
                    description.textContent = 'Your salary information will appear here after HR records it.';
                    const link = document.createElement('a');
                    link.className = 'btn btn-secondary btn-small';
                    link.href = "{{ route('my-salary.index') }}";
                    link.textContent = 'Open My Salary';
                    empty.append(title, description, link);
                    content.appendChild(empty);
                    return;
                }

                const body = document.createElement('div');
                body.className = 'panel-body';
                const grid = document.createElement('div');
                grid.className = 'detail-grid';
                const addDetail = (label, value, valueClass = '') => {
                    const item = document.createElement('div');
                    item.className = 'detail-item';
                    const name = document.createElement('div');
                    name.className = 'detail-label';
                    name.textContent = label;
                    const detail = document.createElement('div');
                    detail.className = 'detail-value' + (valueClass ? ' ' + valueClass : '');
                    detail.textContent = value ?? '';
                    item.append(name, detail);
                    grid.appendChild(item);
                };
                addDetail('Net salary', salary.net_salary, 'salary-net');
                addDetail('Salary period', salary.salary_month);
                addDetail('Payment status', salary.payment_status, 'badge badge-' + salary.payment_status);
                addDetail('Last updated', salary.updated_at);
                body.appendChild(grid);
                content.appendChild(body);
            };

            const refresh = async () => {
                if (inFlight || document.visibilityState !== 'visible') return;
                inFlight = true;
                const controller = new AbortController();
                activeController = controller;
                const timeout = setTimeout(() => controller.abort(), 8000);
                try {
                    const response = await fetch(live.dataset.url, {
                        headers: { 'Accept': 'application/json' },
                        credentials: 'same-origin',
                        cache: 'no-store',
                        signal: controller.signal,
                    });
                    if (!response.ok) return;
                    const snapshot = await response.json();
                    Object.entries(snapshot.metrics ?? {}).forEach(([key, value]) => {
                        document.querySelectorAll('[data-dashboard-metric="' + key + '"]').forEach((node) => {
                            node.textContent = key === 'averageRating' && value !== null
                                ? Number(value).toFixed(1)
                                : String(value ?? '0');
                        });
                    });
                    if (snapshot.employee) {
                        Object.entries(snapshot.employee).forEach(([key, value]) => {
                            document.querySelectorAll('[data-dashboard-employee-field="' + key + '"]').forEach((node) => {
                                node.textContent = value || 'Not assigned';
                            });
                        });
                    }
                    renderSalary(snapshot.salary);
                    renderRecentLeaves(snapshot.recent_leaves);
                } catch (_) {
                    // Keep the last rendered data when the server cannot be reached.
                } finally {
                    clearTimeout(timeout);
                    inFlight = false;
                    if (activeController === controller) activeController = null;
                }
            };

            const startPolling = () => {
                if (timer === null) timer = setInterval(refresh, 20000);
            };
            const stopPolling = () => {
                if (timer !== null) clearInterval(timer);
                timer = null;
                activeController?.abort();
            };

            startPolling();
            document.addEventListener('visibilitychange', () => {
                if (document.visibilityState === 'visible') {
                    startPolling();
                    refresh();
                } else {
                    stopPolling();
                }
            });
            window.addEventListener('pagehide', stopPolling);
            window.addEventListener('pageshow', () => {
                if (document.visibilityState === 'visible') {
                    startPolling();
                    refresh();
                }
            });
        })();
    </script>
</x-app-layout>
