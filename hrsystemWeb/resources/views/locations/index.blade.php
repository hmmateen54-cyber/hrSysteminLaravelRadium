<x-app-layout>
    <x-slot name="header">
        <h1>Attendance locations</h1>
        <p>Server-confirmed location events captured through the employee attendance workflow.</p>
    </x-slot>

    <section class="page-intro">
        <div>
            <div class="eyebrow">ATTENDANCE CONTROLS</div>
            <h2 class="page-title">Location status</h2>
            <p class="page-subtitle">This view shows capture and server confirmation times. Precise coordinates are not displayed.</p>
        </div>
        <span class="badge badge-approved">Recorded events are server confirmed</span>
    </section>

    <section class="panel">
        @if($events->isEmpty())
            <div class="empty-state">
                <div class="empty-mark">GPS</div>
                <strong>No location events received</strong>
                <p>Employee location records will appear here after synchronization.</p>
            </div>
        @else
            <div class="table-wrap">
                <table class="data-table">
                    <thead><tr><th>Employee</th><th>Purpose</th><th>Captured at</th><th>Server confirmed</th><th>Status</th></tr></thead>
                    <tbody>
                        @foreach($events as $event)
                            <tr>
                                <td>
                                    <span class="table-primary">{{ $event->employee?->user?->name ?? 'Unknown employee' }}</span>
                                    <div class="table-secondary">{{ $event->employee?->employee_id ?? '—' }}</div>
                                </td>
                                <td>{{ $event->purpose ?: 'Attendance location check' }}</td>
                                <td>{{ $event->recorded_at?->timezone(config('app.timezone'))->format('d M Y, H:i') ?? '—' }}</td>
                                <td>{{ $event->synced_at?->timezone(config('app.timezone'))->format('d M Y, H:i') ?? '—' }}</td>
                                <td><span class="badge badge-approved">Location recorded</span></td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
            @if($events->hasPages())<div class="pagination-wrap">{{ $events->links() }}</div>@endif
        @endif
    </section>
</x-app-layout>
