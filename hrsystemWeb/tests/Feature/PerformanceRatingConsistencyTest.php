<?php

namespace Tests\Feature;

use App\Models\Employee;
use App\Models\Performance;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PerformanceRatingConsistencyTest extends TestCase
{
    use RefreshDatabase;

    public function test_web_and_mobile_reviews_accept_the_same_zero_to_ten_rating_scale(): void
    {
        $hr = User::factory()->create(['role' => 'hr']);
        $employeeUser = User::factory()->create(['role' => 'employee']);
        $employee = Employee::create([
            'user_id' => $employeeUser->id,
            'employee_id' => 'EMP-RATING',
        ]);
        $base = [
            'employee_id' => $employee->id,
            'review_date' => '2026-10-13',
            'comments' => 'Consistent rating scale.',
        ];

        $this->actingAs($hr)->post(route('performances.store'), $base + ['rating' => '0'])
            ->assertRedirect(route('performances.index'));
        $this->post(route('performances.store'), $base + ['rating' => '10'])
            ->assertRedirect(route('performances.index'));
        $this->post(route('performances.store'), $base + ['rating' => '10.1'])
            ->assertSessionHasErrors('rating');

        $this->assertSame(2, Performance::count());
        $this->assertSame('0.0', Performance::oldest('id')->firstOrFail()->rating);
        $this->assertSame('10.0', Performance::latest('id')->firstOrFail()->rating);

        $token = $hr->createToken('rating-contract')->plainTextToken;
        $this->withToken($token)
            ->postJson('/api/hr/performance', $base + ['rating' => '0'])
            ->assertCreated();
        $this->postJson('/api/hr/performance', $base + ['rating' => '10'])
            ->assertCreated();
        $this->postJson('/api/hr/performance', $base + ['rating' => '10.1'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('rating');

        $this->assertSame(4, Performance::count());
    }
}
