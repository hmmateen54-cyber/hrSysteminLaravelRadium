<x-app-layout>
    <x-slot name="header"><h1>Edit salary record</h1><p>Update salary components and payment status.</p></x-slot>
    <section class="page-intro"><div><div class="eyebrow">PEOPLE OPERATIONS</div><h2 class="page-title">Edit salary record</h2><p class="page-subtitle">Net salary will be recalculated when saved.</p></div><a class="btn btn-secondary" href="{{ route('salaries.show', $salary) }}">Back to details</a></section>
    <section class="panel form-panel"><div class="panel-head"><div><h2 class="panel-title">Salary details</h2></div></div><div class="panel-body">@include('salaries._form')</div></section>
</x-app-layout>
