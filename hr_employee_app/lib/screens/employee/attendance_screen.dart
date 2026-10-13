import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../components/app_loader.dart';
import '../../components/logout_action.dart';
import '../../components/offline_cache_banner.dart';
import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';
import '../../services/offline_sync_service.dart';

enum _LocationState { neutral, loading, available, waiting, uploaded, error }

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with WidgetsBindingObserver {
  late final AutoRefreshController _autoRefresh;
  bool _requestInFlight = false;
  bool _refreshQueued = false;
  bool _hasLoaded = false;
  List<Map<String, dynamic>> attendance = [];
  bool loading = true;
  bool checkingIn = false;
  String? error;
  String? _cacheFetchedAt;
  bool _hasCachedData = false;
  bool _offlineMode = false;
  String locationMessage = 'Location has not been requested.';
  _LocationState locationState = _LocationState.neutral;
  String? locationQueueId;

  Color get _locationColor => switch (locationState) {
    _LocationState.uploaded => Colors.green,
    _LocationState.available || _LocationState.waiting => Colors.amber.shade800,
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
    _autoRefresh = AutoRefreshController(owner: this, onRefresh: getAttendance)
      ..start();
    OfflineSyncService.queueRevision.addListener(_onQueueChanged);
    getAttendance();
    _refreshLocationStatus();
  }

  void _onQueueChanged() => unawaited(getAttendance());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshLocationStatus());
      unawaited(OfflineSyncService.syncPendingLeaves());
      unawaited(getAttendance());
    }
  }

  Future<void> _refreshLocationStatus() async {
    try {
      final rows = await OfflineSyncService.getQueueItems(
        operation: 'location',
      );
      if (rows.isEmpty || !mounted) return;
      final item = rows.firstWhere(
        (row) => row['queue_id'] == locationQueueId,
        orElse: () => rows.first,
      );
      locationQueueId = item['queue_id']?.toString();
      final status = item['sync_status'];

      setState(() {
        if (status == 'synced') {
          locationState = _LocationState.uploaded;
          final syncedAt = DateTime.tryParse(
            item['synced_at']?.toString() ?? '',
          );
          locationMessage = syncedAt == null
              ? 'Location confirmed by the server.'
              : 'Location confirmed by the server at ${syncedAt.toLocal()}.';
        } else if (status == 'failed') {
          locationState = _LocationState.waiting;
          locationMessage =
              'Location needs attention: '
              '${item['last_error']?.toString() ?? 'sync failed'}';
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
    if (_requestInFlight) {
      _refreshQueued = true;
      return;
    }
    _requestInFlight = true;
    if (!_hasLoaded && !loading) setState(() => loading = true);

    List<Map<String, dynamic>> local = [];
    String? localStorageError;

    try {
      local = await OfflineSyncService.getQueueItems(operation: 'attendance');
    } catch (_) {
      localStorageError = 'Offline attendance storage is unavailable.';
      if (mounted && !_hasLoaded) {
        setState(() {
          error = localStorageError;
        });
      }
    }

    Map<String, dynamic>? cached;
    try {
      cached = await OfflineSyncService.readCachedItems('attendance');
    } catch (_) {
      localStorageError ??= 'Offline attendance history is unavailable.';
    }
    final cachedRemote =
        (cached?['items'] as List?)
            ?.whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList() ??
        <Map<String, dynamic>>[];
    if (cached != null && mounted) {
      setState(() {
        attendance = _mergeAttendance(local, cachedRemote);
        _cacheFetchedAt = cached?['fetched_at']?.toString();
        _hasCachedData = true;
        loading = false;
        _hasLoaded = true;
      });
    }

    try {
      final response = await ApiService.get('/employee/attendance');

      if (!mounted) return;

      if (ApiService.isSuccess(response['status']) && response['data'] is Map) {
        final records = response['data']['attendance'];

        final remote = records is List
            ? records
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
            : <Map<String, dynamic>>[];

        try {
          await OfflineSyncService.saveCachedItems('attendance', remote);
          final savedCache = await OfflineSyncService.readCachedItems(
            'attendance',
          );
          _cacheFetchedAt = savedCache?['fetched_at']?.toString();
          _hasCachedData = true;
        } catch (_) {
          // Keep the live response usable if local caching fails.
        }

        final merged = _mergeAttendance(local, remote);

        setState(() {
          attendance = merged;
          loading = false;
          error = localStorageError;
          _offlineMode = false;
          _hasLoaded = true;
        });
      } else {
        final data = response['data'];

        setState(() {
          final currentRemote = attendance
              .where((row) => !row.containsKey('sync_status'))
              .toList();
          attendance = _mergeAttendance(local, currentRemote);
          error =
              localStorageError ??
              (data is Map
                  ? data['message']?.toString() ??
                        ApiService.messageForStatus(response['status'])
                  : ApiService.messageForStatus(response['status']));
          _offlineMode =
              _hasCachedData &&
              (response['status'] == 429 ||
                  (response['status'] is int && response['status'] >= 500));
          loading = false;
          _hasLoaded = true;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        final currentRemote = attendance
            .where((row) => !row.containsKey('sync_status'))
            .toList();
        attendance = _mergeAttendance(local, currentRemote);
        error =
            localStorageError ??
            'Unable to reach the server. Saved attendance remains on this device.';
        _offlineMode = _hasCachedData;
        loading = false;
        _hasLoaded = true;
      });
    } finally {
      _requestInFlight = false;
      if (_refreshQueued && mounted) {
        _refreshQueued = false;
        unawaited(Future<void>.delayed(Duration.zero, getAttendance));
      }
    }
  }

  List<Map<String, dynamic>> _mergeAttendance(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> remote,
  ) {
    final localOnly = local.where((item) {
      final clientId = item['client_id']?.toString();
      return clientId == null ||
          !remote.any((row) => row['sync_id']?.toString() == clientId);
    });
    final merged = <Map<String, dynamic>>[...localOnly, ...remote];
    merged.sort(
      (a, b) => (b['attendance_date']?.toString() ?? '').compareTo(
        a['attendance_date']?.toString() ?? '',
      ),
    );
    return merged;
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
        const SnackBar(content: Text('You have already checked in today.')),
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

      final message =
          e.toString().contains('Attendance already exists for this date')
          ? 'You have already checked in today.'
          : 'Could not save check-in on this device.';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
    _autoRefresh.dispose();
    OfflineSyncService.queueRevision.removeListener(_onQueueChanged);
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
                if (_offlineMode)
                  OfflineCacheBanner(
                    fetchedAt: _cacheFetchedAt,
                    onRetry: () async {
                      await OfflineSyncService.syncPendingLeaves(force: true);
                      await getAttendance();
                    },
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
                        if (locationState == _LocationState.waiting) ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: () async {
                              await OfflineSyncService.syncPendingLeaves(
                                force: true,
                              );
                              await _refreshLocationStatus();
                            },
                            icon: const Icon(Icons.sync),
                            label: const Text('Retry location sync'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: attendance.isEmpty
                      ? RefreshIndicator(
                          onRefresh: getAttendance,
                          child: ListView(
                            children: [
                              if (_offlineMode)
                                OfflineCacheBanner(
                                  fetchedAt: _cacheFetchedAt,
                                  onRetry: getAttendance,
                                ),
                              const SizedBox(height: 150),
                              const Center(
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

                              final syncStatus = record['sync_status']
                                  ?.toString();

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
