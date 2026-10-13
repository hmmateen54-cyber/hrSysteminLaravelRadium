@props(['status', 'label' => null])

@php
    $statusText = trim((string) $status);
    $statusKey = strtolower($statusText);
    $statusKey = preg_replace('/[^a-z0-9_-]+/', '-', $statusKey) ?: 'neutral';
    $statusLabel = $label ?? str_replace(['_', '-'], ' ', $statusText);
@endphp

<span {{ $attributes->class(['badge', 'badge-' . $statusKey]) }}>
    {{ \Illuminate\Support\Str::of($statusLabel)->replace('_', ' ')->title() }}
</span>
