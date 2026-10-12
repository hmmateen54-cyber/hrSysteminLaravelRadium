<x-app-layout>
    <x-slot name="header"><h1>Add salary record</h1><p>Create a monthly salary record for an employee.</p></x-slot>
    <section class="page-intro"><div><div class="eyebrow">PEOPLE OPERATIONS</div><h2 class="page-title">New salary record</h2><p class="page-subtitle">Net salary is calculated automatically when saved.</p></div><a class="btn btn-secondary" href="{{ route('salaries.index') }}">Back to salaries</a></section>
    <section class="panel form-panel"><div class="panel-head"><div><h2 class="panel-title">Salary details</h2><div class="panel-caption">One salary record per employee and month.</div></div></div><div class="panel-body">@include('salaries._form')</div></section>
</x-app-layout>
