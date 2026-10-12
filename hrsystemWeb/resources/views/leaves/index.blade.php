<x-app-layout>
    <x-slot name="header"><h1>Leave management</h1><p>Review and respond to employee leave requests.</p></x-slot>
    <section class="page-intro"><div><div class="eyebrow">TIME OFF</div><h2 class="page-title">Leave management</h2><p class="page-subtitle">See every request, its dates and decision history.</p></div><span class="badge badge-pending">{{ $leaves->total() }} requests</span></section>
    <section class="panel">
        <div class="panel-head"><div><h2 class="panel-title">All leave requests</h2><div class="panel-caption">Add an optional remark when approving or rejecting a request.</div></div></div>
        @if($leaves->isEmpty())<div class="empty-state"><div class="empty-mark">LV</div><strong>No leave requests found</strong><p>Employee requests will appear here when submitted.</p></div>
        @else
            <div class="table-wrap"><table class="data-table"><thead><tr><th>Employee</th><th>Type</th><th>Start date</th><th>End date</th><th>Reason</th><th>Status</th><th>HR remarks</th><th>Actions</th></tr></thead><tbody>
                @foreach($leaves as $leave)<tr>
                    <td><span class="table-primary">{{ $leave->employee?->user?->name ?? 'Unknown employee' }}</span><div class="table-secondary">ID {{ $leave->employee?->employee_id ?? '—' }}</div></td>
                    <td>{{ $leave->leave_type }}</td><td>{{ $leave->start_date->format('d M Y') }}</td><td>{{ $leave->end_date->format('d M Y') }}</td>
                    <td class="cell-wrap">{{ $leave->reason ?: '—' }}</td><td><span class="badge badge-{{ $leave->status }}">{{ $leave->status }}</span></td><td class="cell-wrap">{{ $leave->admin_remarks ?: '—' }}</td>
                    <td><div class="table-actions"><a class="btn btn-secondary btn-small" href="{{ route('leaves.show', $leave) }}">View</a>
                        @if($leave->status === 'pending')<form class="inline-review" action="{{ route('leaves.update', $leave) }}" method="POST">@csrf @method('PATCH')<input type="text" name="admin_remarks" aria-label="Optional HR remark" placeholder="Optional remark"><div class="inline-review-actions"><button class="btn btn-success btn-small" name="status" value="approved" type="submit">Approve</button><button class="btn btn-danger btn-small" name="status" value="rejected" type="submit">Reject</button></div></form>@endif
                    </div></td>
                </tr>@endforeach
            </tbody></table></div>
            @if($leaves->hasPages())<div class="pagination-wrap">{{ $leaves->links() }}</div>@endif
        @endif
    </section>
</x-app-layout>
