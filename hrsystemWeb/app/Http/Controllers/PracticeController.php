<?php

namespace App\Http\Controllers;

// use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class PracticeController extends Controller
{
    public function queryPractice () {
        $employees = DB::table('users')->join('salaries' , 'users.id' , '=', 'salaries.employee_id')->select('users.name', 'users.email', 'salaries.basic_salary', 'salaries.net_salary')->get();
        return view('practice.practice', compact('employees'));
    }
    
    public function QueryPractice1 () {
        $employees = DB::table('users')->join('attendances' , 'users.id' , '=' , 'attendances.employee_id')->select('users.name' , 'users.email' , 'attendances.attendance_date' , 'attendances.status' , 'attendances.check_in' , 'attendances.check_out' , 'attendances.remarks')->get();
        return view('practice.practice', compact('employees'));
    }

    public function QueryPractice2 () {
        $employees = DB::table('employees')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice3 () {
        $employees = DB::table('employees')->select('employees.employee_id' , 'employees.phone' , 'employees.department' , 'employees.designation')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice4 () {
        $employees = DB::table('employees')->where('employees.department' , '=' , 'police')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice5 () {
        $employees = DB::table('employees')->where('employees.department' , '=' , 'police')->where('employees.designation' , '=' , 'ceo')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice6 () {
        $employees = DB::table('employees')->where('employees.id' , '>' , 6)->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice7 () {
        $employees = DB::table('employees')->where('employees.id' , '>' , 6)->where('employees.department' , '=' , 'police')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice8 () {
        $employees = DB::table('employees')->where('employees.id' , '<' , 6)->where('employees.department' , '=' , 'police')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice9 () {
        $employees = DB::table('employees')->whereIn('department', ['head' , 'police'])->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice11 () {
        $employees = DB::table('employees')->whereNotNull('phone')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice10 () {
        $employees = DB::table('employees')->whereNotNull('phone')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice12 () {
        $employees = DB::table('employees')->where('department' , '=' , 'hr')->orWhere('department' , '=' , 'police')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice13 () {
        $employees = DB::table('employees')->where('designation' , 'LIKE' ,'%lalit%')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice14 () {
        $employees = DB::table('employees')->where('designation' , 'LIKE' ,'%constable%' , 'AND' , 'department' , '=' , 'devoleper')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice15 () {
        $employees = DB::table('employees')->OrderBy('id' , 'asc')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice16 () {
        $employees = DB::table('employees')->where('department' , '=' , 'devoleper')->OrderBy('id' , 'desc')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice17 () {
        $employees = DB::table('employees')->limit(5)->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice18 () {
        $employees = DB::table('employees')->where('id' , '=' , 6)->first();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice19 () {
        $totalemployees = DB::table('employees')->count();
        return view('practice.practice' , compact('totalemployees'));
    }

    public function QueryPractice20 () {
        $employees = DB::table('users')->join('salaries' , 'users.id' , '=' , 'salaries.employee_id')->select('users.id' , 'users.email' , 'salaries.basic_salary' , 'salaries.net_salary')->where('net_salary' , '<' , 50000)->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice21() {
        $employees = DB::table('users')
        ->join('salaries' , 'users.id' , '=' ,'salaries.employee_id')
        ->join('employees' , 'users.id' , '=' ,'employees.user_id')
        ->select('users.name' , 'users.email' , 'salaries.basic_salary' , 'salaries.net_salary' , 'employees.department' , 'employees.designation')
        ->where('salaries.net_salary' , '>' , 30000)
        ->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice22 () {
        $employees = DB::table('users')->join('salaries' , 'users.id' , 'salaries.employee_id')->select('users.name' , 'users.email' , 'salaries.net_salary' , 'salaries.basic_salary')->where('salaries.net_salary' , '>' , '10000')
        ->OrderBy('net_salary' , 'asc')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice23 () {
        $employees = DB::table('users')->join('salaries' , 'users.id' , 'salaries.employee_id')->join('employees' , 'users.id' , 'employees.user_id')->select('users.name' , 'users.email' , 'salaries.net_salary' , 'employees.department' , 'employees.designation')->whereIn('employees.department' , ['police' , 'hr'])->
        where('salaries.net_salary' , '>' , '30000')
        ->OrderBy('salaries.net_salary' , 'desc')->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice24() {
        $employees = DB::table('employees')
        ->select("department",
        DB::raw('COUNT(*) as total')
        )
        ->groupBy('department')
        ->get();
        return view('practice.practice' , compact('employees'));
    }

    public function QueryPractice25 () {
        $employees = DB::table('users')
        ->join('salaries' , 'users.id' , '=' , 'salaries.employee_id')
        ->join('employees' , 'users.id' , '=' , 'employees.user_id')
        ->select("employees.department" ,
         DB::raw('SUM(salaries.net_salary) as total'))
        ->groupBy('employees.department')
        ->get();
        return view('practice.practice' , compact('employees'));
    }
}
