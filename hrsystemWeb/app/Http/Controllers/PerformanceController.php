<?php

namespace App\Http\Controllers;

use App\Models\Employee;
use App\Models\Performance;
use Illuminate\Http\Request;

class PerformanceController extends Controller
{
    public function index()
    {
        $performances = Performance::with('employee.user')->latest('review_date')->paginate(15);

        return view('performances.index', compact('performances'));
    }

    public function myPerformance()
    {
        $employee = auth()->user()->employee;
        $performances = $employee
            ? $employee->performances()->latest('review_date')->paginate(15)
            : Performance::whereKey([])->paginate(15);

        return view('performances.index', [
            'performances' => $performances,
            'isEmployeeView' => true,
        ]);
    }

    public function create()
    {
        $employees = Employee::with('user')->orderBy('employee_id')->get();

        return view('performances.create', compact('employees'));
    }

    public function store(Request $request)
    {
        Performance::create($this->validated($request));

        return redirect()->route('performances.index')->with('success', 'Performance review created.');
    }

    public function show(Performance $performance)
    {
        $performance->load('employee.user');
        $isEmployeeView = auth()->user()->role === 'employee';

        if ($isEmployeeView && auth()->user()->employee?->id !== $performance->employee_id) {
            abort(403);
        }

        return view('performances.show', compact('performance', 'isEmployeeView'));
    }

    public function edit(Performance $performance)
    {
        $performance->load('employee.user');
        $employees = Employee::with('user')->orderBy('employee_id')->get();

        return view('performances.edit', compact('performance', 'employees'));
    }

    public function update(Request $request, Performance $performance)
    {
        $performance->update($this->validated($request));

        return redirect()->route('performances.index')->with('success', 'Performance review updated.');
    }

    public function destroy(Performance $performance)
    {
        $performance->delete();

        return redirect()->route('performances.index')->with('success', 'Performance review deleted.');
    }

    private function validated(Request $request): array
    {
        return $request->validate([
            'employee_id' => ['required', 'integer', 'exists:employees,id'],
            'review_date' => ['required', 'date'],
            'rating' => ['required', 'numeric', 'between:0,10'],
            'comments' => ['nullable', 'string', 'max:5000'],
        ]);
    }
}
