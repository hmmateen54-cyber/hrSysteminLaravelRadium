<?php

namespace App\Http\Controllers;

use App\Models\Employee;
use App\Models\Salary;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class SalaryController extends Controller
{
    public function index(Request $request)
    {
        $filters = $request->validate([
            'q' => ['nullable', 'string', 'max:100'],
            'payment_status' => ['nullable', Rule::in(Salary::PAYMENT_STATUSES)],
            'salary_month' => ['nullable', 'date_format:Y-m'],
        ]);

        $salaries = Salary::with('employee.user')
            ->when($filters['q'] ?? null, function ($query, $search) {
                $query->whereHas('employee', function ($employeeQuery) use ($search) {
                    $employeeQuery->where('employee_id', 'like', "%{$search}%")
                        ->orWhereHas('user', function ($userQuery) use ($search) {
                            $userQuery->where('name', 'like', "%{$search}%")
                                ->orWhere('email', 'like', "%{$search}%");
                        });
                });
            })
            ->when($filters['payment_status'] ?? null, fn ($query, $status) => $query->where('payment_status', $status))
            ->when($filters['salary_month'] ?? null, function ($query, $month) {
                [$year, $monthNumber] = explode('-', $month);
                $query->whereYear('salary_month', $year)->whereMonth('salary_month', $monthNumber);
            })
            ->orderByDesc('salary_month')
            ->orderByDesc('id')
            ->paginate(15)
            ->withQueryString();

        return view('salaries.index', compact('salaries', 'filters'));
    }

    public function mySalary()
    {
        $employee = auth()->user()->employee;
        $salaries = $employee
            ? $employee->salaries()->latest('salary_month')->latest('id')->paginate(12)
            : Salary::whereKey([])->paginate(12);

        return view('salaries.mine', compact('employee', 'salaries'));
    }

    public function mySalaryShow(Salary $salary)
    {
        $employee = auth()->user()->employee;

        abort_unless($employee && (int) $salary->employee_id === (int) $employee->getKey(), 403);

        $salary->load('employee.user');

        return view('salaries.my-show', compact('salary'));
    }

    public function create()
    {
        $employees = Employee::with('user')->orderBy('employee_id')->get();

        return view('salaries.create', compact('employees'));
    }

    public function store(Request $request)
    {
        $data = $this->validated($request);
        Salary::create($data);

        return redirect()->route('salaries.index')->with('success', 'Salary record created.');
    }

    public function show(Salary $salary)
    {
        $salary->load('employee.user');

        return view('salaries.show', compact('salary'));
    }

    public function edit(Salary $salary)
    {
        $salary->load('employee.user');
        $employees = Employee::with('user')->orderBy('employee_id')->get();

        return view('salaries.edit', compact('salary', 'employees'));
    }

    public function update(Request $request, Salary $salary)
    {
        $salary->update($this->validated($request, $salary));

        return redirect()->route('salaries.show', $salary)->with('success', 'Salary record updated.');
    }

    public function destroy(Salary $salary)
    {
        abort_unless(auth()->user()->role === 'admin', 403);

        $salary->delete();

        return redirect()->route('salaries.index')->with('success', 'Salary record deleted.');
    }

    private function validated(Request $request, ?Salary $salary = null): array
    {
        $data = $request->validate([
            'employee_id' => ['required', 'integer', 'exists:employees,id'],
            'basic_salary' => ['required', 'numeric', 'decimal:0,2', 'min:0', 'max:9999999999.99'],
            'allowances' => ['required', 'numeric', 'decimal:0,2', 'min:0', 'max:9999999999.99'],
            'deductions' => ['required', 'numeric', 'decimal:0,2', 'min:0', 'max:9999999999.99'],
            'salary_month' => ['required', 'date_format:Y-m'],
            'payment_status' => ['required', Rule::in(Salary::PAYMENT_STATUSES)],
        ]);

        $month = Carbon::createFromFormat('!Y-m-d', $data['salary_month'].'-01')->toDateString();
        $duplicate = Salary::query()
            ->where('employee_id', $data['employee_id'])
            ->whereDate('salary_month', $month)
            ->when($salary, fn ($query) => $query->whereKeyNot($salary->getKey()))
            ->exists();

        if ($duplicate) {
            throw ValidationException::withMessages([
                'salary_month' => 'A salary record already exists for this employee and month.',
            ]);
        }

        $netSalary = round(
            (float) $data['basic_salary'] + (float) $data['allowances'] - (float) $data['deductions'],
            2
        );

        if ($netSalary < 0) {
            throw ValidationException::withMessages([
                'deductions' => 'Deductions cannot exceed basic salary plus allowances.',
            ]);
        }

        $data['salary_month'] = $month;
        $data['net_salary'] = $netSalary;

        return $data;
    }
}
