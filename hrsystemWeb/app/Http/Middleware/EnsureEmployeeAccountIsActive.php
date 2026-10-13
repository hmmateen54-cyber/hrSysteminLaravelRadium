<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureEmployeeAccountIsActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || ! $user->isInactiveEmployee()) {
            return $next($request);
        }

        // Pending employees need access to the status page and logout only.
        if ($request->routeIs('employee.pending-profile', 'logout')) {
            return $next($request);
        }

        if ($request->expectsJson()) {
            return response()->json([
                'message' => 'Your account is registered, but your employee profile is awaiting HR completion. You will be able to log in once HR completes your profile.',
            ], 403);
        }

        return redirect()->route('employee.pending-profile');
    }
}
