@php($editing = isset($performance))
<form action="{{ $editing ? route('performances.update', $performance) : route('performances.store') }}" method="POST">
    @csrf
    @if($editing) @method('PUT') @endif
    <div class="form-grid">
        <div class="field field-span-2"><label for="employee_id">Employee</label><select id="employee_id" name="employee_id" required><option value="">Choose an employee</option>@foreach($employees as $employee)<option value="{{ $employee->id }}" @selected(old('employee_id', $performance->employee_id ?? '') == $employee->id)>{{ $employee->employee_id }} · {{ $employee->user?->name ?? 'User unavailable' }}</option>@endforeach</select>@error('employee_id')<p class="field-error">{{ $message }}</p>@enderror</div>
        <div class="field"><label for="review_date">Review date</label><input id="review_date" type="date" name="review_date" value="{{ old('review_date', isset($performance) ? $performance->review_date?->format('Y-m-d') : today()->format('Y-m-d')) }}" required>@error('review_date')<p class="field-error">{{ $message }}</p>@enderror</div>
        <div class="field"><label for="rating">Rating <span class="optional">· 0 to 10</span></label><input id="rating" type="number" name="rating" min="0" max="10" step="0.1" value="{{ old('rating', $performance->rating ?? '') }}" required>@error('rating')<p class="field-error">{{ $message }}</p>@enderror</div>
        <div class="field field-span-2"><label for="comments">Comments <span class="optional">· optional</span></label><textarea id="comments" name="comments" placeholder="Share review feedback and development notes">{{ old('comments', $performance->comments ?? '') }}</textarea>@error('comments')<p class="field-error">{{ $message }}</p>@enderror</div>
    </div>
    <div class="form-actions"><a class="btn btn-secondary" href="{{ route('performances.index') }}">Cancel</a><button class="btn btn-primary" type="submit">{{ $editing ? 'Save changes' : 'Create review' }}</button></div>
</form>
