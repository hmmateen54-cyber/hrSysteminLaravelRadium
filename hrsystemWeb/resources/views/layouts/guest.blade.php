<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <meta name="theme-color" content="#101b36">
    <title>HR Management | Secure access</title>
    @vite(['resources/css/app.css', 'resources/css/design-system.css', 'resources/js/app.js'])
    @livewireStyles
</head>
<body class="auth-body">
    <div class="auth-layout">
        <aside class="auth-story">
            <div class="auth-story-kicker"><span></span> HR MANAGEMENT WORKSPACE</div>
            <div class="auth-story-content">
                <div class="auth-story-label">YOUR TEAM, IN GOOD HANDS</div>
                <h1>People operations<br>with more clarity.</h1>
                <p>Bring employee records, attendance and leave requests together in one secure workspace.</p>
                <div class="auth-story-list"><div><span>01</span> Employee information</div><div><span>02</span> Attendance and leave</div><div><span>03</span> Performance reviews</div></div>
            </div>
            <div class="auth-story-footer"><span class="auth-story-dot"></span> A focused workspace for your people team</div>
        </aside>
        <main class="auth-main">
            <div class="auth-content">{{ $slot }}</div>
            <p class="auth-page-footer">Secure access to your HR workspace</p>
        </main>
    </div>
    @livewireScripts
</body>
</html>
