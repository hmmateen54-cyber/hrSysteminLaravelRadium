<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>{{ isset($header) ? strip_tags($header) . ' | ' : '' }}HR Management</title>
    <link rel="preconnect" href="https://fonts.bunny.net">
    <link href="https://fonts.bunny.net/css?family=montserrat:400,500,600,700&display=swap" rel="stylesheet">
    @vite(['resources/css/app.css', 'resources/js/app.js'])
    @livewireStyles
</head>
<body class="font-sans antialiased">
    <x-banner />
    @php($role = auth()->user()->role)
    <div class="app-shell">
        <aside class="sidebar">
            <a class="brand" href="{{ route('dashboard') }}">
                <span class="brand-mark">HR</span>
                <span><strong>HR Management</strong><small>People operations</small></span>
            </a>
            <div class="nav-caption">WORKSPACE</div>
            <nav class="side-nav" aria-label="Main navigation">
                <a class="side-link {{ request()->routeIs('dashboard', '*.dashboard') ? 'is-active' : '' }}" href="{{ route('dashboard') }}"><span class="nav-icon">OV</span><span>Dashboard</span></a>
                @if(in_array($role, ['admin', 'hr'], true))
                    <a class="side-link {{ request()->routeIs('employees.*') ? 'is-active' : '' }}" href="{{ route('employees.index') }}"><span class="nav-icon">EM</span><span>Employees</span></a>
                    <a class="side-link {{ request()->routeIs('attendances.*') ? 'is-active' : '' }}" href="{{ route('attendances.index') }}"><span class="nav-icon">AT</span><span>Attendance</span></a>
                    <a class="side-link {{ request()->routeIs('location-events.*') ? 'is-active' : '' }}" href="{{ route('location-events.index') }}"><span class="nav-icon">LC</span><span>Location status</span></a>
                    <a class="side-link {{ request()->routeIs('leaves.*') ? 'is-active' : '' }}" href="{{ route('leaves.index') }}"><span class="nav-icon">LV</span><span>Leaves</span>@if(($pendingSidebarCount ?? 0) > 0)<span class="nav-count">{{ $pendingSidebarCount }}</span>@endif</a>
                    <a class="side-link {{ request()->routeIs('performances.*') ? 'is-active' : '' }}" href="{{ route('performances.index') }}"><span class="nav-icon">PR</span><span>Performance</span></a>
                    <a class="side-link {{ request()->routeIs('salaries.*') ? 'is-active' : '' }}" href="{{ route('salaries.index') }}"><span class="nav-icon">$</span><span>Salaries</span></a>
                    <a class="side-link {{ request()->routeIs('tasks.*', 'projects.*') ? 'is-active' : '' }}" href="{{ route('tasks.index') }}"><span class="nav-icon">TK</span><span>Projects &amp; tasks</span></a>
                    <a class="side-link {{ request()->routeIs('feedback.*') ? 'is-active' : '' }}" href="{{ route('feedback.index') }}"><span class="nav-icon">FB</span><span>Feedback</span></a>
                @else
                    <a class="side-link {{ request()->routeIs('employee.leaves.index') ? 'is-active' : '' }}" href="{{ route('employee.leaves.index') }}"><span class="nav-icon">LV</span><span>My Leaves</span></a>
                    <a class="side-link {{ request()->routeIs('employee.leave.create') ? 'is-active' : '' }}" href="{{ route('employee.leave.create') }}"><span class="nav-icon">＋</span><span>Request Leave</span></a>
                    <a class="side-link {{ request()->routeIs('employee.performance.*') ? 'is-active' : '' }}" href="{{ route('employee.performance.index') }}"><span class="nav-icon">PR</span><span>My Performance</span></a>
                    <a class="side-link {{ request()->routeIs('employee.tasks.*') ? 'is-active' : '' }}" href="{{ route('employee.tasks.index') }}"><span class="nav-icon">TK</span><span>My Tasks</span></a>
                    <a class="side-link {{ request()->routeIs('employee.feedback.*') ? 'is-active' : '' }}" href="{{ route('employee.feedback.index') }}"><span class="nav-icon">FB</span><span>Feedback</span></a>
                    <a class="side-link {{ request()->routeIs('my-salary.*') ? 'is-active' : '' }}" href="{{ route('my-salary.index') }}"><span class="nav-icon">$</span><span>My Salary</span></a>
                @endif
            </nav>
            <div class="sidebar-bottom">
                <div class="sidebar-note"><span class="online-dot"></span><span><strong>Workspace active</strong><small>People operations</small></span></div>
                <div class="sidebar-user"><span class="avatar">{{ mb_substr(auth()->user()->name, 0, 1) }}</span><span class="user-meta"><strong>{{ auth()->user()->name }}</strong><small>{{ ucfirst($role) }} account</small></span><a class="logout-link" href="{{ route('profile.show') }}" aria-label="Profile settings">···</a></div>
            </div>
        </aside>

        <div class="main-column">
            <header class="topbar">
                <div class="topbar-left">
                    <details class="mobile-menu">
                        <summary aria-label="Open navigation">☰</summary>
                        <nav>
                            <a href="{{ route('dashboard') }}">Dashboard</a>
                            @if(in_array($role, ['admin', 'hr'], true))
                                <a href="{{ route('employees.index') }}">Employees</a><a href="{{ route('attendances.index') }}">Attendance</a><a href="{{ route('location-events.index') }}">Location status</a><a href="{{ route('leaves.index') }}">Leaves</a><a href="{{ route('performances.index') }}">Performance</a><a href="{{ route('salaries.index') }}">Salaries</a><a href="{{ route('tasks.index') }}">Projects &amp; tasks</a><a href="{{ route('feedback.index') }}">Feedback</a>
                            @else
                                <a href="{{ route('employee.leaves.index') }}">My Leaves</a><a href="{{ route('employee.leave.create') }}">Request Leave</a><a href="{{ route('employee.performance.index') }}">My Performance</a><a href="{{ route('employee.tasks.index') }}">My Tasks</a><a href="{{ route('employee.feedback.index') }}">Feedback</a><a href="{{ route('my-salary.index') }}">My Salary</a>
                            @endif
                        </nav>
                    </details>
                    <span class="topbar-context">People operations <span>/</span> {{ ucfirst($role) }} workspace</span>
                </div>
                <div class="topbar-right">
                    <span class="topbar-date">{{ now()->format('D, d M Y') }}</span>
                    <span class="topbar-avatar">{{ mb_substr(auth()->user()->name, 0, 1) }}</span>
                    <span class="topbar-name">{{ auth()->user()->name }}</span>
                    <form method="POST" action="{{ route('logout') }}">@csrf<button class="text-button" type="submit">Sign out</button></form>
                </div>
            </header>

            <main class="main-content">
                @if(isset($header))<div class="page-heading">{{ $header }}</div>@endif
                @if(session('success'))<div class="alert alert-success" role="status"><span class="alert-mark">✓</span>{{ session('success') }}</div>@endif
                @if(session('error'))<div class="alert alert-error" role="alert">{{ session('error') }}</div>@endif
                {{ $slot }}
                <footer class="app-footer"><span>© {{ now()->year }} HR Management</span><span>People operations, made clear.</span></footer>
            </main>
        </div>
    </div>
    @stack('modals')
    @livewireScripts
</body>
</html>
