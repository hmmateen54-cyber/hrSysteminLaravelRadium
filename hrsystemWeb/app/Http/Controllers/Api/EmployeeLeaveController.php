<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Leave;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class EmployeeLeaveController extends Controller
{
    public function update(Request $request, Leave $leave)
    {
        $validated = $request->validate([
            'start_date' => ['required', 'date'],
            'end_date' => ['required', 'date', 'after_or_equal:start_date'],
            'leave_type' => ['required', 'string', 'max:255'],
            'reason' => ['nullable', 'string', 'max:5000'],
        ]);

        $updated = DB::transaction(function () use ($request, $leave, $validated) {
            $employeeId = $request->user()->employee?->id;
            abort_unless($employeeId, 404, 'Employee profile not found.');

            $locked = Leave::query()
                ->whereKey($leave->id)
                ->where('employee_id', $employeeId)
                ->lockForUpdate()
                ->firstOrFail();

            abort_unless($locked->status === 'pending', 409, 'Only pending leave requests can be edited.');
            $locked->update($validated);
            return $locked->fresh();
        });

        return response()->json(['message' => 'Leave request updated.', 'leave' => $updated]);
    }
}
