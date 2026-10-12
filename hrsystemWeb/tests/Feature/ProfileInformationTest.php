<?php

namespace Tests\Feature;

use App\Actions\Fortify\UpdateUserProfileInformation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Livewire\Livewire;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Tests\TestCase;

class ProfileInformationTest extends TestCase
{
    use RefreshDatabase;

    public function test_profile_page_shows_personal_information_without_edit_controls(): void
    {
        $user = User::factory()->create([
            'name' => 'Read Only User',
            'email' => 'readonly@example.test',
        ]);

        $this->actingAs($user)
            ->get(route('profile.show'))
            ->assertOk()
            ->assertSee('Read Only User')
            ->assertSee('readonly@example.test')
            ->assertSee('read-only')
            ->assertDontSee('wire:model="state.name"')
            ->assertDontSee('wire:model="state.email"')
            ->assertDontSee('update-profile-information-form');
    }

    public function test_profile_information_update_route_is_not_registered_or_accessible(): void
    {
        $this->assertFalse(Route::has('user-profile-information.update'));

        $user = User::factory()->create([
            'name' => 'Original User',
            'email' => 'original@example.test',
        ]);

        $this->actingAs($user)
            ->put('/user/profile-information', [
                'name' => 'Changed User',
                'email' => 'changed@example.test',
            ])
            ->assertNotFound();

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'name' => 'Original User',
            'email' => 'original@example.test',
        ]);
    }

    public function test_livewire_profile_update_and_photo_removal_are_forbidden(): void
    {
        $user = User::factory()->create([
            'name' => 'Protected User',
            'email' => 'protected@example.test',
        ]);

        $this->actingAs($user);

        Livewire::test('profile.update-profile-information-form')
            ->set('state', ['name' => 'Changed User', 'email' => 'changed@example.test'])
            ->call('updateProfileInformation')
            ->assertForbidden();

        Livewire::test('profile.update-profile-information-form')
            ->call('deleteProfilePhoto')
            ->assertForbidden();

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'name' => 'Protected User',
            'email' => 'protected@example.test',
        ]);
    }

    public function test_fortify_profile_update_action_rejects_direct_invocation(): void
    {
        $user = User::factory()->create([
            'name' => 'Original Action User',
            'email' => 'action@example.test',
        ]);

        try {
            app(UpdateUserProfileInformation::class)->update($user, [
                'name' => 'Changed Action User',
                'email' => 'changed-action@example.test',
            ]);

            $this->fail('The profile update action should reject direct calls.');
        } catch (HttpException $exception) {
            $this->assertSame(403, $exception->getStatusCode());
        }

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'name' => 'Original Action User',
            'email' => 'action@example.test',
        ]);
    }

    public function test_logout_route_remains_available(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->post(route('logout'))
            ->assertRedirect(route('home'));

        $this->assertGuest();
    }
}
