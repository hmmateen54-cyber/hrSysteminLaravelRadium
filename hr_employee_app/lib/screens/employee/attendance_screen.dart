import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../components/app_loader.dart';
import '../../components/logout_action.dart';
import '../../components/offline_cache_banner.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_section_header.dart';
import '../../components/app_status_badge.dart';
import '../../services/api_service.dart';
import '../../services/attendance_location_service.dart';
import '../../services/auto_refresh_controller.dart';
import '../../services/offline_sync_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

enum _LocationState { neutral, loading, waiting, uploaded, error }

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
  bool _locationSyncFailed = false;
  final AttendanceLocationService _locationService =
      AttendanceLocationService();

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

  void _onQueueChanged() {
    unawaited(getAttendance());
    unawaited(_refreshLocationStatus());
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
    try {
      final rows = await OfflineSyncService.getQueueItems(
        operation: 'attendance',
      );
      if (rows.isEmpty || !mounted) return;
      final item = rows.firstWhere(
        (row) => row['queue_id'] == locationQueueId,
        orElse: () => rows.first,
      );
      locationQueueId = item['queue_id']?.toString();
      final status = item['sync_status'];
      final accuracy = double.tryParse(item['accuracy']?.toString() ?? '');
      final capturedAt = DateTime.tryParse(
        item['captured_at']?.toString() ??
            item['recorded_at']?.toString() ??
            '',
      );
      final action = item['action_type'] == 'check_out'
          ? 'Check-out'
          : 'Check-in';
      final details = [
        if (accuracy != null) 'GPS accuracy about ${accuracy.round()}m',
        if (capturedAt != null) 'captured ${capturedAt.toLocal()}',
      ].join(' · ');

      setState(() {
        if (status == 'synced') {
          _locationSyncFailed = false;
          locationState = _LocationState.uploaded;
          final syncedAt = DateTime.tryParse(
            item['synced_at']?.toString() ?? '',
          );
          locationMessage = syncedAt == null
              ? '$action location confirmed by the server${details.isEmpty ? '.' : ' · $details.'}'
              : '$action location confirmed by the server at ${syncedAt.toLocal()}${details.isEmpty ? '.' : ' · $details.'}';
        } else if (status == 'failed') {
          _locationSyncFailed = true;
          locationState = _LocationState.error;
          locationMessage =
              'Synchronization failed; the captured location is still saved on this device. '
              '${item['last_error']?.toString() ?? 'Retry when your connection is available.'}';
        } else {
          _locationSyncFailed = false;
          locationState = _LocationState.waiting;
          locationMessage =
              '$action location saved on this device and waiting to sync${details.isEmpty ? '.' : ' · $details.'}';
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
    final mergedByDate = <String, Map<String, dynamic>>{
      for (final row in remote)
        if (row['attendance_date'] != null)
          row['attendance_date'].toString().substring(0, 10):
              Map<String, dynamic>.from(row),
    };

    for (final item in local) {
      final rawDate = item['attendance_date']?.toString();
      if (rawDate == null || rawDate.length < 10) continue;
      final date = rawDate.substring(0, 10);
      final record = mergedByDate.putIfAbsent(
        date,
        () => {'attendance_date': date, 'status': 'present'},
      );
      final action = item['action_type']?.toString() ?? 'check_in';
      final time =
          item['action_time']?.toString() ?? item['check_in']?.toString();
      if (action == 'check_out') {
        record['check_out'] ??= time;
      } else {
        record['check_in'] ??= time;
      }
      final statuses = (record['_local_sync_statuses'] as List<String>? ?? [])
        ..add(item['sync_status']?.toString() ?? 'waiting');
      record['_local_sync_statuses'] = statuses;
      record['sync_status'] = statuses.contains('failed')
          ? 'failed'
          : statuses.every((status) => status == 'synced')
          ? 'synced'
          : 'waiting';
      record['last_action_type'] = action;
      record['last_action_accuracy'] = item['accuracy'];
      record['last_action_captured_at'] = item['captured_at'];
      record['last_action_synced_at'] = item['synced_at'];
      record['last_action_queue_id'] = item['queue_id'];
      record['last_action_error'] = item['last_error'];
      record['last_action_server_record_id'] = item['server_record_id'];
    }

    final merged = mergedByDate.values.toList();
    merged.sort(
      (a, b) => (b['attendance_date']?.toString() ?? '').compareTo(
        a['attendance_date']?.toString() ?? '',
      ),
    );
    return merged;
  }

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic>? get _todayAttendance {
    final today = _dateString(DateTime.now());
    for (final record in attendance) {
      if (record['attendance_date']?.toString().startsWith(today) == true) {
        return record;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _openAttendance {
    for (final record in attendance) {
      if (record['check_in'] != null && record['check_out'] == null) {
        return record;
      }
    }
    return null;
  }

  String? get _nextAction {
    if (_openAttendance != null) return 'check_out';
    if (_todayAttendance == null) return 'check_in';
    return null;
  }

  Future<void> handleAttendanceAction(String actionType) async {
    if (checkingIn) return;

    if (_nextAction != actionType) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            actionType == 'check_in'
                ? 'Today already has an attendance record.'
                : 'There is no open check-in to check out from.',
          ),
        ),
      );
      return;
    }

    final openAttendance = _openAttendance;
    if (actionType == 'check_out' &&
        openAttendance?['sync_status'] == 'failed' &&
        openAttendance?['last_action_server_record_id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The check-in must sync successfully before checking out.',
          ),
        ),
      );
      return;
    }

    if (!await _explainLocationUse() || !mounted) return;

    setState(() {
      checkingIn = true;
      locationState = _LocationState.loading;
      locationMessage = 'Checking permission and waiting for a fresh GPS fix…';
    });

    try {
      final actionAt = DateTime.now();
      final targetDate = actionType == 'check_out'
          ? openAttendance!['attendance_date'].toString().substring(0, 10)
          : _dateString(actionAt);
      final location = await _locationService.capture();
      if (!mounted) return;
      final queueId = await OfflineSyncService.queueAttendanceAction(
        attendanceDate: targetDate,
        actionType: actionType,
        actionAt: actionAt,
        capturedAt: location.capturedAt,
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: location.accuracyMeters,
      );
      locationQueueId = queueId;

      await OfflineSyncService.syncPendingLeaves(force: true);

      final queued = (await OfflineSyncService.getQueueItems(
        operation: 'attendance',
      )).where((row) => row['queue_id'] == queueId);

      final status = queued.isEmpty ? 'waiting' : queued.first['sync_status'];

      if (!mounted) return;

      await _refreshLocationStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'synced'
                ? '${actionType == 'check_in' ? 'Check-in' : 'Check-out'} and location confirmed by the server.'
                : status == 'failed'
                ? 'Synchronization failed. The attendance and GPS reading remain saved on this device.'
                : 'Attendance and GPS reading saved on this device and waiting to sync.',
          ),
        ),
      );

      await getAttendance();
    } on AttendanceLocationException catch (exception) {
      var openSettings = false;
      var settingsAction = '';
      if (exception.issue ==
          AttendanceLocationIssue.permissionPermanentlyDenied) {
        settingsAction = 'Open app settings';
      } else if (exception.issue == AttendanceLocationIssue.servicesDisabled) {
        settingsAction = 'Location settings';
      }
      if (settingsAction.isNotEmpty && mounted) {
        openSettings = await _showLocationIssue(
          exception.message,
          action: settingsAction,
        );
        if (openSettings) {
          if (exception.issue ==
              AttendanceLocationIssue.permissionPermanentlyDenied) {
            await Geolocator.openAppSettings();
          } else {
            await Geolocator.openLocationSettings();
          }
        }
      }
      _setLocationError(exception.message);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.message)));
      }
    } catch (e) {
      if (!mounted) return;
      final message = 'Could not save attendance on this device: $e';
      _setLocationError(message);
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
            title: const Text('Location required for attendance'),
            content: const Text(
              'A fresh foreground GPS reading and its reported accuracy will be saved with this check-in or check-out. Location is collected only for this attendance action.',
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
      _locationSyncFailed = false;
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
        actions: [
          IconButton(
            tooltip: 'Refresh attendance',
            onPressed: getAttendance,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const LogoutAction(),
        ],
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
                  margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Attendance GPS confirmation',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            AppStatusBadge(
                              status: switch (locationState) {
                                _LocationState.uploaded => 'synced',
                                _LocationState.waiting => 'pending',
                                _LocationState.loading => 'in_progress',
                                _LocationState.error => 'failed',
                                _ => 'neutral',
                              },
                              label: switch (locationState) {
                                _LocationState.uploaded => 'Server confirmed',
                                _LocationState.waiting => 'Waiting to sync',
                                _LocationState.loading => 'Locating',
                                _LocationState.error => 'Needs attention',
                                _ => 'Not recorded',
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          locationMessage,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (locationState == _LocationState.waiting ||
                            _locationSyncFailed) ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: () async {
                              final queueId = locationQueueId;
                              if (queueId != null) {
                                await OfflineSyncService.retryQueueItem(
                                  queueId,
                                );
                              }
                            },
                            icon: const Icon(Icons.sync),
                            label: const Text('Retry attendance sync'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: getAttendance,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        const AppSectionHeader(
                          title: 'Attendance history',
                          subtitle: 'Daily records and sync confirmation',
                        ),
                        if (attendance.isEmpty)
                          const AppEmptyState(
                            icon: Icons.calendar_month_outlined,
                            title: 'No attendance records',
                            description:
                                'Your recorded attendance will appear here.',
                          ),
                        for (final record in attendance)
                          _attendanceCard(record),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: checkingIn || _nextAction == null
            ? null
            : () => handleAttendanceAction(_nextAction!),
        icon: checkingIn
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(_nextAction == 'check_out' ? Icons.logout : Icons.login),
        label: Text(
          checkingIn
              ? 'Getting GPS…'
              : _nextAction == 'check_out'
              ? 'Check out'
              : _nextAction == 'check_in'
              ? 'Check in'
              : 'Done for today',
        ),
      ),
    );
  }

  Widget _attendanceCard(Map<String, dynamic> record) {
    final local = record.containsKey('sync_status');
    final syncStatus = record['sync_status']?.toString();
    final status = local
        ? syncStatus == 'synced'
              ? 'Server confirmed'
              : syncStatus == 'retry'
              ? 'Waiting to retry'
              : syncStatus == 'failed'
              ? 'Sync failed'
              : 'Waiting to sync'
        : (record['status'] ?? 'present').toString();
    final statusKey = local
        ? syncStatus == 'synced'
              ? 'synced'
              : syncStatus == 'failed'
              ? 'failed'
              : 'pending'
        : status;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.infoSurface,
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: const Icon(
            Icons.calendar_month_outlined,
            color: AppColors.info,
          ),
        ),
        title: Text(
          record['attendance_date']?.toString() ?? 'Date unavailable',
        ),
        subtitle: Text(
          'Check in: ${record['check_in'] ?? '—'}\n'
          'Check out: ${record['check_out'] ?? '—'}',
        ),
        isThreeLine: true,
        trailing: AppStatusBadge(status: statusKey, label: status),
      ),
    );
  }
}
