<x-app-layout>
    <x-slot name="header"><h1>Edit leave request</h1><p>Only pending requests can be changed.</p></x-slot>
    <section class="page-intro"><div><div class="eyebrow">TIME OFF</div><h2 class="page-title">Edit request</h2><p class="page-subtitle">The request keeps its original identity and remains pending review.</p></div><span class="badge badge-pending">Pending</span></section>
    <section class="panel"><form class="panel-body form-grid" method="POST" action="{{ route('employee.leaves.update', $leave) }}">@csrf @method('PATCH')
        <label class="field"><span>Leave type</span><input name="leave_type" maxlength="255" required value="{{ old('leave_type', $leave->leave_type) }}">@error('leave_type')<small class="field-error">{{ $message }}</small>@enderror</label>
        <label class="field"><span>Start date</span><input type="date" name="start_date" required value="{{ old('start_date', $leave->start_date->format('Y-m-d')) }}">@error('start_date')<small class="field-error">{{ $message }}</small>@enderror</label>
        <label class="field"><span>End date</span><input type="date" name="end_date" required value="{{ old('end_date', $leave->end_date->format('Y-m-d')) }}">@error('end_date')<small class="field-error">{{ $message }}</small>@enderror</label>
        <label class="field field-span-2"><span>Reason</span><textarea name="reason" rows="5" maxlength="5000">{{ old('reason', $leave->reason) }}</textarea>@error('reason')<small class="field-error">{{ $message }}</small>@enderror</label>
        @error('status')<div class="field-error field-span-2">{{ $message }}</div>@enderror
        <div class="field field-span-2 form-actions"><button class="btn btn-primary">Save changes</button><a class="btn btn-secondary" href="{{ route('employee.leaves.show', $leave) }}">Cancel</a></div>
    </form></section>
</x-app-layout>
