<?php

namespace App\Http\Controllers;

use App\Models\Employee;
use App\Models\Salary;
use Carbon\Carbon;
use Illuminate\Database\QueryException;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class SalaryController extends Controller
{
    private const MAX_SALARY_CENTS = 999_999_999_999;

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
        try {
            Salary::create($data);
        } catch (QueryException $exception) {
            if (! $this->salaryExistsForMonth($data['employee_id'], $data['salary_month'])) {
                throw $exception;
            }

            $this->throwDuplicateSalaryMonth();
        }

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
        $data = $this->validated($request, $salary);
        try {
            $salary->update($data);
        } catch (QueryException $exception) {
            if (! $this->salaryExistsForMonth($data['employee_id'], $data['salary_month'], $salary)) {
                throw $exception;
            }

            $this->throwDuplicateSalaryMonth();
        }

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
        if ($this->salaryExistsForMonth($data['employee_id'], $month, $salary)) {
            $this->throwDuplicateSalaryMonth();
        }

        $netSalaryCents = $this->amountToCents($data['basic_salary'])
            + $this->amountToCents($data['allowances'])
            - $this->amountToCents($data['deductions']);

        if ($netSalaryCents < 0) {
            throw ValidationException::withMessages([
                'deductions' => 'Deductions cannot exceed basic salary plus allowances.',
            ]);
        }

        if ($netSalaryCents > self::MAX_SALARY_CENTS) {
            throw ValidationException::withMessages([
                'allowances' => 'The calculated net salary cannot exceed 9,999,999,999.99.',
            ]);
        }

        $data['salary_month'] = $month;
        $data['net_salary'] = sprintf(
            '%d.%02d',
            intdiv($netSalaryCents, 100),
            $netSalaryCents % 100,
        );

        return $data;
    }

    private function amountToCents(string|int|float $amount): int
    {
        [$whole, $fraction] = explode('.', number_format((float) $amount, 2, '.', ''), 2);

        return ((int) $whole * 100) + (int) $fraction;
    }

    private function salaryExistsForMonth(int|string $employeeId, string $month, ?Salary $salary = null): bool
    {
        return Salary::query()
            ->where('employee_id', $employeeId)
            ->whereDate('salary_month', $month)
            ->when($salary, fn ($query) => $query->whereKeyNot($salary->getKey()))
            ->exists();
    }

    private function throwDuplicateSalaryMonth(): void
    {
        throw ValidationException::withMessages([
            'salary_month' => 'A salary record already exists for this employee and month.',
        ]);
    }
}
