<x-app-layout>
    <x-slot name="header"><h1>My leaves</h1><p>Track your time off requests and manager decisions.</p></x-slot>
    <section class="page-intro"><div><div class="eyebrow">TIME OFF</div><h2 class="page-title">My leave requests</h2><p class="page-subtitle">Your requests and their latest status.</p></div><a class="btn btn-primary" href="{{ route('employee.leave.create') }}">＋ Request leave</a></section>
    @unless($employee)<div class="alert alert-error">Your account is not linked to an employee profile. Please contact HR.</div>@endunless
    <section class="panel"><div class="panel-head"><div><h2 class="panel-title">Request history</h2><div class="panel-caption">{{ $leaves->total() }} requests</div></div></div>
        @if($leaves->isEmpty())<div class="empty-state"><div class="empty-mark">LV</div><strong>No requests yet</strong><p>When you submit a leave request, it will appear here.</p><a class="btn btn-primary btn-small" href="{{ route('employee.leave.create') }}">Request leave</a></div>
        @else<div class="table-wrap"><table class="data-table"><thead><tr><th>Leave type</th><th>Start date</th><th>End date</th><th>Reason</th><th>Status</th><th>HR remarks</th><th></th></tr></thead><tbody>
            @foreach($leaves as $leave)<tr><td><span class="table-primary">{{ $leave->leave_type }}</span><div class="table-secondary">Submitted {{ $leave->created_at->format('d M Y') }}</div></td><td>{{ $leave->start_date->format('d M Y') }}</td><td>{{ $leave->end_date->format('d M Y') }}</td><td class="cell-wrap">{{ $leave->reason ?: '—' }}</td><td><x-ui.status-badge :status="$leave->status" /></td><td class="cell-wrap">{{ $leave->admin_remarks ?: '—' }}</td><td><div class="table-actions"><a class="btn btn-secondary btn-small" href="{{ route('employee.leaves.show', $leave) }}">Details</a>@if($leave->status === 'pending')<a class="btn btn-primary btn-small" href="{{ route('employee.leaves.edit', $leave) }}">Edit</a>@endif</div></td></tr>@endforeach
        </tbody></table></div>@if($leaves->hasPages())<div class="pagination-wrap">{{ $leaves->links() }}</div>@endif @endif
    </section>
</x-app-layout>
