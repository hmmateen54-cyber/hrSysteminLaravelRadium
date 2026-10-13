<?php

namespace App\Http\Controllers;

use App\Models\Employee;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;

class EmployeeController extends Controller
{
    /**
     * Display a listing of the resource.
     */
    public function index()
    {
        $employees = Employee::with('user')->latest()->paginate(15);
        return view('employees.index', compact('employees'));
    }

    /**
     * Show the form for creating a new resource.
     */
    public function create()
    {
        return view('employees.create');
    }

    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8'],
            'employee_id' => ['required', 'string', 'max:255', 'unique:employees,employee_id'],
            'phone' => ['nullable', 'string', 'max:20'],
            'department' => ['nullable', 'string', 'max:255'],
            'designation' => ['nullable', 'string', 'max:255'],
            'joining_date' => ['nullable', 'date'],
            'salary' => ['nullable', 'numeric', 'min:0'],
        ]);

        $activated = DB::transaction(function () use ($validated) {
            $user = User::create([
                'name' => $validated['name'],
                'email' => $validated['email'],
                'password' => Hash::make($validated['password']),
                'role' => 'employee',
                'account_status' => 'pending',
            ]);

            $employee = $user->employee()->create(collect($validated)->only([
                'employee_id', 'phone', 'department', 'designation', 'joining_date', 'salary',
            ])->all());

            if ($employee->hasCompleteProfile()) {
                $user->forceFill(['account_status' => 'active'])->save();
            }

            return $user->account_status === 'active';
        });

        return redirect()->route('employees.index')->with(
            'success',
            $activated
                ? 'Employee created and activated successfully.'
                : 'Employee created. The account remains pending until HR completes the required profile fields.'
        );
    }

    /**
     * Display the specified resource.
     */
    public function show(Employee $employee)
    {
        $employee->load('user');

        return view('employees.show' , compact('employee'));
    }

    /**
     * Show the form for editing the specified resource.
     */
    public function edit(Employee $employee)
    {
        $employee->load('user');

        return view('employees.edit', compact('employee'));
    }

    /**
     * Update the specified resource in storage.
     */
    public function update(Request $request, Employee $employee)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email,'.$employee->user_id],
            'employee_id' => ['required', 'string', 'max:255', 'unique:employees,employee_id,'.$employee->id],
            'phone' => ['nullable', 'string', 'max:20'],
            'department' => ['nullable', 'string', 'max:255'],
            'designation' => ['nullable', 'string', 'max:255'],
            'joining_date' => ['nullable', 'date'],
            'salary' => ['nullable', 'numeric', 'min:0'],
        ]);

        $user = $employee->user;
        abort_if(!$user, 404);

        $activated = DB::transaction(function () use ($employee, $user, $validated) {
            $user->update(collect($validated)->only(['name', 'email'])->all());
            $employee->update(collect($validated)->only([
                'employee_id', 'phone', 'department', 'designation', 'joining_date', 'salary',
            ])->all());

            if ($user->account_status === 'pending' && $employee->fresh()->hasCompleteProfile()) {
                $user->forceFill(['account_status' => 'active'])->save();

                return true;
            }

            return false;
        });

        return redirect()
            ->route('employees.index')
            ->with(
                'success',
                $activated
                    ? 'Employee profile completed and account activated successfully.'
                    : ($user->account_status === 'pending'
                        ? 'Employee updated. The account remains pending until HR completes the required profile fields.'
                        : 'Employee updated successfully.')
            );
    }

    /**
     * Remove the specified resource from storage.
     */

    public function destroy(Employee $employee)
    {
        DB::transaction(function () use ($employee) {
            $employee->user?->delete();
            $employee->delete();
        });

        return redirect()
            ->route('employees.index')
            ->with('success', 'Employee deleted successfully.');
    }
}
