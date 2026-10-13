<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\LocationEvent;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;

class LocationEventController extends Controller
{
    public function store(Request $request)
    {
        $validated = $request->validate([
            'client_event_id' => ['required', 'uuid'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'recorded_at' => ['required', 'date'],
            'accuracy' => ['nullable', 'numeric', 'min:0', 'max:100000'],
            'purpose' => ['nullable', 'string', 'max:120'],
        ]);

        $user = $request->user();
        $employee = $user->employee;

        if (!$employee) {
            return response()->json(['message' => 'Employee profile not found.'], 404);
        }

        $existing = LocationEvent::query()
            ->where('user_id', $user->getKey())
            ->where('client_event_id', $validated['client_event_id'])
            ->first();

        if ($existing) {
            return $this->duplicateResponse($existing, $validated);
        }

        try {
            $event = LocationEvent::create($validated + [
                'user_id' => $user->getKey(),
                'employee_id' => $employee->getKey(),
                'synced_at' => now(),
            ]);
        } catch (QueryException $exception) {
            $event = LocationEvent::query()
                ->where('user_id', $user->getKey())
                ->where('client_event_id', $validated['client_event_id'])
                ->first();

            if (!$event) {
                throw $exception;
            }

            return $this->duplicateResponse($event, $validated);
        }

        return response()->json([
            'message' => 'Location event saved.',
            'event' => [
                'id' => $event->getKey(),
                'client_event_id' => $event->client_event_id,
                'recorded_at' => $event->recorded_at,
                'synced_at' => $event->synced_at,
            ],
        ], 201);
    }

    private function duplicateResponse(LocationEvent $event, array $validated)
    {
        $samePayload = number_format((float) $event->latitude, 7, '.', '')
                === number_format((float) $validated['latitude'], 7, '.', '')
            && number_format((float) $event->longitude, 7, '.', '')
                === number_format((float) $validated['longitude'], 7, '.', '')
            && $event->recorded_at->format('Y-m-d H:i:s')
                === \Illuminate\Support\Carbon::parse($validated['recorded_at'])->format('Y-m-d H:i:s')
            && (is_null($validated['accuracy'] ?? null)
                ? is_null($event->accuracy)
                : number_format((float) $event->accuracy, 2, '.', '')
                    === number_format((float) $validated['accuracy'], 2, '.', ''))
            && $event->purpose === ($validated['purpose'] ?? null);

        if (!$samePayload) {
            return response()->json([
                'message' => 'This event ID was already used for different location data.',
            ], 409);
        }

        return response()->json([
            'message' => 'Location event already saved.',
            'event' => [
                'id' => $event->getKey(),
                'client_event_id' => $event->client_event_id,
                'recorded_at' => $event->recorded_at,
                'synced_at' => $event->synced_at,
            ],
        ]);
    }
}
