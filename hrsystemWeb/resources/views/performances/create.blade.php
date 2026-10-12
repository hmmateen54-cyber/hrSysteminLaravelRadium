<x-app-layout>
    <x-slot name="header"><h1>New performance review</h1><p>Record feedback for an employee.</p></x-slot>
    <section class="page-intro"><div><div class="eyebrow">GROWTH & DEVELOPMENT</div><h2 class="page-title">Create a review</h2><p class="page-subtitle">Choose an employee, set a rating and add feedback.</p></div><a class="btn btn-secondary" href="{{ route('performances.index') }}">← Reviews</a></section>
    <section class="panel form-panel"><div class="panel-head"><div><h2 class="panel-title">Review details</h2><div class="panel-caption">Employees can view these records but cannot change them.</div></div></div><div class="panel-body">@include('performances._form')</div></section>
</x-app-layout>
