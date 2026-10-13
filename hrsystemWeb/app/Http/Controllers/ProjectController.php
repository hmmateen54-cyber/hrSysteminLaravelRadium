<?php

namespace App\Http\Controllers;

use App\Models\Project;
use Illuminate\Http\Request;

class ProjectController extends Controller
{
    private const STATUSES = ['active', 'completed', 'on_hold'];

    public function index()
    {
        $projects = Project::withCount('tasks')->latest()->paginate(15);
        return view('projects.index', compact('projects'));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:160'],
            'description' => ['nullable', 'string', 'max:5000'],
            'status' => ['required', 'in:active,completed,on_hold'],
        ]);
        $project = Project::create($data + ['created_by' => $request->user()->id]);
        return redirect()->route('projects.index')->with('success', 'Project created.');
    }

    public function update(Request $request, Project $project)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:160'],
            'description' => ['nullable', 'string', 'max:5000'],
            'status' => ['required', 'in:active,completed,on_hold'],
        ]);
        $project->update($data);
        return redirect()->route('projects.index')->with('success', 'Project updated.');
    }

    public function apiIndex()
    {
        return response()->json([
            'projects' => Project::withCount('tasks')->latest()->paginate(25),
        ]);
    }

    public function apiStore(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:160'],
            'description' => ['nullable', 'string', 'max:5000'],
            'status' => ['required', 'in:'.implode(',', self::STATUSES)],
        ]);
        $project = Project::create($data + ['created_by' => $request->user()->id]);
        return response()->json(['project' => $project], 201);
    }

    public function apiUpdate(Request $request, Project $project)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:160'],
            'description' => ['nullable', 'string', 'max:5000'],
            'status' => ['required', 'in:'.implode(',', self::STATUSES)],
        ]);
        $project->update($data);
        return response()->json(['project' => $project->fresh()->loadCount('tasks')]);
    }
}
