<?php

use App\Http\Controllers\AttendanceController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\EmployeeController;
use App\Http\Controllers\LeaveController;
use App\Http\Controllers\PerformanceController;
use App\Http\Controllers\SalaryController;
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
        Route::get('/my/performance', [PerformanceController::class, 'myPerformance'])->name('employee.performance.index');
        Route::get('/my/performance/{performance}', [PerformanceController::class, 'show'])->name('employee.performance.show');
        Route::get('/my-salary', [SalaryController::class, 'mySalary'])->name('my-salary.index');
        Route::get('/my-salary/{salary}', [SalaryController::class, 'mySalaryShow'])->name('my-salary.show');
    });

    Route::middleware('role:admin,hr')->group(function () {
        Route::resource('employees', EmployeeController::class);
        Route::resource('attendances', AttendanceController::class);
        Route::get('/leaves', [LeaveController::class, 'index'])->name('leaves.index');
        Route::get('/leaves/{leave}', [LeaveController::class, 'show'])->name('leaves.show');
        Route::patch('/leaves/{leave}', [LeaveController::class, 'update'])->name('leaves.update');
        Route::resource('performances', PerformanceController::class);
        Route::resource('salaries', SalaryController::class)->except('destroy');
    });

    Route::middleware('role:admin')->delete('/salaries/{salary}', [SalaryController::class, 'destroy'])->name('salaries.destroy');
});


// Practice Routes

Route::middleware(['auth', 'role:admin,hr'])->group(function () {
Route::get('/query-practice' , [PracticeController::class , 'queryPractice']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice1']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice2']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice3']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice4']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice5']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice6']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice7']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice8']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice9']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice10']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice11']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice12']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice13']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice14']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice15']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice16']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice17']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice18']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice19']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice20']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice21']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice22']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice23']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice24']);
Route::get('/query-practice' , [PracticeController::class , 'queryPractice25']);
Route::get('/query-practice2' , [Practice2Controller::class , 'eloquentPractice']);
Route::get('/query-practice2' , [Practice2Controller::class , 'eloquentPractice2']);
Route::get('/query-practice2' , [Practice2Controller::class , 'eloquentPractice3']);
Route::get('/query-practice2' , [Practice2Controller::class , 'eloquentPractice4']);
Route::get('/query-practice2' , [Practice2Controller::class , 'eloquentPractice5']);
});
