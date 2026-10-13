<?php

namespace App\Http\Controllers;

use App\Models\LocationEvent;
use Illuminate\Http\Request;

class LocationEventManagementController extends Controller
{
    public function index()
    {
        $events = LocationEvent::query()
            ->select(['id', 'employee_id', 'purpose', 'recorded_at', 'synced_at'])
            ->with('employee.user:id,name')
            ->latest('recorded_at')
            ->paginate(25);

        return view('locations.index', compact('events'));
    }

    public function apiIndex(Request $request)
    {
        $query = LocationEvent::query()
            ->select(['id', 'employee_id', 'purpose', 'recorded_at', 'synced_at'])
            ->with('employee:id,user_id,employee_id')
            ->with('employee.user:id,name')
            ->latest('recorded_at');

        if ($request->filled('employee')) {
            $query->whereHas('employee', fn ($builder) => $builder->where('id', $request->integer('employee')));
        }

        return response()->json(['events' => $query->paginate(25)->withQueryString()]);
    }
}
