<?php

namespace Tests\Feature;

use App\Models\Attendance;
use App\Models\Employee;
use App\Models\LocationEvent;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class AttendanceIndexTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_sees_attendance_fields_and_the_check_in_location_once(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);
        [$firstUser, $firstEmployee] = $this->employee('Amina Attendance', 'EMP-801');
        [, $secondEmployee] = $this->employee('Bilal Attendance', 'EMP-802');

        $firstAttendance = $this->attendance($firstEmployee, '2026-10-14', '08:45:00', '17:10:00', 'Private attendance note');
        $secondAttendance = $this->attendance($secondEmployee, '2026-10-13', null, null);

        $this->locationEvent($firstUser, $firstEmployee, $firstAttendance, 'check_in', 'Main entrance, 25 Example Road');
        $this->locationEvent($firstUser, $firstEmployee, $firstAttendance, 'check_out', 'Exit gate, 25 Example Road');
        $this->locationEvent($secondEmployee->user, $secondEmployee, $secondAttendance, 'check_in', null);

        $response = $this->actingAs($admin)->get(route('attendances.index'));

        $response->assertOk()
            ->assertSee('Employee Name')
            ->assertSee('Attendance Date')
            ->assertSee('Status')
            ->assertSee('Check In')
            ->assertSee('Check Out')
            ->assertSee('Location Address')
            ->assertSee('Amina Attendance')
            ->assertSee('Bilal Attendance')
            ->assertSee('14 Oct 2026')
            ->assertSee('Present')
            ->assertSee('08:45')
            ->assertSee('17:10')
            ->assertSee('Main entrance, 25 Example Road')
            ->assertSee('Address unavailable')
            ->assertSee('—')
            ->assertDontSee('Exit gate, 25 Example Road')
            ->assertDontSee('Private attendance note')
            ->assertDontSee('<th>Remarks</th>', false)
            ->assertDontSee('<th>Employee ID</th>', false);

        $this->assertSame(3, substr_count($response->getContent(), '<tr>'), 'The table should contain a header and exactly one row per attendance record.');
    }

    public function test_admin_sees_an_empty_state_when_no_attendance_exists(): void
    {
        $admin = User::factory()->create(['role' => 'admin']);

        $this->actingAs($admin)
            ->get(route('attendances.index'))
            ->assertOk()
            ->assertSee('No attendance records');
    }

    private function employee(string $name, string $employeeId): array
    {
        $user = User::factory()->create(['name' => $name, 'role' => 'employee']);
        $employee = Employee::create([
            'user_id' => $user->id,
            'employee_id' => $employeeId,
        ]);

        return [$user, $employee];
    }

    private function attendance(Employee $employee, string $date, ?string $checkIn, ?string $checkOut, ?string $remarks = null): Attendance
    {
        return Attendance::create([
            'employee_id' => $employee->id,
            'attendance_date' => $date,
            'status' => 'present',
            'check_in' => $checkIn,
            'check_out' => $checkOut,
            'remarks' => $remarks,
        ]);
    }

    private function locationEvent(User $user, Employee $employee, Attendance $attendance, string $eventType, ?string $address): LocationEvent
    {
        return LocationEvent::create([
            'user_id' => $user->id,
            'employee_id' => $employee->id,
            'attendance_id' => $attendance->id,
            'client_event_id' => (string) Str::uuid(),
            'event_type' => $eventType,
            'latitude' => 24.8607000,
            'longitude' => 67.0011000,
            'address' => $address,
            'recorded_at' => '2026-10-14 08:45:00',
            'action_at' => '2026-10-14 08:45:00',
        ]);
    }
}
