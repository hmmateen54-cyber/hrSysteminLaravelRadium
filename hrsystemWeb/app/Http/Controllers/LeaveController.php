<?php

namespace App\Http\Controllers;

use App\Models\Leave;
use Illuminate\Http\Request;

class LeaveController extends Controller
{
    public function index()
    {
        $leaves = Leave::with('employee.user')->latest()->paginate(15);

        return view('leaves.index', compact('leaves'));
    }

    public function myLeaves()
    {
        $employee = auth()->user()->employee;
        $leaves = $employee ? $employee->leaves()->latest()->paginate(15) : Leave::whereKey([])->paginate(15);

        return view('leaves.my-index', compact('leaves', 'employee'));
    }

    public function create()
    {
        $employee = auth()->user()->employee;
        $leaves = $employee ? $employee->leaves()->latest()->paginate(5) : collect();

        return view('leaves.create', compact('employee', 'leaves'));
    }

    public function store(Request $request)
    {
        $validated = $request->validate([
            'start_date' => ['required', 'date'],
            'end_date' => ['required', 'date', 'after_or_equal:start_date'],
            'leave_type' => ['required', 'string', 'max:255'],
            'reason' => ['nullable', 'string', 'max:5000'],
        ]);

        $employee = $request->user()->employee;

        if (!$employee) {
            abort(403, 'Your account is not linked to an employee profile. Please contact HR.');
        }

        $employee->leaves()->create($validated + ['status' => 'pending']);

        return redirect()->route('employee.leaves.index')->with('success', 'Your leave request has been submitted.');
    }

    public function show(Leave $leave)
    {
        $leave->load('employee.user');
        $canManage = in_array(auth()->user()->role, ['admin', 'hr'], true);

        if (!$canManage && auth()->user()->employee?->id !== $leave->employee_id) {
            abort(403);
        }

        return view('leaves.show', compact('leave', 'canManage'));
    }

    public function update(Request $request, Leave $leave)
    {
        abort_unless($leave->status === 'pending', 409, 'This leave request has already been reviewed.');

        $validated = $request->validate([
            'status' => ['required', 'in:approved,rejected'],
            'admin_remarks' => ['nullable', 'string', 'max:5000'],
        ]);

        $leave->update($validated);

        return redirect()->route('leaves.index')->with('success', 'Leave request '. $validated['status'] .'.');
    }
}
