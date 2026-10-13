<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Fortify\TwoFactorAuthenticatable;
use Laravel\Jetstream\HasProfilePhoto;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens;

    public const PENDING_PROFILE_MESSAGE = 'Your account is registered, but your employee profile is awaiting HR completion. You will be able to log in once HR completes your profile.';

    public const SUSPENDED_ACCOUNT_MESSAGE = 'Your employee account is suspended. Please contact HR to restore access.';

    /** @use HasFactory<UserFactory> */
    use HasFactory;

    use HasProfilePhoto;
    use Notifiable;
    use TwoFactorAuthenticatable;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'account_status',
    ];

    public function employee()
    {
        return $this->hasOne(Employee::class, 'user_id');
    }

    public function isPendingEmployee(): bool
    {
        return $this->role === 'employee' && $this->account_status === 'pending';
    }

    public function isInactiveEmployee(): bool
    {
        // A null value on a just-created model still means the database default
        // applies; pending and suspended employees are both blocked from access.
        return $this->role === 'employee'
            && $this->account_status !== null
            && $this->account_status !== 'active';
    }

    public function inactiveEmployeeMessage(): string
    {
        return match ($this->account_status) {
            'pending' => self::PENDING_PROFILE_MESSAGE,
            'suspended' => self::SUSPENDED_ACCOUNT_MESSAGE,
            default => 'Your employee account is inactive. Please contact HR.',
        };
    }

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
        'remember_token',
        'two_factor_recovery_codes',
        'two_factor_secret',
    ];

    /**
     * The accessors to append to the model's array form.
     *
     * @var array<int, string>
     */
    protected $appends = [
        'profile_photo_url',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }
}
