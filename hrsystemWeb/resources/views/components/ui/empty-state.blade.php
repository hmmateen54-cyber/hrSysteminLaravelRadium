@props(['title', 'description' => null, 'mark' => '•'])

<div {{ $attributes->class(['empty-state']) }}>
    <div class="empty-mark" aria-hidden="true">{{ $mark }}</div>
    <strong>{{ $title }}</strong>
    @if($description)<p>{{ $description }}</p>@endif
    {{ $slot }}
</div>
