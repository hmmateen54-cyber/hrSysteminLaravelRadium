<?php

namespace App\Livewire;

use Laravel\Fortify\Contracts\UpdatesUserProfileInformation;
use Laravel\Jetstream\Http\Livewire\UpdateProfileInformationForm;

class DisabledProfileInformationForm extends UpdateProfileInformationForm
{
    public function updateProfileInformation(UpdatesUserProfileInformation $updater): void
    {
        abort(403, 'Profile information updates are disabled.');
    }

    public function deleteProfilePhoto(): void
    {
        abort(403, 'Profile information updates are disabled.');
    }
}
