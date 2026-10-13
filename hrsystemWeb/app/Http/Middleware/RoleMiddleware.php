<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RoleMiddleware
{
    public function handle(Request $request, Closure $next, ...$roles): Response
    {
        $user = $request->user();

        if (! $user) {
            return redirect()->route('login');
        }

        if (! in_array($user->role, $roles, true)) {
            abort(403, 'Unauthorized');
        }

        if ($user->isInactiveEmployee()) {
            $message = 'Your account is registered, but your employee profile is awaiting HR completion. You will be able to log in once HR completes your profile.';

            if ($request->expectsJson()) {
                return response()->json(['message' => $message], 403);
            }

            return redirect()->route('employee.pending-profile');
        }

        return $next($request);
    }
}
