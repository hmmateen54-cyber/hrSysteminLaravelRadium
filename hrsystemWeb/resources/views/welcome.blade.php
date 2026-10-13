<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="#f5f7fb">
    <title>HR Management · People operations</title>
    @vite(['resources/css/app.css', 'resources/css/design-system.css', 'resources/js/app.js'])
</head>
<body class="landing-body">
    <div class="landing-page">
        <header class="landing-nav">
            <a class="landing-brand" href="{{ route('home') }}">
                <span class="landing-brand-mark">HR</span>
                <span>HR Management</span>
            </a>
            <nav class="landing-nav-actions" aria-label="Account navigation">
                @guest
                    <a class="landing-signin" href="{{ route('login') }}">Sign in</a>
                    <a class="landing-btn landing-btn-primary" href="{{ route('register') }}">Create account <span aria-hidden="true">→</span></a>
                @else
                    <a class="landing-btn landing-btn-primary" href="{{ route('dashboard') }}">Open dashboard <span aria-hidden="true">→</span></a>
                @endguest
            </nav>
        </header>

        <main>
            <section class="landing-hero">
                <div class="landing-copy">
                    <div class="landing-eyebrow"><span></span> PEOPLE OPERATIONS, MADE CLEAR</div>
                    <h1>Good work starts with <span>good people operations.</span></h1>
                    <p class="landing-lead">Manage employees, attendance, leaves and HR operations in one considered workspace built for your team.</p>
                    <div class="landing-hero-actions">
                        @guest
                            <a class="landing-btn landing-btn-primary landing-btn-large" href="{{ route('login') }}">Log in to your workspace <span aria-hidden="true">→</span></a>
                            <a class="landing-btn landing-btn-outline landing-btn-large" href="{{ route('register') }}">Create an account</a>
                        @else
                            <a class="landing-btn landing-btn-primary landing-btn-large" href="{{ route('dashboard') }}">Go to dashboard <span aria-hidden="true">→</span></a>
                        @endguest
                    </div>
                    <div class="landing-assurance"><span class="landing-check">✓</span> One secure place for your team's essential HR work</div>
                </div>

                <div class="landing-preview" aria-label="HR workspace preview">
                    <div class="preview-glow"></div>
                    <div class="preview-window">
                        <div class="preview-topbar"><div class="preview-dots"><i></i><i></i><i></i></div><span>TEAM WORKSPACE</span><span class="preview-live"><i></i> Ready</span></div>
                        <div class="preview-content">
                            <div class="preview-greeting"><div><span>YOUR PEOPLE, IN VIEW</span><strong>HR workspace</strong></div><span class="preview-avatar">HR</span></div>
                            <div class="preview-summary">
                                <div class="preview-summary-card"><span class="preview-card-icon">01</span><span>Employee records</span><small>Profiles and team details</small></div>
                                <div class="preview-summary-card"><span class="preview-card-icon preview-card-icon-green">02</span><span>Attendance</span><small>Daily team visibility</small></div>
                                <div class="preview-summary-card"><span class="preview-card-icon preview-card-icon-amber">03</span><span>Leave requests</span><small>Clear review and decisions</small></div>
                            </div>
                            <div class="preview-activity"><div class="preview-activity-head"><span>Built around your workflow</span><span>HRMS</span></div><div class="preview-activity-row"><span class="preview-activity-mark">✓</span><span>One shared view for essential people operations</span></div><div class="preview-activity-row"><span class="preview-activity-mark preview-mark-muted">↗</span><span>Role based access for every team member</span></div></div>
                        </div>
                    </div>
                    <div class="preview-float"><span class="preview-float-mark">✓</span><span><strong>Everything in one place</strong><small>A more organized workday</small></span></div>
                </div>
            </section>

            <section class="landing-capabilities">
                <div class="landing-section-heading"><span>THE WORKSPACE</span><h2>Less admin. More clarity.</h2><p>Keep the everyday work of supporting your team organized and easy to follow.</p></div>
                <div class="landing-feature-grid">
                    <article class="landing-feature"><span class="landing-feature-icon">PE</span><h3>People records</h3><p>Keep employee profiles and important work details together.</p></article>
                    <article class="landing-feature"><span class="landing-feature-icon landing-feature-green">AT</span><h3>Attendance tracking</h3><p>Record daily attendance and find team history when you need it.</p></article>
                    <article class="landing-feature"><span class="landing-feature-icon landing-feature-amber">LV</span><h3>Leave management</h3><p>Make requests and review decisions clear for everyone.</p></article>
                </div>
            </section>
        </main>

        <footer class="landing-footer"><a class="landing-brand landing-brand-footer" href="{{ route('home') }}"><span class="landing-brand-mark">HR</span><span>HR Management</span></a><span>People operations, made clear.</span></footer>
    </div>
</body>
</html>
