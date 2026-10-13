import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hr_employee_app/services/attendance_location_service.dart';

void main() {
  final now = DateTime.utc(2026, 10, 13, 12);

  test('requests permission before obtaining a GPS fix', () async {
    final source = _FakeLocationSource(
      permission: LocationPermission.denied,
      requestedPermission: LocationPermission.whileInUse,
      reading: AttendanceGpsReading(
        latitude: 24.8607,
        longitude: 67.0011,
        accuracyMeters: 8.5,
        timestamp: now.subtract(const Duration(seconds: 3)),
      ),
    );
    final service = AttendanceLocationService(source: source, now: () => now);

    final result = await service.capture();

    expect(source.permissionRequests, 1);
    expect(source.fixRequests, 1);
    expect(result.latitude, 24.8607);
    expect(result.longitude, 67.0011);
    expect(result.accuracyMeters, 8.5);
    expect(result.capturedAt, now.subtract(const Duration(seconds: 3)));
  });

  test(
    'denied permission prevents a location fix from being accepted',
    () async {
      final source = _FakeLocationSource(
        permission: LocationPermission.denied,
        requestedPermission: LocationPermission.denied,
      );
      final service = AttendanceLocationService(source: source, now: () => now);

      await expectLater(
        service.capture(),
        throwsA(
          isA<AttendanceLocationException>().having(
            (exception) => exception.issue,
            'issue',
            AttendanceLocationIssue.permissionDenied,
          ),
        ),
      );
      expect(source.fixRequests, 0);
    },
  );

  test(
    'permanently denied permission is surfaced without requesting a fix',
    () async {
      final source = _FakeLocationSource(
        permission: LocationPermission.deniedForever,
      );
      final service = AttendanceLocationService(source: source, now: () => now);

      await expectLater(
        service.capture(),
        throwsA(
          isA<AttendanceLocationException>().having(
            (exception) => exception.issue,
            'issue',
            AttendanceLocationIssue.permissionPermanentlyDenied,
          ),
        ),
      );
      expect(source.fixRequests, 0);
    },
  );

  test('disabled location services stop attendance capture', () async {
    final source = _FakeLocationSource(servicesEnabled: false);
    final service = AttendanceLocationService(source: source, now: () => now);

    await expectLater(
      service.capture(),
      throwsA(
        isA<AttendanceLocationException>().having(
          (exception) => exception.issue,
          'issue',
          AttendanceLocationIssue.servicesDisabled,
        ),
      ),
    );
    expect(source.permissionChecks, 0);
    expect(source.fixRequests, 0);
  });

  test('weak accuracy is rejected with a retryable location issue', () async {
    final source = _FakeLocationSource(
      reading: AttendanceGpsReading(
        latitude: 24.8607,
        longitude: 67.0011,
        accuracyMeters: 180,
        timestamp: now,
      ),
    );
    final service = AttendanceLocationService(source: source, now: () => now);

    await expectLater(
      service.capture(),
      throwsA(
        isA<AttendanceLocationException>()
            .having(
              (exception) => exception.issue,
              'issue',
              AttendanceLocationIssue.weakAccuracy,
            )
            .having(
              (exception) => exception.message,
              'message',
              contains('180m'),
            ),
      ),
    );
  });

  test('stale GPS readings are rejected', () async {
    final source = _FakeLocationSource(
      reading: AttendanceGpsReading(
        latitude: 24.8607,
        longitude: 67.0011,
        accuracyMeters: 8,
        timestamp: now.subtract(const Duration(minutes: 2)),
      ),
    );
    final service = AttendanceLocationService(source: source, now: () => now);

    await expectLater(
      service.capture(),
      throwsA(
        isA<AttendanceLocationException>().having(
          (exception) => exception.issue,
          'issue',
          AttendanceLocationIssue.staleReading,
        ),
      ),
    );
  });
}

class _FakeLocationSource implements AttendanceLocationSource {
  _FakeLocationSource({
    this.servicesEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestedPermission = LocationPermission.whileInUse,
    this.reading,
  });

  final bool servicesEnabled;
  final LocationPermission permission;
  final LocationPermission requestedPermission;
  final AttendanceGpsReading? reading;
  int permissionChecks = 0;
  int permissionRequests = 0;
  int fixRequests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => servicesEnabled;

  @override
  Future<LocationPermission> checkPermission() async {
    permissionChecks++;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return requestedPermission;
  }

  @override
  Future<AttendanceGpsReading> getCurrentPosition() async {
    fixRequests++;
    return reading!;
  }
}
