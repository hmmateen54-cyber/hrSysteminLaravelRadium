<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Attendance;
use App\Models\Employee;
use App\Models\LocationEvent;
use App\Services\ReverseGeocodingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class AttendanceController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        if (! $request->has('action_type')) {
            return $this->storeLegacyCheckIn($request);
        }

        $validated = $request->validate([
            'action_type' => ['required', 'in:check_in,check_out'],
            'client_event_id' => ['required', 'uuid'],
            'attendance_date' => ['required', 'date_format:Y-m-d'],
            'action_date' => ['required', 'date_format:Y-m-d'],
            'action_time' => ['required', 'date_format:H:i:s'],
            'action_at' => ['required', 'date'],
            'captured_at' => ['required', 'date'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'accuracy' => ['required', 'numeric', 'min:0', 'max:100'],
        ]);

        $actionAt = Carbon::parse($validated['action_at'])->utc();
        $capturedAt = Carbon::parse($validated['captured_at'])->utc();
        if ($actionAt->isAfter(now()->addMinutes(5)) || $capturedAt->isAfter(now()->addMinutes(5))) {
            throw ValidationException::withMessages([
                'action_at' => 'The attendance timestamps cannot be in the future.',
            ]);
        }
        if ($validated['action_type'] === 'check_in'
            && $validated['action_date'] !== $validated['attendance_date']) {
            throw ValidationException::withMessages([
                'attendance_date' => 'Check-in date must match the action date.',
            ]);
        }

        $user = $request->user();
        $employee = $user->employee;
        if (! $employee) {
            return response()->json(['message' => 'Employee profile not found.'], 404);
        }

        $response = DB::transaction(function () use ($validated, $user, $employee, $actionAt, $capturedAt) {
            $employee = Employee::query()
                ->whereKey($employee->getKey())
                ->lockForUpdate()
                ->firstOrFail();

            $existingEvent = LocationEvent::query()
                ->where('user_id', $user->getKey())
                ->where('client_event_id', $validated['client_event_id'])
                ->first();
            if ($existingEvent) {
                return $this->attendanceDuplicateResponse($existingEvent, $validated, $actionAt, $capturedAt);
            }

            if ($validated['action_type'] === 'check_in') {
                $attendance = $employee->attendances()
                    ->whereDate('attendance_date', $validated['attendance_date'])
                    ->first();

                if ($attendance) {
                    return response()->json([
                        'message' => 'Attendance has already been marked for this date.',
                    ], 409);
                }

                $attendance = $employee->attendances()->create([
                    'attendance_date' => $validated['attendance_date'],
                    'check_in' => $validated['action_time'],
                    'status' => 'present',
                    'sync_id' => $validated['client_event_id'],
                ]);
            } else {
                $attendance = $employee->attendances()
                    ->whereDate('attendance_date', $validated['attendance_date'])
                    ->lockForUpdate()
                    ->first();

                if (! $attendance || ! $attendance->check_in) {
                    return response()->json([
                        'message' => 'Check in before checking out.',
                    ], 409);
                }
                if ($attendance->check_out !== null) {
                    return response()->json([
                        'message' => 'Attendance has already been checked out.',
                    ], 409);
                }

                $checkInEvent = $attendance->locationEvents()
                    ->where('event_type', 'check_in')
                    ->first();
                if ($checkInEvent && ! $actionAt->greaterThan($checkInEvent->action_at)) {
                    return response()->json([
                        'message' => 'Check-out time must be after check-in.',
                    ], 422);
                }
                if (! $checkInEvent
                    && $validated['action_date'] < $attendance->attendance_date->toDateString()) {
                    return response()->json([
                        'message' => 'Check-out date cannot be before check-in.',
                    ], 422);
                }
                if (! $checkInEvent
                    && $validated['action_date'] === $attendance->attendance_date->toDateString()
                    && $validated['action_time'] <= (string) $attendance->check_in) {
                    return response()->json([
                        'message' => 'Check-out time must be after check-in.',
                    ], 422);
                }

                $attendance->forceFill(['check_out' => $validated['action_time']])->save();
            }

            $event = LocationEvent::create([
                'user_id' => $user->getKey(),
                'employee_id' => $employee->getKey(),
                'attendance_id' => $attendance->getKey(),
                'client_event_id' => $validated['client_event_id'],
                'event_type' => $validated['action_type'],
                'latitude' => $validated['latitude'],
                'longitude' => $validated['longitude'],
                'address_status' => 'pending',
                'accuracy' => $validated['accuracy'],
                'recorded_at' => $capturedAt,
                'action_at' => $actionAt,
                'purpose' => $validated['action_type'] === 'check_in'
                    ? 'Attendance check-in'
                    : 'Attendance check-out',
                'synced_at' => now(),
            ]);

            return $this->attendanceResponse($attendance->fresh(), $event, 201);
        });

        return $this->attemptAddressResolution($response, app(ReverseGeocodingService::class));
    }

    public function resolveAddress(
        Request $request,
        string $clientEventId,
        ReverseGeocodingService $geocoder,
    ): JsonResponse {
        $event = LocationEvent::query()
            ->where('user_id', $request->user()->getKey())
            ->where('client_event_id', $clientEventId)
            ->whereNotNull('attendance_id')
            ->firstOrFail();

        if ($event->address_status === 'pending') {
            $this->resolveEventAddress($event, $geocoder);
        }

        return response()->json([
            'event' => [
                'id' => $event->getKey(),
                'client_event_id' => $event->client_event_id,
                'address' => $event->address,
                'address_status' => $event->address_status,
                'address_resolved_at' => $event->address_resolved_at,
            ],
        ]);
    }

    private function attemptAddressResolution(
        JsonResponse $response,
        ReverseGeocodingService $geocoder,
    ): JsonResponse {
        if ($response->getStatusCode() >= 300) {
            return $response;
        }

        $eventId = $response->getData(true)['event']['id'] ?? null;
        if ($eventId === null) {
            return $response;
        }

        $event = LocationEvent::query()
            ->whereKey($eventId)
            ->where('user_id', auth()->id())
            ->first();
        if (! $event || $event->address_status !== 'pending') {
            return $event?->attendance
                ? $this->attendanceResponse($event->attendance, $event, $response->getStatusCode())
                : $response;
        }

        if (! $event->attendance) {
            return $response;
        }

        $this->resolveEventAddress($event, $geocoder);

        return $this->attendanceResponse(
            $event->attendance,
            $event,
            $response->getStatusCode(),
            data_get($response->getData(true), 'message', 'Attendance event saved.'),
        );
    }

    private function resolveEventAddress(LocationEvent $event, ReverseGeocodingService $geocoder): void
    {
        $result = $geocoder->reverse((float) $event->latitude, (float) $event->longitude);
        $resolved = $result['status'] !== 'pending';

        $event->forceFill([
            'address' => $result['address'],
            'address_status' => $result['status'],
            'address_resolved_at' => $resolved ? now() : null,
        ])->save();
    }

    private function storeLegacyCheckIn(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'attendance_date' => ['required', 'date_format:Y-m-d'],
            'check_in' => ['required', 'date_format:H:i:s'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'sync_id' => ['nullable', 'uuid'],
        ]);

        $employee = $request->user()->employee;
        if (! $employee) {
            return response()->json(['message' => 'Employee profile not found.'], 404);
        }

        return DB::transaction(function () use ($employee, $validated) {
            $employee = Employee::query()
                ->whereKey($employee->getKey())
                ->lockForUpdate()
                ->firstOrFail();

            if (! empty($validated['sync_id'])) {
                $existingSync = $employee->attendances()
                    ->where('sync_id', $validated['sync_id'])
                    ->first();
                if ($existingSync) {
                    $samePayload = $existingSync->attendance_date->toDateString() === $validated['attendance_date']
                        && (string) $existingSync->check_in === $validated['check_in']
                        && $this->sameOptionalNumber($existingSync->latitude, $validated['latitude'] ?? null)
                        && $this->sameOptionalNumber($existingSync->longitude, $validated['longitude'] ?? null);

                    if (! $samePayload) {
                        return response()->json([
                            'message' => 'This sync ID was already used for different attendance details.',
                        ], 409);
                    }

                    return response()->json([
                        'message' => 'Attendance was already synced.',
                        'attendance' => $existingSync,
                        'server_confirmed_at' => $existingSync->updated_at,
                    ]);
                }
            }

            $existingDate = $employee->attendances()
                ->whereDate('attendance_date', $validated['attendance_date'])
                ->first();
            if ($existingDate) {
                return response()->json([
                    'message' => 'Attendance has already been marked for this date.',
                ], 409);
            }

            $attendance = $employee->attendances()->create([
                'attendance_date' => $validated['attendance_date'],
                'check_in' => $validated['check_in'],
                'status' => 'present',
                'latitude' => $validated['latitude'] ?? null,
                'longitude' => $validated['longitude'] ?? null,
                'sync_id' => $validated['sync_id'] ?? null,
            ]);

            return response()->json([
                'message' => 'Attendance marked successfully.',
                'attendance' => $attendance,
                'server_confirmed_at' => now(),
            ], 201);
        });
    }

    private function attendanceDuplicateResponse(
        LocationEvent $event,
        array $validated,
        Carbon $actionAt,
        Carbon $capturedAt,
    ): JsonResponse {
        $attendance = $event->attendance;
        $storedTime = $validated['action_type'] === 'check_in'
            ? $attendance?->check_in
            : $attendance?->check_out;
        $samePayload = $event->event_type === $validated['action_type']
            && $attendance?->attendance_date?->toDateString() === $validated['attendance_date']
            && (string) $storedTime === $validated['action_time']
            && $event->action_at?->format('Y-m-d H:i:s') === $actionAt->format('Y-m-d H:i:s')
            && $event->recorded_at?->format('Y-m-d H:i:s') === $capturedAt->format('Y-m-d H:i:s')
            && number_format((float) $event->latitude, 7, '.', '') === number_format((float) $validated['latitude'], 7, '.', '')
            && number_format((float) $event->longitude, 7, '.', '') === number_format((float) $validated['longitude'], 7, '.', '')
            && number_format((float) $event->accuracy, 2, '.', '') === number_format((float) $validated['accuracy'], 2, '.', '');

        if (! $samePayload || ! $attendance) {
            return response()->json([
                'message' => 'This event ID was already used for different attendance details.',
            ], 409);
        }

        return $this->attendanceResponse($attendance, $event, 200, 'Attendance event already saved.');
    }

    private function attendanceResponse(
        Attendance $attendance,
        LocationEvent $event,
        int $status,
        string $message = 'Attendance event saved.',
    ): JsonResponse {
        return response()->json([
            'message' => $message,
            'attendance' => $attendance,
            'event' => [
                'id' => $event->getKey(),
                'attendance_id' => $event->attendance_id,
                'client_event_id' => $event->client_event_id,
                'event_type' => $event->event_type,
                'latitude' => $event->latitude,
                'longitude' => $event->longitude,
                'address' => $event->address,
                'address_status' => $event->address_status,
                'address_resolved_at' => $event->address_resolved_at,
                'accuracy' => $event->accuracy,
                'captured_at' => $event->recorded_at,
                'synced_at' => $event->synced_at,
            ],
            'server_confirmed_at' => $event->synced_at,
        ], $status);
    }

    private function sameOptionalNumber(mixed $stored, mixed $submitted): bool
    {
        if ($stored === null || $submitted === null) {
            return $stored === null && $submitted === null;
        }

        return (float) $stored === (float) $submitted;
    }
}
