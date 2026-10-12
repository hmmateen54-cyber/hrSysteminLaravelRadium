<?php

namespace App\Http\Controllers;

use App\Models\Attendance;
use App\Models\Employee;
use App\Models\Leave;
use App\Models\Performance;

class DashboardController extends Controller
{
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
