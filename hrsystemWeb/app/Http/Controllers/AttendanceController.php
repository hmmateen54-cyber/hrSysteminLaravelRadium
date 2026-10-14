<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Attendance;
use App\Models\Employee;
use Illuminate\Support\Facades\DB;

class AttendanceController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        $attendances = Attendance::with(['employee.user', 'checkInLocationEvent'])
            ->latest('attendance_date')
            ->paginate(15);

        return view('attendances.index', compact('attendances'));
    }
    /**
     * Show the form for creating a new resource.
     */
    public function create()
    {
        $employees = Employee::with('user')->get();

        return view('attendances.create', compact('employees'));
    }

    /**
     * Store a newly created resource in storage.
     */

    public function store(Request $request)
    {
        $validated = $request->validate([
        'employee_id' => 'required|exists:employees,id',
        'attendance_date' => 'required|date',
        'status' => 'required|in:present,absent,late,leave',
        'check_in' => 'nullable|date_format:H:i',
        'check_out' => 'nullable|date_format:H:i',
        'remarks' => 'nullable|string',
        ]);

        $created = DB::transaction(function () use ($validated) {
            Employee::query()
                ->whereKey($validated['employee_id'])
                ->lockForUpdate()
                ->firstOrFail();

            $alreadyExists = Attendance::where('employee_id', $validated['employee_id'])
                ->where('attendance_date', $validated['attendance_date'])
                ->exists();

            if ($alreadyExists) return false;

            Attendance::create($validated);
            return true;
        });

        if (!$created) {
            return back()
                ->withErrors(['attendance_date' => 'Attendance already exists for this employee on this date.'])
                ->withInput();
        }

        return redirect()->route('attendances.index')->with('success', 'Attendance marked successfully.');
    }

    /**
     * Display the specified resource.
     */
    public function show(Attendance $attendance)
    {
        $attendance->load('employee.user');

        return view('attendances.show', compact('attendance'));
    }

    /**
     * Show the form for editing the specified resource.
     */
    public function edit(Attendance $attendance)
    {
        $employees = Employee::with('user')->get();

        return view('attendances.edit', compact('attendance', 'employees'));
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, Attendance $attendance)
    {
        $validated = $request->validate([
        'employee_id' => 'required|exists:employees,id',
        'attendance_date' => 'required|date',
        'status' => 'required|in:present,absent,late,leave',
        'check_in' => 'nullable|date_format:H:i',
        'check_out' => 'nullable|date_format:H:i',
        'remarks' => 'nullable|string',
        ]);

        $duplicate = DB::transaction(function () use ($validated, $attendance) {
            Employee::query()
                ->whereKey($validated['employee_id'])
                ->lockForUpdate()
                ->firstOrFail();

            $duplicate = Attendance::where('employee_id', $validated['employee_id'])
                ->where('attendance_date', $validated['attendance_date'])
                ->where('id', '<>', $attendance->getKey())
                ->exists();

            if (!$duplicate) $attendance->update($validated);
            return $duplicate;
        });

        if ($duplicate) {
            return back()->withErrors(['attendance_date' => 'Attendance already exists for this employee on this date.'])->withInput();
        }

        return redirect()->route('attendances.index')->with('success', 'Attendance updated successfully.');
    }

    /**
     * Remove the specified resource from storage.
     */
   public function destroy(Attendance $attendance)
    {
        $attendance->delete();

        return redirect()
            ->route('attendances.index')
            ->with('success', 'Attendance deleted successfully.');
    }
}
