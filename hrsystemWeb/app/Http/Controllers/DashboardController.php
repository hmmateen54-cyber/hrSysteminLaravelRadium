<?php

namespace App\Http\Controllers;

use App\Models\Attendance;
use App\Models\Employee;
use App\Models\Leave;
use App\Models\Performance;

class DashboardController extends Controller
{
    public function snapshot()
    {
        $user = auth()->user();
        abort_unless(in_array($user->role, ['admin', 'hr', 'employee'], true), 403);
        $employee = $user->employee;
        $employeeLeaves = fn () => $employee
            ? Leave::query()->where('employee_id', $employee->getKey())
            : Leave::query()->whereKey([]);

        if ($user->role === 'employee') {
            $recentLeaves = $employeeLeaves()->latest()->limit(5)->get();
            $latestSalary = $employee
                ? $employee->salaries()
                    ->latest('salary_month')
                    ->latest('id')
                    ->first()
                : null;
            $metrics = [
                'pendingLeaves' => $employeeLeaves()->where('status', 'pending')->count(),
                'approvedLeaves' => $employeeLeaves()->where('status', 'approved')->count(),
                'rejectedLeaves' => $employeeLeaves()->where('status', 'rejected')->count(),
                'performanceCount' => $employee
                    ? $employee->performances()->count()
                    : 0,
                'averageRating' => $employee
                    ? $employee->performances()->avg('rating')
                    : null,
            ];
        } else {
            $recentLeaves = Leave::with('employee.user')->latest()->limit(6)->get();
            $metrics = [
                'totalEmployees' => Employee::count(),
                'pendingLeaves' => Leave::where('status', 'pending')->count(),
                'approvedLeaves' => Leave::where('status', 'approved')->count(),
                'performanceRecords' => Performance::count(),
            ];

            if ($user->role === 'admin') {
                $metrics['totalAttendance'] = Attendance::count();
            } else {
                $metrics['todayAttendance'] = Attendance::whereDate('attendance_date', today())->count();
            }
        }

        return response()->json([
            'metrics' => $metrics,
            'employee' => $user->role === 'employee' && $employee
                ? [
                    'employee_id' => $employee->employee_id,
                    'department' => $employee->department,
                    'designation' => $employee->designation,
                ]
                : null,
            'salary' => $user->role === 'employee' && $latestSalary
                ? [
                    'net_salary' => number_format((float) $latestSalary->net_salary, 2),
                    'salary_month' => $latestSalary->salary_month->format('F Y'),
                    'payment_status' => $latestSalary->payment_status,
                    'updated_at' => $latestSalary->updated_at->format('d M Y'),
                ]
                : null,
            'recent_leaves' => $recentLeaves->map(fn (Leave $leave) => [
                'id' => $leave->getKey(),
                'leave_type' => $leave->leave_type,
                'start_date' => $leave->start_date->format('d M Y'),
                'end_date' => $leave->end_date->format('d M Y'),
                'created_at' => $leave->created_at->format('d M Y'),
                'status' => $leave->status,
                'employee_name' => $user->role === 'employee'
                    ? null
                    : ($leave->employee?->user?->name ?? 'Unknown employee'),
                'employee_number' => $user->role === 'employee'
                    ? null
                    : ($leave->employee?->employee_id ?? '—'),
                'url' => $user->role === 'employee'
                    ? route('employee.leaves.show', $leave)
                    : route('leaves.show', $leave),
            ])->values(),
        ])->header('Cache-Control', 'no-store, private');
    }

    public function index()
    {
        $user = auth()->user();

        if ($user->role === 'admin') {
            return redirect()->route('admin.dashboard');
        }

        if ($user->role === 'hr') {
            return redirect()->route('hr.dashboard');
        }

        return redirect()->route('employee.dashboard');
    }

    public function admin()
    {
        return view('dashboard', [
            'role' => 'admin',
            'totalEmployees' => Employee::count(),
            'totalAttendance' => Attendance::count(),
            'pendingLeaves' => Leave::where('status', 'pending')->count(),
            'approvedLeaves' => Leave::where('status', 'approved')->count(),
            'performanceRecords' => Performance::count(),
            'recentLeaves' => Leave::with('employee.user')->latest()->limit(6)->get(),
        ]);
    }

    public function hr()
    {
        return view('dashboard', [
            'role' => 'hr',
            'totalEmployees' => Employee::count(),
            'todayAttendance' => Attendance::whereDate('attendance_date', today())->count(),
            'pendingLeaves' => Leave::where('status', 'pending')->count(),
            'approvedLeaves' => Leave::where('status', 'approved')->count(),
            'performanceRecords' => Performance::count(),
            'recentLeaves' => Leave::with('employee.user')->latest()->limit(6)->get(),
        ]);
    }

    public function employee()
    {
        $user = auth()->user();
        $employee = $user->employee;
        $leaveQuery = fn () => $employee
            ? Leave::query()->where('employee_id', $employee->getKey())
            : Leave::query()->whereKey([]);
        $performanceQuery = fn () => $employee
            ? Performance::query()->where('employee_id', $employee->getKey())
            : Performance::query()->whereKey([]);

        return view('dashboard', [
            'role' => 'employee',
            'employee' => $employee,
            'pendingLeaves' => $leaveQuery()->where('status', 'pending')->count(),
            'approvedLeaves' => $leaveQuery()->where('status', 'approved')->count(),
            'rejectedLeaves' => $leaveQuery()->where('status', 'rejected')->count(),
            'recentLeaves' => $leaveQuery()->latest()->limit(5)->get(),
            'performanceCount' => $performanceQuery()->count(),
            'averageRating' => $performanceQuery()->avg('rating'),
            'latestSalary' => $employee?->salaries()->latest('salary_month')->latest('id')->first(),
        ]);
    }
}
