<x-app-layout>
    <x-slot name="header"><h1>Edit performance review</h1><p>Update the review feedback and rating.</p></x-slot>
    <section class="page-intro"><div><div class="eyebrow">GROWTH & DEVELOPMENT</div><h2 class="page-title">Edit review</h2><p class="page-subtitle">Review for {{ $performance->employee?->user?->name ?? 'employee' }}.</p></div><a class="btn btn-secondary" href="{{ route('performances.show', $performance) }}">← Review details</a></section>
    <section class="panel form-panel"><div class="panel-head"><div><h2 class="panel-title">Review details</h2></div></div><div class="panel-body">@include('performances._form')</div></section>
</x-app-layout>
