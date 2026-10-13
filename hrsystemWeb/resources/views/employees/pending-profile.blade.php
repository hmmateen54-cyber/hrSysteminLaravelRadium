<x-app-layout>
    @php($pending = auth()->user()->isPendingEmployee())
    <x-slot name="header"><h1>{{ $pending ? 'Profile awaiting HR completion' : 'Account access suspended' }}</h1></x-slot>

    <section class="page-intro">
        <div>
            <div class="eyebrow">ACCOUNT STATUS</div>
            <h2 class="page-title">{{ $pending ? 'Your employee profile is pending' : 'Your employee account is suspended' }}</h2>
            <p class="page-subtitle">{{ auth()->user()->inactiveEmployeeMessage() }}</p>
        </div>
    </section>

    <section class="panel form-panel">
        <div class="panel-body">
            <p>{{ $pending ? 'You can sign out and return after HR completes your profile.' : 'Please contact your HR team if you believe this is a mistake.' }}</p>
            <form method="POST" action="{{ route('logout') }}">
                @csrf
                <button class="btn btn-primary" type="submit">Sign out</button>
            </form>
        </div>
    </section>
</x-app-layout>
