<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Models\User;
use App\Models\Employee;
use App\Models\Attendance;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\AttendanceController as ApiAttendanceController;
use App\Http\Controllers\Api\LocationEventController;
use App\Http\Controllers\Api\EmployeeLeaveController;
use App\Http\Controllers\TaskController;
use App\Http\Controllers\ProjectController;
use App\Http\Controllers\LocationEventManagementController;
use App\Http\Controllers\FeedbackController;

Route::get('/user', function (Request $request) {
    $user = $request->user();

    return response()->json([
        'id' => $user->getKey(),
        'name' => $user->name,
        'email' => $user->email,
        'role' => $user->role,
    ]);
})->middleware(['auth:sanctum', 'role:admin,hr,employee']);

Route::get('/test', function () {
    return response()->json([
        'message' => 'Laravel API is working!',
    ]);
});

Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:login');
Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:5,1');
Route::middleware('auth:sanctum')->post('/logout', [AuthController::class, 'logout']);

//Only Admin Routes

Route::middleware(['auth:sanctum', 'role:admin'])
    ->get('/admin/employees', function (Request $request) {

        $employees = Employee::with('user')
            ->orderBy('id', 'desc')
            ->get();

        return response()->json([
            'employees' => $employees,
        ]);
    });

    Route::middleware(['auth:sanctum', 'role:admin'])
    ->get('/admin/attendance', function (Request $request) {

        $attendance = Attendance::query()
            ->select(['id', 'employee_id', 'attendance_date', 'status', 'check_in', 'check_out', 'remarks', 'sync_id', 'created_at', 'updated_at'])
            ->with(['employee:id,user_id,employee_id', 'employee.user:id,name'])
            ->orderBy('attendance_date', 'desc')
            ->get();

        return response()->json([
            'attendance' => $attendance,
        ]);
    });

    Route::middleware(['auth:sanctum', 'role:admin'])
    ->get('/admin/leaves', function (Request $request) {

        $leaves = \App\Models\Leave::with('employee.user')
            ->orderBy('start_date', 'desc')
            ->get();

        return response()->json([
            'leaves' => $leaves,
        ]);
    });

    Route::middleware(['auth:sanctum', 'role:admin'])
    ->patch('/admin/leaves/{leave}/status', function (
        Request $request,
        \App\Models\Leave $leave
    ) {

        $validated = $request->validate([
            'status' => 'required|in:approved,rejected',
            'admin_remarks' => 'nullable|string|max:1000',
        ]);

        $updated = \Illuminate\Support\Facades\DB::transaction(function () use ($leave, $validated) {
            $locked = \App\Models\Leave::query()->whereKey($leave->id)->lockForUpdate()->firstOrFail();
            if ($locked->status !== 'pending') return null;
            $locked->update($validated);
            return $locked->fresh()->load('employee.user');
        });
        if (!$updated) return response()->json(['message' => 'This leave request has already been reviewed.'], 409);

        return response()->json([
            'message' => 'Leave status updated successfully',
            'leave' => $updated,
        ]);
    });

    Route::middleware(['auth:sanctum', 'role:admin'])
    ->get('/admin/performance', function (Request $request) {

        $performance = \App\Models\Performance::with('employee.user')
            ->orderBy('review_date', 'desc')
            ->get();

        return response()->json([
            'performance' => $performance,
        ]);
    });

    Route::middleware(['auth:sanctum', 'role:admin'])
    ->post('/admin/performance', function (Request $request) {

        $request->validate([
            'employee_id' => 'required|exists:employees,id',
            'review_date' => 'required|date',
            'rating' => 'required|numeric|min:0|max:10',
            'comments' => 'nullable|string',
        ]);

        $performance = \App\Models\Performance::create([
            'employee_id' => $request->employee_id,
            'review_date' => $request->review_date,
            'rating' => $request->rating,
            'comments' => $request->comments,
        ]);

        return response()->json([
            'message' => 'Performance record created successfully',
            'performance' => $performance->load('employee.user'),
        ], 201);
    });

    Route::middleware(['auth:sanctum', 'role:admin'])
    ->patch('/admin/performance/{performance}', function (
        Request $request,
        \App\Models\Performance $performance
    ) {

        $request->validate([
            'employee_id' => 'required|exists:employees,id',
            'review_date' => 'required|date',
            'rating' => 'required|numeric|min:0|max:10',
            'comments' => 'nullable|string',
        ]);

        $performance->update([
            'employee_id' => $request->employee_id,
            'review_date' => $request->review_date,
            'rating' => $request->rating,
            'comments' => $request->comments,
        ]);

        return response()->json([
            'message' => 'Performance updated successfully',
            'performance' => $performance->load('employee.user'),
        ]);
    });

Route::middleware(['auth:sanctum', 'role:admin'])
    ->delete('/admin/performance/{performance}', function (
        Request $request,
        \App\Models\Performance $performance
    ) {

        $performance->delete();

        return response()->json([
            'message' => 'Performance deleted successfully',
        ]);
    });

    //...........................................................................//

    // hr routes.................................................................//

    Route::middleware(['auth:sanctum', 'role:hr'])
    ->get('/hr/dashboard', function (Request $request) {

        return response()->json([
            'total_employees' =>
                \App\Models\Employee::count(),

            'total_attendance' =>
                \App\Models\Attendance::count(),

            'pending_leaves' =>
                \App\Models\Leave::where(
                    'status',
                    'pending'
                )->count(),

            'approved_leaves' =>
                \App\Models\Leave::where(
                    'status',
                    'approved'
                )->count(),

            'rejected_leaves' =>
                \App\Models\Leave::where(
                    'status',
                    'rejected'
                )->count(),

            'performance_records' =>
                \App\Models\Performance::count(),
            'locations_received' => \App\Models\LocationEvent::count(),

            'total_tasks' => \App\Models\Task::count(),
            'unassigned_tasks' => \App\Models\Task::doesntHave('assignments')->count(),
            'overdue_tasks' => \App\Models\Task::whereDate('due_date', '<', today())
                ->whereHas('assignments', fn ($query) => $query->where('status', '!=', 'completed'))
                ->count(),
            'new_feedback' => \App\Models\Feedback::where('status', 'new')->count(),
        ]);
    });

    Route::middleware(['auth:sanctum', 'role:hr'])
    ->get('/hr/employees', function (Request $request) {

        $employees = \App\Models\Employee::with('user')
            ->orderBy('id', 'desc')
            ->get();

        return response()->json([
            'employees' => $employees,
        ]);
    });

    Route::middleware(['auth:sanctum', 'role:hr'])
    ->get('/hr/attendance', function (Request $request) {

        $attendance = \App\Models\Attendance::query()
            ->select(['id', 'employee_id', 'attendance_date', 'status', 'check_in', 'check_out', 'remarks', 'sync_id', 'created_at', 'updated_at'])
            ->with(['employee:id,user_id,employee_id', 'employee.user:id,name'])
            ->orderBy('attendance_date', 'desc')
            ->get();

        return response()->json([
            'attendance' => $attendance,
        ]);
    });

    Route::middleware(['auth:sanctum', 'role:hr'])
    ->get('/hr/leaves', function (Request $request) {

        $leaves = \App\Models\Leave::with('employee.user')
            ->orderBy('start_date', 'desc')
            ->get();

        return response()->json([
            'leaves' => $leaves,
        ]);
    });

    Route::middleware(['auth:sanctum', 'role:hr'])
    ->patch('/hr/leaves/{leave}/status', function (
        Request $request,
        \App\Models\Leave $leave
    ) {
        $validated = $request->validate([
            'status' => 'required|in:approved,rejected',
            'admin_remarks' => 'nullable|string|max:1000',
        ]);

        $updated = \Illuminate\Support\Facades\DB::transaction(function () use ($leave, $validated) {
            $locked = \App\Models\Leave::query()->whereKey($leave->id)->lockForUpdate()->firstOrFail();
            if ($locked->status !== 'pending') return null;
            $locked->update($validated);
            return $locked->fresh()->load('employee.user');
        });
        if (!$updated) return response()->json(['message' => 'This leave request has already been reviewed.'], 409);

        return response()->json([
            'message' => 'Leave status updated successfully',
            'leave' => $updated,
        ]);
    });

    Route::middleware(['auth:sanctum', 'role:hr'])
    ->get('/hr/performance', function (Request $request) {

        $performance = \App\Models\Performance::with('employee.user')
            ->orderBy('review_date', 'desc')
            ->get();

        return response()->json([
            'performance' => $performance,
        ]);
    });

    Route::middleware(['auth:sanctum', 'role:hr'])
    ->post('/hr/performance', function (Request $request) {

        $request->validate([
            'employee_id' => 'required|exists:employees,id',
            'review_date' => 'required|date',
            'rating' => 'required|numeric|min:0|max:10',
            'comments' => 'nullable|string',
        ]);

        $performance = \App\Models\Performance::create([
            'employee_id' => $request->employee_id,
            'review_date' => $request->review_date,
            'rating' => $request->rating,
            'comments' => $request->comments,
        ]);

        return response()->json([
            'message' => 'Performance record created successfully',
            'performance' => $performance->load('employee.user'),
        ], 201);
    });


Route::middleware(['auth:sanctum', 'role:hr'])
    ->patch('/hr/performance/{performance}', function (
        Request $request,
        \App\Models\Performance $performance
    ) {
        $validated = $request->validate([
            'employee_id' => 'required|exists:employees,id',
            'review_date' => 'required|date',
            'rating' => 'required|numeric|min:0|max:10',
            'comments' => 'nullable|string',
        ]);

        $performance->update($validated);

        return response()->json([
            'message' => 'Performance record updated successfully',
            'performance' => $performance->load('employee.user'),
        ]);
    });

Route::middleware(['auth:sanctum', 'role:hr'])
    ->delete('/hr/performance/{performance}', function (
        \App\Models\Performance $performance
    ) {
        $performance->delete();

        return response()->json([
            'message' => 'Performance record deleted successfully',
        ]);
    });

    //...........................................................//


Route::middleware(['auth:sanctum', 'role:employee'])->get('/employee/profile', function (Request $request) {

    $employee = $request->user()->employee;

    if (!$employee) {
        return response()->json([
            'message' => 'Employee profile not found'
        ], 404);
    }

    return response()->json([
        'user' => $request->user(),
        'employee' => $employee,
    ]);
});


Route::middleware(['auth:sanctum', 'role:employee'])->get('/employee/attendance', function (Request $request) {

    $employee = $request->user()->employee;

    if (!$employee) {
        return response()->json([
            'message' => 'Employee profile not found'
        ], 404);
    }

    $attendance = $employee->attendances()
        ->select(['id', 'employee_id', 'attendance_date', 'status', 'check_in', 'check_out', 'remarks', 'sync_id', 'created_at', 'updated_at'])
        ->with(['locationEvents' => fn ($query) => $query->select([
            'id', 'attendance_id', 'client_event_id', 'event_type', 'recorded_at', 'action_at', 'accuracy', 'synced_at',
            'address', 'address_status', 'address_resolved_at',
        ])])
        ->orderBy('attendance_date', 'desc')
        ->get();

    return response()->json([
        'attendance' => $attendance,
    ]);
});


Route::middleware(['auth:sanctum', 'role:employee'])
    ->post('/employee/attendance', function (Request $request) {
        $employee = $request->user()->employee;

        if (!$employee) {
            return response()->json([
                'message' => 'Employee profile not found',
            ], 404);
        }

        $validated = $request->validate([
            'attendance_date' => 'required|date_format:Y-m-d',
            'check_in' => 'required|date_format:H:i:s',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'sync_id' => 'nullable|uuid',
        ]);

        return \Illuminate\Support\Facades\DB::transaction(function () use ($employee, $validated) {
            // Serialize attendance writes for this employee while checking the
            // one-per-day rule. The same employee lock is used by the web form.
            $employee = Employee::query()
                ->whereKey($employee->getKey())
                ->lockForUpdate()
                ->firstOrFail();

            // If this exact offline request was already accepted,
            // return the existing record instead of creating another.
            if (!empty($validated['sync_id'])) {
                $existingSync = $employee->attendances()
                    ->where('sync_id', $validated['sync_id'])
                    ->first();

                if ($existingSync) {
                    $samePayload =
                        $existingSync->attendance_date->toDateString()
                            === $validated['attendance_date']
                        && (string) $existingSync->check_in
                            === $validated['check_in']
                        && (
                            $existingSync->latitude === null
                                ? ($validated['latitude'] ?? null) === null
                                : (
                                    $validated['latitude'] !== null
                                    && (float) $existingSync->latitude
                                        === (float) $validated['latitude']
                                )
                        )
                        && (
                            $existingSync->longitude === null
                                ? ($validated['longitude'] ?? null) === null
                                : (
                                    $validated['longitude'] !== null
                                    && (float) $existingSync->longitude
                                        === (float) $validated['longitude']
                                )
                        );

                    if (!$samePayload) {
                        return response()->json([
                            'message' => 'This sync ID was already used for different attendance details.',
                        ], 409);
                    }

                    return response()->json([
                        'message' => 'Attendance was already synced.',
                        'attendance' => $existingSync,
                    ], 200);
                }
            }

            // One attendance per employee per date.
            $existingDate = $employee->attendances()
                ->whereDate('attendance_date', $validated['attendance_date'])
                ->first();

            if ($existingDate) {
                return response()->json([
                    'message' => 'Attendance has already been marked for this date.',
                ], 409);
            }

            try {
                $attendance = $employee->attendances()->create([
                    'attendance_date' => $validated['attendance_date'],
                    'check_in' => $validated['check_in'],
                    'status' => 'present',
                    'latitude' => $validated['latitude'] ?? null,
                    'longitude' => $validated['longitude'] ?? null,
                    'sync_id' => $validated['sync_id'] ?? null,
                ]);
            } catch (\Illuminate\Database\QueryException $exception) {
                // Another request may have inserted the same date first.
                $existingDate = $employee->attendances()
                    ->whereDate('attendance_date', $validated['attendance_date'])
                    ->first();

                if ($existingDate) {
                    return response()->json([
                        'message' => 'Attendance has already been marked for this date.',
                    ], 409);
                }

                throw $exception;
            }

            return response()->json([
                'message' => 'Attendance marked successfully.',
                'attendance' => $attendance,
            ], 201);
        });
    });

// Mobile attendance actions require a fresh GPS event and are stored with the
// attendance mutation in one transaction. The older POST route above remains
// available for already-installed app versions and web integrations.
Route::middleware(['auth:sanctum', 'role:employee'])
    ->post('/employee/attendance-actions', [ApiAttendanceController::class, 'store']);

Route::middleware(['auth:sanctum', 'role:employee'])
    ->post('/employee/attendance-actions/{clientEventId}/resolve-address', [ApiAttendanceController::class, 'resolveAddress'])
    ->whereUuid('clientEventId');


Route::middleware(['auth:sanctum', 'role:employee'])->get('/employee/performance', function (Request $request) {

    $employee = $request->user()->employee;

    if (!$employee) {
        return response()->json([
            'message' => 'Employee profile not found'
        ], 404);
    }

    $performance = $employee->performances()
        ->orderBy('review_date', 'desc')
        ->get();

    return response()->json([
        'performance' => $performance,
    ]);
});

Route::middleware(['auth:sanctum', 'role:admin'])
    ->get('/admin/dashboard', function (Request $request) {

        return response()->json([
            'total_users' => User::count(),
            'total_employees' => Employee::count(),
            'total_hr' => User::where('role', 'hr')->count(),
            'pending_leaves' => \App\Models\Leave::where('status', 'pending')->count(),
            'approved_leaves' => \App\Models\Leave::where('status', 'approved')->count(),
            'rejected_leaves' => \App\Models\Leave::where('status', 'rejected')->count(),
            'total_tasks' => \App\Models\Task::count(),
            'unassigned_tasks' => \App\Models\Task::doesntHave('assignments')->count(),
            'overdue_tasks' => \App\Models\Task::whereDate('due_date', '<', today())
                ->whereHas('assignments', fn ($query) => $query->where('status', '!=', 'completed'))
                ->count(),
            'new_feedback' => \App\Models\Feedback::where('status', 'new')->count(),
        ]);
    });

Route::middleware(['auth:sanctum', 'role:employee'])->group(function () {

    Route::get('/employee/leaves', function (Request $request) {

        $employee = $request->user()->employee;

        if (!$employee) {
            return response()->json([
                'message' => 'Employee profile not found'
            ], 404);
        }

        $leaves = $employee->leaves()
            ->orderBy('start_date', 'desc')
            ->get();

        return response()->json([
            'leaves' => $leaves,
        ]);
    });

    Route::patch('/employee/leaves/{leave}', [EmployeeLeaveController::class, 'update']);
    Route::get('/employee/tasks', [TaskController::class, 'apiMyTasks']);
    Route::get('/employee/tasks/{assignment}', [TaskController::class, 'apiMyTask']);
    Route::patch('/employee/tasks/{assignment}/progress', [TaskController::class, 'apiUpdateMyProgress']);
    Route::get('/employee/feedback', [FeedbackController::class, 'apiMine']);
    Route::post('/employee/feedback', [FeedbackController::class, 'apiStoreMine']);

});

Route::middleware(['auth:sanctum', 'role:employee'])->post('/employee/leaves', function (Request $request) {

    $employee = $request->user()->employee;

    if (!$employee) {
        return response()->json([
            'message' => 'Employee profile not found'
        ], 404);
    }

    $validated = $request->validate([
        'start_date' => 'required|date',
        'end_date' => 'required|date|after_or_equal:start_date',
        'leave_type' => 'required|string|max:255',
    'reason' => 'nullable|string|max:5000',
        'sync_id' => 'nullable|uuid',
    ]);

    if (!empty($validated['sync_id'])) {
        $existingLeave = $employee->leaves()->where('sync_id', $validated['sync_id'])->first();
        if ($existingLeave) {
            $samePayload = $existingLeave->start_date->toDateString() === $validated['start_date']
                && $existingLeave->end_date->toDateString() === $validated['end_date']
                && $existingLeave->leave_type === $validated['leave_type']
                && $existingLeave->reason === ($validated['reason'] ?? null);

            if (!$samePayload) {
                return response()->json([
                    'message' => 'This request ID was already used for different leave details.',
                ], 409);
            }

            return response()->json([
                'message' => 'Leave request already submitted',
                'leave' => $existingLeave,
            ], 200);
        }
    }

    try {
        $leave = $employee->leaves()->create([
            'start_date' => $validated['start_date'],
            'end_date' => $validated['end_date'],
            'leave_type' => $validated['leave_type'],
            'reason' => $validated['reason'] ?? null,
            'status' => 'pending',
            'sync_id' => $validated['sync_id'] ?? null,
        ]);
    } catch (\Illuminate\Database\QueryException $exception) {
        $leave = $validated['sync_id'] ?? null
            ? $employee->leaves()->where('sync_id', $validated['sync_id'])->first()
            : null;

        if (!$leave) {
            throw $exception;
        }

        $samePayload = $leave->start_date->toDateString() === $validated['start_date']
            && $leave->end_date->toDateString() === $validated['end_date']
            && $leave->leave_type === $validated['leave_type']
            && $leave->reason === ($validated['reason'] ?? null);

        if (!$samePayload) {
            return response()->json([
                'message' => 'This request ID was already used for different leave details.',
            ], 409);
        }

        return response()->json([
            'message' => 'Leave request already submitted',
            'leave' => $leave,
        ], 200);
    }

    return response()->json([
        'message' => 'Leave request submitted successfully',
        'leave' => $leave,
    ], 201);
});

Route::middleware(['auth:sanctum', 'role:employee'])
    ->post('/employee/location-events', [LocationEventController::class, 'store']);

Route::middleware(['auth:sanctum', 'role:admin,hr'])->group(function () {
    Route::get('/management/location-events', [LocationEventManagementController::class, 'apiIndex']);
    Route::get('/management/task-options', [TaskController::class, 'apiOptions']);
    Route::get('/management/tasks', [TaskController::class, 'apiIndex']);
    Route::post('/management/tasks', [TaskController::class, 'apiStore']);
    Route::patch('/management/tasks/{task}', [TaskController::class, 'apiUpdate']);
    Route::get('/management/projects', [ProjectController::class, 'apiIndex']);
    Route::post('/management/projects', [ProjectController::class, 'apiStore']);
    Route::patch('/management/projects/{project}', [ProjectController::class, 'apiUpdate']);
    Route::get('/management/feedback', [FeedbackController::class, 'apiIndex']);
    Route::patch('/management/feedback/{feedback}', [FeedbackController::class, 'apiUpdate']);
});
