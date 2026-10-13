<?php

namespace App\Actions\Jetstream;

use App\Models\Feedback;
use App\Models\LocationEvent;
use App\Models\Project;
use App\Models\Task;
use App\Models\User;
use Illuminate\Validation\ValidationException;
use Laravel\Jetstream\Contracts\DeletesUsers;

class DeleteUser implements DeletesUsers
{
    /**
     * Delete the given user.
     */
    public function delete(User $user): void
    {
        if ($this->hasRetainedRecords($user)) {
            throw ValidationException::withMessages([
                'password' => 'This account is linked to HR or employee records and cannot be deleted here. Contact HR to suspend employee access or arrange record ownership transfer.',
            ]);
        }

        $user->deleteProfilePhoto();
        $user->tokens->each->delete();
        $user->delete();
    }

    private function hasRetainedRecords(User $user): bool
    {
        $employee = $user->employee;
        if ($employee && (
            $employee->attendances()->exists()
            || $employee->leaves()->exists()
            || $employee->performances()->exists()
            || $employee->salaries()->exists()
            || $employee->taskAssignments()->exists()
            || LocationEvent::query()->where('employee_id', $employee->getKey())->exists()
        )) {
            return true;
        }

        return Feedback::query()->where('user_id', $user->getKey())->exists()
            || Task::query()->where('created_by', $user->getKey())->exists()
            || Project::query()->where('created_by', $user->getKey())->exists();
    }
}
