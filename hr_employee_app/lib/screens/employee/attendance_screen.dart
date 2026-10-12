import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../components/app_loader.dart';
import '../../components/logout_action.dart';
import '../../services/api_service.dart';
import '../../services/offline_sync_service.dart';

enum _LocationState { neutral, loading, available, waiting, uploaded, error }

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> attendance = [];
  bool loading = true;
  bool checkingIn = false;
  String? error;
  String locationMessage = 'Location has not been requested.';
  _LocationState locationState = _LocationState.neutral;
  String? locationQueueId;

  Color get _locationColor => switch (locationState) {
    _LocationState.available || _LocationState.uploaded => Colors.green,
    _LocationState.waiting => Colors.blue,
    _LocationState.error => Colors.red,
    _ => Colors.blueGrey,
  };

  IconData get _locationIcon => switch (locationState) {
    _LocationState.available || _LocationState.uploaded => Icons.location_on,
    _LocationState.waiting => Icons.cloud_upload_outlined,
    _LocationState.loading => Icons.hourglass_top,
    _LocationState.error => Icons.location_off,
    _ => Icons.location_searching,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    getAttendance();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshLocationStatus());
      unawaited(OfflineSyncService.syncPendingLeaves());
      unawaited(getAttendance());
    }
  }

  Future<void> _refreshLocationStatus() async {
    final id = locationQueueId;
    if (id == null) return;

    try {
      final rows = await OfflineSyncService.getQueueItems(
        operation: 'location',
      );
      final matches = rows.where((row) => row['queue_id'] == id);

      if (matches.isEmpty || !mounted) return;

      final item = matches.first;
      final status = item['sync_status'];

      setState(() {
        if (status == 'synced') {
          locationState = _LocationState.uploaded;
          locationMessage = 'Location uploaded to the server.';
        } else if (status == 'failed') {
          locationState = _LocationState.error;
          locationMessage =
              item['last_error']?.toString() ?? 'Location upload failed.';
        } else {
          locationState = _LocationState.waiting;
          locationMessage = 'Location saved offline — waiting to sync.';
        }
      });
    } catch (_) {
      // Keep the last known location status.
    }
  }

  Future<void> getAttendance() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    List<Map<String, dynamic>> local = [];

    try {
      local = await OfflineSyncService.getQueueItems(
        operation: 'attendance',
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Offline attendance storage is unavailable.';
        });
      }
    }

    try {
      final response = await ApiService.get('/employee/attendance');

      if (!mounted) return;

      if (ApiService.isSuccess(response['status']) &&
          response['data'] is Map) {
        final records = response['data']['attendance'];

        final remote = records is List
            ? records
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
            : <Map<String, dynamic>>[];

        final localOnly = local.where((item) {
          return !remote.any((row) {
            final sameDate =
                row['attendance_date']?.toString().substring(0, 10) ==
                item['attendance_date']?.toString().substring(0, 10);

            final localCheckIn = item['check_in']?.toString() ?? '';
            final remoteCheckIn = row['check_in']?.toString() ?? '';
            final sameCheckIn = localCheckIn.isNotEmpty &&
                remoteCheckIn.startsWith(localCheckIn);

            return sameDate && sameCheckIn;
          });
        }).toList();

        setState(() {
          attendance = [...localOnly, ...remote];
          loading = false;
        });
      } else {
        final data = response['data'];

        setState(() {
          attendance = local;
          error = data is Map
              ? data['message']?.toString() ??
                    ApiService.messageForStatus(response['status'])
              : ApiService.messageForStatus(response['status']);
          loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        attendance = local;
        error =
            'Unable to reach the server. Saved attendance remains on this device.';
        loading = false;
      });
    }
  }

  Future<void> handleCheckIn() async {
    if (checkingIn) return;

    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final alreadyCheckedIn = attendance.any((record) {
      return record['attendance_date']?.toString().startsWith(date) == true;
    });

    if (alreadyCheckedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already checked in today.'),
        ),
      );
      return;
    }

    setState(() => checkingIn = true);

    try {
      final time =
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:00';

      final queueId = await OfflineSyncService.queueAttendance(
        attendanceDate: date,
        checkIn: time,
      );

      await OfflineSyncService.syncPendingLeaves(force: true);

      final queued = (await OfflineSyncService.getQueueItems(
        operation: 'attendance',
      )).where((row) => row['queue_id'] == queueId);

      final status = queued.isEmpty ? 'synced' : queued.first['sync_status'];

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'synced'
                ? 'Check-in confirmed by the server.'
                : status == 'failed'
                ? 'Attendance sync failed. Please check your connection.'
                : 'Check-in saved on this device and waiting to sync.',
          ),
        ),
      );

      await getAttendance();
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().contains(
        'Attendance already exists for this date',
      )
          ? 'You have already checked in today.'
          : 'Could not save check-in on this device.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => checkingIn = false);
      }
    }
  }

  Future<bool> _explainLocationUse() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Share your location?'),
            content: const Text(
              'Your precise location will be saved with the time of this request for the HR attendance feature. It is only collected after you continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> handleLocationAction() async {
    if (locationState == _LocationState.loading) return;
    if (!await _explainLocationUse() || !mounted) return;

    setState(() {
      locationState = _LocationState.loading;
      locationMessage = 'Checking permission and device location…';
    });

    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        final openSettings = await _showLocationIssue(
          'Location permission is blocked. Open app settings to allow location access.',
          action: 'Open settings',
        );

        if (openSettings) await Geolocator.openAppSettings();

        _setLocationError(
          'Location permission is denied. Allow it in app settings and try again.',
        );
        return;
      }

      if (permission == LocationPermission.denied) {
        _setLocationError(
          'Location permission was denied. No location was collected.',
        );
        return;
      }

      final enabled = await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        final openSettings = await _showLocationIssue(
          'Device location services are turned off. Enable them to get your current location.',
          action: 'Location settings',
        );

        if (openSettings) await Geolocator.openLocationSettings();

        _setLocationError(
          'Device location services are disabled. No location was collected.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) return;

      setState(() {
        locationState = _LocationState.available;
        locationMessage = 'A current location was obtained. Saving the event…';
      });

      final queuedId = await OfflineSyncService.queueLocationEvent(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        recordedAt: position.timestamp,
      );

      locationQueueId = queuedId;

      await OfflineSyncService.syncPendingLeaves(force: true);
      await _refreshLocationStatus();
    } catch (_) {
      _setLocationError(
        'Unable to get a current location. No location event was saved.',
      );
    }
  }

  Future<bool> _showLocationIssue(
    String message, {
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location unavailable'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _setLocationError(String message) {
    if (!mounted) return;

    setState(() {
      locationState = _LocationState.error;
      locationMessage = message;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        actions: const [LogoutAction()],
      ),
      body: loading
          ? const AppLoader()
          : Column(
              children: [
                if (error != null)
                  MaterialBanner(
                    content: Text(error!),
                    leading: const Icon(Icons.cloud_off),
                    actions: [
                      TextButton(
                        onPressed: getAttendance,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(_locationIcon, color: _locationColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                locationMessage,
                                style: TextStyle(color: _locationColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: locationState == _LocationState.loading
                              ? null
                              : handleLocationAction,
                          icon: locationState == _LocationState.loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location),
                          label: const Text('Share Location'),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: attendance.isEmpty
                      ? RefreshIndicator(
                          onRefresh: getAttendance,
                          child: ListView(
                            children: const [
                              SizedBox(height: 150),
                              Center(
                                child: Text('No attendance records found'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: getAttendance,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: attendance.length,
                            itemBuilder: (context, index) {
                              final record = attendance[index];
                              final local = record.containsKey('sync_status');

                              final syncStatus =
                                  record['sync_status']?.toString();

                              final status = local
                                  ? syncStatus == 'synced'
                                        ? 'Server confirmed'
                                        : syncStatus == 'retry'
                                        ? 'Waiting to retry'
                                        : syncStatus == 'failed'
                                        ? 'Sync failed'
                                        : 'Waiting to sync'
                                  : (record['status'] ?? 'present').toString();

                              final color = local
                                  ? syncStatus == 'synced'
                                        ? Colors.blue
                                        : syncStatus == 'failed'
                                        ? Colors.red
                                        : Colors.amber
                                  : Colors.blue;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: color.withValues(
                                      alpha: .12,
                                    ),
                                    child: Icon(
                                      Icons.calendar_month,
                                      color: color,
                                    ),
                                  ),
                                  title: Text(
                                    record['attendance_date']?.toString() ??
                                        '-',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Check in: ${record['check_in'] ?? '-'}\n'
                                    '${local ? 'Saved on this device.' : 'Check out: ${record['check_out'] ?? '-'}'}',
                                  ),
                                  trailing: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: checkingIn ? null : handleCheckIn,
        icon: checkingIn
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.fingerprint),
        label: Text(checkingIn ? 'Saving…' : 'Check In'),
      ),
    );
  }
}
