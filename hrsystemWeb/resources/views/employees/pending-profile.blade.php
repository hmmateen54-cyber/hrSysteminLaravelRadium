<x-app-layout>
    <x-slot name="header"><h1>Profile awaiting HR completion</h1></x-slot>

    <section class="page-intro">
        <div>
            <div class="eyebrow">ACCOUNT STATUS</div>
            <h2 class="page-title">Your employee profile is pending</h2>
            <p class="page-subtitle">Your account is registered. HR must complete your employee ID, phone, department, designation, and joining date before employee features are available. Salary is not required for activation.</p>
        </div>
    </section>

    <section class="panel form-panel">
        <div class="panel-body">
            <p>Please contact your HR team. You can sign out and return after they complete your profile.</p>
            <form method="POST" action="{{ route('logout') }}">
                @csrf
                <button class="btn btn-primary" type="submit">Sign out</button>
            </form>
        </div>
    </section>
</x-app-layout>
