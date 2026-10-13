<?php

namespace App\Http\Controllers;

use App\Models\Feedback;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Database\QueryException;

class FeedbackController extends Controller
{
    private const CATEGORIES = ['workplace', 'payroll', 'benefits', 'management', 'other'];

    public function mine(Request $request)
    {
        $feedback = Feedback::where('user_id', $request->user()->id)->latest()->paginate(10);
        return view('feedback.mine', compact('feedback'));
    }

    public function storeMine(Request $request)
    {
        $data = $request->validate([
            'client_submission_id' => ['required', 'uuid'],
            'category' => ['required', 'in:'.implode(',', self::CATEGORIES)],
            'subject' => ['required', 'string', 'max:160'],
            'message' => ['required', 'string', 'max:5000'],
            'rating' => ['nullable', 'integer', 'between:1,5'],
        ]);

        $existing = Feedback::where('user_id', $request->user()->id)
            ->where('client_submission_id', $data['client_submission_id'])
            ->first();
        if ($existing) {
            if (!$this->sameSubmission($existing, $data)) {
                return back()->withInput()->withErrors([
                    'client_submission_id' => 'This submission ID was already used for different feedback. Refresh the form and submit again.',
                ]);
            }

            return redirect()->route('employee.feedback.index')->with('success', 'Your feedback was already submitted.');
        }

        try {
            Feedback::create($data + ['user_id' => $request->user()->id]);
        } catch (QueryException $exception) {
            $existing = Feedback::where('user_id', $request->user()->id)
                ->where('client_submission_id', $data['client_submission_id'])
                ->first();
            if (!$existing) throw $exception;
            if (!$this->sameSubmission($existing, $data)) {
                return back()->withInput()->withErrors([
                    'client_submission_id' => 'This submission ID was already used for different feedback. Refresh the form and submit again.',
                ]);
            }
        }
        return redirect()->route('employee.feedback.index')->with('success', 'Your feedback was submitted.');
    }

    public function index(Request $request)
    {
        $query = Feedback::with('author:id,name,email')->latest();
        if (in_array($request->query('category'), self::CATEGORIES, true)) $query->where('category', $request->query('category'));
        if (in_array($request->query('status'), ['new', 'reviewing', 'resolved'], true)) $query->where('status', $request->query('status'));
        if ($request->filled('from')) $query->whereDate('created_at', '>=', $request->query('from'));
        if ($request->filled('to')) $query->whereDate('created_at', '<=', $request->query('to'));
        $feedback = $query->paginate(15)->withQueryString();
        return view('feedback.index', compact('feedback'));
    }

    public function update(Request $request, Feedback $feedback)
    {
        $data = $request->validate([
            'status' => ['required', 'in:new,reviewing,resolved'],
            'internal_remarks' => ['nullable', 'string', 'max:5000'],
        ]);
        DB::transaction(function () use ($feedback, $data) {
            $locked = Feedback::query()->whereKey($feedback->id)->lockForUpdate()->firstOrFail();
            $locked->update($data);
        });
        return redirect()->route('feedback.index')->with('success', 'Feedback handling status updated.');
    }

    public function apiMine(Request $request)
    {
        $feedback = Feedback::where('user_id', $request->user()->id)
            ->latest()
            ->paginate(20);

        $feedback->setCollection(
            $feedback->getCollection()->map(fn (Feedback $record) => $this->employeePayload($record))
        );

        return response()->json(['feedback' => $feedback]);
    }

    public function apiStoreMine(Request $request)
    {
        $data = $request->validate([
            'client_submission_id' => ['required', 'uuid'],
            'category' => ['required', 'in:'.implode(',', self::CATEGORIES)],
            'subject' => ['required', 'string', 'max:160'],
            'message' => ['required', 'string', 'max:5000'],
            'rating' => ['nullable', 'integer', 'between:1,5'],
        ]);
        $existing = Feedback::where('user_id', $request->user()->id)
            ->where('client_submission_id', $data['client_submission_id'])->first();
        if ($existing) {
            if (!$this->sameSubmission($existing, $data)) {
                return response()->json([
                    'message' => 'This submission ID was already used for different feedback.',
                ], 409);
            }

            return response()->json(['feedback' => $this->employeePayload($existing)], 200);
        }

        try {
            $record = Feedback::create($data + ['user_id' => $request->user()->id]);
            $record->refresh();
        } catch (\Illuminate\Database\QueryException $exception) {
            $record = Feedback::where('user_id', $request->user()->id)
                ->where('client_submission_id', $data['client_submission_id'])->first();
            if (!$record) throw $exception;

            if (!$this->sameSubmission($record, $data)) {
                return response()->json([
                    'message' => 'This submission ID was already used for different feedback.',
                ], 409);
            }
        }
        return response()->json(['feedback' => $this->employeePayload($record)], 201);
    }

    public function apiIndex(Request $request)
    {
        $query = Feedback::with('author:id,name,email')->latest();
        if ($request->filled('category')) $query->where('category', $request->query('category'));
        if ($request->filled('status')) $query->where('status', $request->query('status'));
        return response()->json(['feedback' => $query->paginate(25)]);
    }

    public function apiUpdate(Request $request, Feedback $feedback)
    {
        $data = $request->validate([
            'status' => ['required', 'in:new,reviewing,resolved'],
            'internal_remarks' => ['nullable', 'string', 'max:5000'],
        ]);
        $updated = DB::transaction(function () use ($feedback, $data) {
            $locked = Feedback::query()->whereKey($feedback->id)->lockForUpdate()->firstOrFail();
            $locked->update($data);
            return $locked->fresh();
        });
        return response()->json(['feedback' => $updated]);
    }

    private function employeePayload(Feedback $feedback): array
    {
        return $feedback->only(['id', 'client_submission_id', 'category', 'subject', 'message', 'rating', 'status', 'created_at', 'updated_at']);
    }

    private function sameSubmission(Feedback $feedback, array $data): bool
    {
        return $feedback->category === $data['category']
            && $feedback->subject === $data['subject']
            && $feedback->message === $data['message']
            && (string) ($feedback->rating ?? '') === (string) ($data['rating'] ?? '');
    }
}
