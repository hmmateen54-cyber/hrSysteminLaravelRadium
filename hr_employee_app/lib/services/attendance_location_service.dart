import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

enum AttendanceLocationIssue {
  servicesDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
  timeout,
  staleReading,
  weakAccuracy,
  invalidReading,
  unavailable,
}

class AttendanceLocationException implements Exception {
  const AttendanceLocationException(this.issue, this.message);

  final AttendanceLocationIssue issue;
  final String message;

  @override
  String toString() => message;
}

class AttendanceLocation {
  const AttendanceLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
}

class AttendanceGpsReading {
  const AttendanceGpsReading({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
}

abstract interface class AttendanceLocationSource {
  Future<bool> isLocationServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<AttendanceGpsReading> getCurrentPosition();
}

class GeolocatorAttendanceLocationSource implements AttendanceLocationSource {
  const GeolocatorAttendanceLocationSource();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<AttendanceGpsReading> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: AttendanceLocationService.fixTimeout,
    );
    return AttendanceGpsReading(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      timestamp: position.timestamp,
    );
  }
}

class AttendanceLocationService {
  static const Duration fixTimeout = Duration(seconds: 20);
  static const Duration _maximumFixAge = Duration(seconds: 30);
  static const Duration _futureClockTolerance = Duration(seconds: 10);

  /// Attendance requires a fresh foreground GPS fix accurate to 100 m or better.
  static const double maximumAccuracyMeters = 100;

  AttendanceLocationService({
    AttendanceLocationSource? source,
    DateTime Function()? now,
  }) : _source = source ?? const GeolocatorAttendanceLocationSource(),
       _now = now ?? DateTime.now;

  final AttendanceLocationSource _source;
  final DateTime Function() _now;

  Future<AttendanceLocation> capture() async {
    if (!await _source.isLocationServiceEnabled()) {
      throw const AttendanceLocationException(
        AttendanceLocationIssue.servicesDisabled,
        'Device location services are turned off. Enable GPS and retry.',
      );
    }

    var permission = await _source.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _source.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const AttendanceLocationException(
        AttendanceLocationIssue.permissionPermanentlyDenied,
        'Location permission is blocked. Allow location access in app settings, then retry.',
      );
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const AttendanceLocationException(
        AttendanceLocationIssue.permissionDenied,
        'Location permission is required for attendance. No attendance was recorded.',
      );
    }

    try {
      final position = await _source.getCurrentPosition();
      return _validate(position, _now().toUtc());
    } on TimeoutException {
      throw const AttendanceLocationException(
        AttendanceLocationIssue.timeout,
        'GPS did not provide a location in time. Move to a clearer area and retry.',
      );
    } on LocationServiceDisabledException {
      throw const AttendanceLocationException(
        AttendanceLocationIssue.servicesDisabled,
        'Device location services are turned off. Enable GPS and retry.',
      );
    } on PermissionDeniedException {
      throw const AttendanceLocationException(
        AttendanceLocationIssue.permissionDenied,
        'Location permission is required for attendance. No attendance was recorded.',
      );
    } on AttendanceLocationException {
      rethrow;
    } catch (_) {
      throw const AttendanceLocationException(
        AttendanceLocationIssue.unavailable,
        'Unable to get a current GPS reading. No attendance was recorded.',
      );
    }
  }

  AttendanceLocation _validate(AttendanceGpsReading position, DateTime nowUtc) {
    final latitude = position.latitude;
    final longitude = position.longitude;
    final accuracy = position.accuracyMeters;
    final capturedAt = position.timestamp.toUtc();

    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        !accuracy.isFinite ||
        accuracy < 0) {
      throw const AttendanceLocationException(
        AttendanceLocationIssue.invalidReading,
        'The device returned an invalid GPS reading. No attendance was recorded.',
      );
    }

    final age = nowUtc.difference(capturedAt);
    if (age > _maximumFixAge || age < -_futureClockTolerance) {
      throw const AttendanceLocationException(
        AttendanceLocationIssue.staleReading,
        'GPS returned an old or incorrectly timed reading. Retry to get a fresh location.',
      );
    }

    if (accuracy > maximumAccuracyMeters) {
      final reported = math.max(0, accuracy).round();
      throw AttendanceLocationException(
        AttendanceLocationIssue.weakAccuracy,
        'GPS accuracy is about ${reported}m; attendance needs ${maximumAccuracyMeters.round()}m or better. Move to an open area and retry.',
      );
    }

    return AttendanceLocation(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracy,
      capturedAt: capturedAt,
    );
  }
}
