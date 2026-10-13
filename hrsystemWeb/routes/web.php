<?php

use App\Http\Controllers\AttendanceController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\EmployeeController;
use App\Http\Controllers\LeaveController;
use App\Http\Controllers\PerformanceController;
use App\Http\Controllers\SalaryController;
use App\Http\Controllers\TaskController;
use App\Http\Controllers\ProjectController;
use App\Http\Controllers\FeedbackController;
use App\Http\Controllers\LocationEventManagementController;
use Illuminate\Support\Facades\Route;

// Practice Controller 

use App\Http\Controllers\PracticeController;
use App\Http\Controllers\Practice2Controller;

Route::get('/', function () {
    return auth()->check()
        ? redirect()->route('dashboard')
        : view('welcome');
})->name('home');

Route::middleware(['auth'])->group(function () {
    Route::get('/employee/pending-profile', function () {
        if (!auth()->user()->isInactiveEmployee()) {
            return redirect()->route('dashboard');
        }

        return view('employees.pending-profile');
    })->name('employee.pending-profile');

    Route::get('/dashboard', [DashboardController::class, 'index'])->name('dashboard');
    Route::get('/dashboard/snapshot', [DashboardController::class, 'snapshot'])
        ->name('dashboard.snapshot');

    Route::middleware('role:admin')->get('/admin', [DashboardController::class, 'admin'])->name('admin.dashboard');
    Route::middleware('role:admin,hr')->get('/hr', [DashboardController::class, 'hr'])->name('hr.dashboard');
    Route::middleware('role:employee')->group(function () {
        Route::get('/employee', [DashboardController::class, 'employee'])->name('employee.dashboard');
        Route::get('/my/leaves', [LeaveController::class, 'myLeaves'])->name('employee.leaves.index');
        Route::get('/my/leaves/{leave}', [LeaveController::class, 'show'])->name('employee.leaves.show');
        Route::get('/leave/create', [LeaveController::class, 'create'])->name('employee.leave.create');
        Route::post('/leave', [LeaveController::class, 'store'])->name('employee.leave.store');
        Route::get('/my/leaves/{leave}/edit', [LeaveController::class, 'editMine'])->name('employee.leaves.edit');
        Route::patch('/my/leaves/{leave}', [LeaveController::class, 'updateMine'])->name('employee.leaves.update');
        Route::get('/my/tasks', [TaskController::class, 'myTasks'])->name('employee.tasks.index');
        Route::get('/my/tasks/{assignment}', [TaskController::class, 'myTask'])->name('employee.tasks.show');
        Route::patch('/my/tasks/{assignment}', [TaskController::class, 'updateMyProgress'])->name('employee.tasks.update');
        Route::get('/my/feedback', [FeedbackController::class, 'mine'])->name('employee.feedback.index');
        Route::post('/my/feedback', [FeedbackController::class, 'storeMine'])->name('employee.feedback.store');
        Route::get('/my/performance', [PerformanceController::class, 'myPerformance'])->name('employee.performance.index');
        Route::get('/my/performance/{performance}', [PerformanceController::class, 'show'])->name('employee.performance.show');
        Route::get('/my-salary', [SalaryController::class, 'mySalary'])->name('my-salary.index');
        Route::get('/my-salary/{salary}', [SalaryController::class, 'mySalaryShow'])->name('my-salary.show');
    });

    Route::middleware('role:admin,hr')->group(function () {
        Route::resource('employees', EmployeeController::class);
        Route::patch('/employees/{employee}/account-status', [EmployeeController::class, 'updateAccountStatus'])->name('employees.account-status');
        Route::resource('attendances', AttendanceController::class);
        Route::get('/location-events', [LocationEventManagementController::class, 'index'])->name('location-events.index');
        Route::get('/leaves', [LeaveController::class, 'index'])->name('leaves.index');
        Route::get('/leaves/{leave}', [LeaveController::class, 'show'])->name('leaves.show');
        Route::patch('/leaves/{leave}', [LeaveController::class, 'update'])->name('leaves.update');
        Route::resource('performances', PerformanceController::class);
        Route::resource('salaries', SalaryController::class)->except('destroy');
        Route::resource('tasks', TaskController::class)->except('destroy');
        Route::get('/projects', [ProjectController::class, 'index'])->name('projects.index');
        Route::post('/projects', [ProjectController::class, 'store'])->name('projects.store');
        Route::patch('/projects/{project}', [ProjectController::class, 'update'])->name('projects.update');
        Route::get('/feedback', [FeedbackController::class, 'index'])->name('feedback.index');
        Route::patch('/feedback/{feedback}', [FeedbackController::class, 'update'])->name('feedback.update');
    });

    Route::middleware('role:admin')->delete('/salaries/{salary}', [SalaryController::class, 'destroy'])->name('salaries.destroy');
});


// Practice Routes

Route::middleware(['auth', 'role:admin,hr'])->group(function () {
    // Keep the currently effective examples; earlier same-URI registrations
    // were overwritten during route registration.
    Route::get('/query-practice', [PracticeController::class, 'queryPractice25']);
    Route::get('/query-practice2', [Practice2Controller::class, 'eloquentPractice5']);
});
