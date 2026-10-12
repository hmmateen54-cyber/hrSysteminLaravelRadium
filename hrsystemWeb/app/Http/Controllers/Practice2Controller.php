<?php

namespace App\Http\Controllers;

use App\Models\Employee;

class Practice2Controller extends Controller
{
    public function eloquentPractice()
    {
    $employees = Employee::all();
    return view('eloquent.eloquent', compact('employees'));
    }
    
    public function eloquentPractice2()
    {
    $employees = Employee::where('department', '=' , 'devoleper')
    ->orderBy('id' , 'desc')->get();
    return view('eloquent.eloquent', compact('employees'));
    }

    public function eloquentPractice3()
    {
    $employees = Employee::where('department', '=' , 'devoleper')
    ->orderBy('id' , 'desc')->get();
    return view('eloquent.eloquent', compact('employees'));
    }

    public function eloquentPractice4()
    {
    $employees = Employee::where('id', '>' , 5)
    ->where('id', '<' , 10)
    ->orderBy('id' , 'asc')
    ->get();
    return view('eloquent.eloquent', compact('employees'));
    }

    public function eloquentPractice5()
    {
    $employees = Employee::whereIn('department' , ['Hr' , 'police'])
    ->orderBy('id' , 'asc')
    ->get();
    return view('eloquent.eloquent', compact('employees'));
    }

    public function eloquentPractice6()
    {
    $employees = Employee::whereIn('department' , ['Hr' , 'police'])
    ->orderBy('id' , 'desc')
    ->get();
    return view('eloquent.eloquent', compact('employees'));
    }
}
