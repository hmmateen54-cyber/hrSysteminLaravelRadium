<x-app-layout>
    <x-slot name="header"><h1>Request leave</h1><p>Send a request to your manager for review.</p></x-slot>
    <section class="page-intro"><div><div class="eyebrow">TIME OFF</div><h2 class="page-title">Request leave</h2><p class="page-subtitle">Choose your dates and give HR a little context.</p></div><a class="btn btn-secondary" href="{{ route('employee.leaves.index') }}">View all requests</a></section>

    @if(!$employee)
        <div class="alert alert-error">Your account is not linked to an employee profile. Please contact HR before submitting a request.</div>
    @else
        <div class="content-grid">
            <section class="panel form-panel">
                <div class="panel-head"><div><h2 class="panel-title">Leave details</h2><div class="panel-caption">Your request will be submitted with pending status.</div></div></div>
                <div class="panel-body">
                    <form action="{{ route('employee.leave.store') }}" method="POST">
                        @csrf
                        <div class="form-grid">
                            <div class="field"><label for="start_date">Start date</label><input id="start_date" type="date" name="start_date" value="{{ old('start_date') }}" required>@error('start_date')<p class="field-error">{{ $message }}</p>@enderror</div>
                            <div class="field"><label for="end_date">End date</label><input id="end_date" type="date" name="end_date" value="{{ old('end_date') }}" required>@error('end_date')<p class="field-error">{{ $message }}</p>@enderror</div>
                            <div class="field field-span-2"><label for="leave_type">Leave type</label><select id="leave_type" name="leave_type" required><option value="">Choose a leave type</option>@foreach(['Casual', 'Sick', 'Annual', 'Emergency', 'Unpaid'] as $type)<option value="{{ $type }}" @selected(old('leave_type') === $type)>{{ $type }} leave</option>@endforeach</select>@error('leave_type')<p class="field-error">{{ $message }}</p>@enderror</div>
                            <div class="field field-span-2"><label for="reason">Reason <span class="optional">· optional</span></label><textarea id="reason" name="reason" placeholder="Add any details that will help HR review your request">{{ old('reason') }}</textarea>@error('reason')<p class="field-error">{{ $message }}</p>@enderror</div>
                        </div>
                        <div class="form-actions"><a class="btn btn-secondary" href="{{ route('employee.dashboard') }}">Cancel</a><button class="btn btn-primary" type="submit">Submit request <span>→</span></button></div>
                    </form>
                </div>
            </section>
            <section class="panel"><div class="panel-head"><div><h2 class="panel-title">Recent requests</h2><div class="panel-caption">Latest status updates</div></div><a class="panel-link" href="{{ route('employee.leaves.index') }}">View all</a></div>
                @if($leaves->isEmpty())<div class="empty-state"><div class="empty-mark">LV</div><strong>No requests yet</strong><p>Your request history will show here.</p></div>
                @else<div class="panel-body">@foreach($leaves as $leave)<a class="quick-link" href="{{ route('employee.leaves.show', $leave) }}"><span>{{ $leave->leave_type }}<span class="table-secondary">{{ $leave->start_date->format('d M') }} – {{ $leave->end_date->format('d M Y') }}</span></span><span class="badge badge-{{ $leave->status }}">{{ $leave->status }}</span></a>@endforeach</div>@endif
            </section>
        </div>
    @endif
</x-app-layout>
