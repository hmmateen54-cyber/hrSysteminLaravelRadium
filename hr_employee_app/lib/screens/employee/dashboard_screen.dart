import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../components/app_empty_state.dart';
import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../components/app_section_header.dart';
import '../../components/app_stat_card.dart';
import '../../components/app_status_badge.dart';
import '../../components/offline_cache_banner.dart';
import '../../components/dashboard_card.dart';
import '../../components/logout_action.dart';
import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';
import '../../services/offline_sync_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'attendance_screen.dart';
import 'feedback_screen.dart';
import 'leaves_screen.dart';
import 'performance_screen.dart';
import 'profile_screen.dart';
import 'tasks_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final AutoRefreshController _autoRefresh;
  bool _requestInFlight = false;
  bool _offlineMode = false;
  Map<String, dynamic>? employee;
  bool loading = true;
  String? error;
  bool _overviewLoading = true;
  bool _overviewRequestInFlight = false;
  bool _overviewOffline = false;
  bool _overviewHasData = false;
  String? _overviewFetchedAt;
  String? _overviewError;
  List<Map<String, dynamic>> _overviewLeaves = [];
  List<Map<String, dynamic>> _overviewAttendance = [];
  List<Map<String, dynamic>> _overviewPerformance = [];
  List<Map<String, dynamic>> _overviewTasks = [];

  Future<void> _onQueueChanged() async {
    try {
      final cached = await OfflineSyncService.readCachedItems('tasks');
      final rows = (cached?['items'] as List?)
          ?.whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      if (rows != null && mounted) {
        setState(() {
          _overviewTasks = rows;
          _overviewFetchedAt ??= cached?['fetched_at']?.toString();
          _overviewHasData = _overviewHasData || rows.isNotEmpty;
        });
      }
    } catch (_) {
      // The dashboard can keep showing its current summary if cache reads fail.
    }
  }

  Future<void> getProfile() async {
    if (!mounted || _requestInFlight) return;
    _requestInFlight = true;
    if (employee == null && !loading) setState(() => loading = true);

    try {
      if (employee == null) {
        final cached = await _readCachedProfile();
        if (cached != null && mounted) {
          setState(() {
            employee = cached;
            loading = false;
            error = null;
          });
        }
      }

      final response = await ApiService.get('/employee/profile');
      if (!mounted) return;

      if (ApiService.isSuccess(response['status'])) {
        final data = response['data'];
        final profile = data is Map ? data['employee'] : null;
        if (profile is Map<String, dynamic>) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'cached_employee',
              jsonEncode({
                'user_id': widget.user['id'],
                'employee': {
                  'employee_id': profile['employee_id'],
                  'department': profile['department'],
                  'designation': profile['designation'],
                },
              }),
            );
          } catch (_) {
            // The live profile remains available if local caching fails.
          }
        }

        setState(() {
          employee = profile is Map<String, dynamic> ? profile : null;
          loading = false;
          error = employee == null
              ? 'The server returned an invalid employee profile.'
              : null;
          _offlineMode = false;
        });
      } else {
        final status = response['status'];
        final serverMessage = response['data'] is Map
            ? response['data']['message']?.toString()
            : null;
        setState(() {
          loading = false;
          if (status == 429 || (status is int && status >= 500)) {
            _offlineMode = true;
            error = 'Showing saved information. The server is unavailable.';
          } else {
            _offlineMode = false;
            error = status == 404
                ? 'Employee profile not found. Contact HR to link this account.'
                : serverMessage ?? ApiService.messageForStatus(status);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          _offlineMode = true;
          error = 'Showing saved information. The server is unavailable.';
        });
      }
    } finally {
      _requestInFlight = false;
    }
  }

  Future<Map<String, dynamic>?> _readCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_employee');
      if (raw == null) return null;
      final cached = jsonDecode(raw);
      if (cached is! Map || '${cached['user_id']}' != '${widget.user['id']}') {
        return null;
      }
      final profile = cached['employee'];
      return profile is Map ? Map<String, dynamic>.from(profile) : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _safeGet(String path) async {
    try {
      return await ApiService.get(path);
    } catch (_) {
      return {'status': 0, 'data': null};
    }
  }

  List<Map<String, dynamic>> _readRows(dynamic response, String key) {
    if (response is! Map || !ApiService.isSuccess(response['status'])) {
      return [];
    }
    final data = response['data'];
    final value = data is Map ? data[key] : null;
    final rows = value is Map ? value['data'] : value;
    return rows is List
        ? rows
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
        : [];
  }

  List<Map<String, dynamic>> _mergeQueued(
    List<Map<String, dynamic>> queued,
    List<Map<String, dynamic>> remote,
  ) {
    final knownSyncIds = remote
        .map((row) => row['sync_id']?.toString())
        .whereType<String>()
        .toSet();
    final localOnly = queued.where((row) {
      final clientId = row['client_id']?.toString();
      return clientId == null || !knownSyncIds.contains(clientId);
    });
    return [...localOnly, ...remote];
  }

  Future<void> _loadOverview() async {
    if (!mounted || _overviewRequestInFlight) return;
    _overviewRequestInFlight = true;
    if (!_overviewHasData) setState(() => _overviewLoading = true);

    List<Map<String, dynamic>> queuedLeaves = [];
    List<Map<String, dynamic>> queuedAttendance = [];
    Map<String, dynamic>? cachedLeaves;
    Map<String, dynamic>? cachedAttendance;
    Map<String, dynamic>? cachedPerformance;
    Map<String, dynamic>? cachedTasks;
    try {
      final cached = await Future.wait([
        OfflineSyncService.readCachedItems('leaves'),
        OfflineSyncService.readCachedItems('tasks'),
        OfflineSyncService.readCachedItems('attendance'),
        OfflineSyncService.readCachedItems('performance'),
        OfflineSyncService.getQueueItems(operation: 'leave'),
        OfflineSyncService.getQueueItems(operation: 'attendance'),
      ]);
      cachedLeaves = cached[0] as Map<String, dynamic>?;
      cachedTasks = cached[1] as Map<String, dynamic>?;
      cachedAttendance = cached[2] as Map<String, dynamic>?;
      cachedPerformance = cached[3] as Map<String, dynamic>?;
      queuedLeaves = (cached[4] as List).cast<Map<String, dynamic>>();
      queuedAttendance = (cached[5] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      // The live dashboard remains useful if local storage is unavailable.
    }

    final cachedLeaveRows =
        (cachedLeaves?['items'] as List?)
            ?.whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList() ??
        <Map<String, dynamic>>[];
    final cachedAttendanceRows =
        (cachedAttendance?['items'] as List?)
            ?.whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList() ??
        <Map<String, dynamic>>[];
    final cachedPerformanceRows =
        (cachedPerformance?['items'] as List?)
            ?.whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList() ??
        <Map<String, dynamic>>[];
    final cachedTaskRows =
        (cachedTasks?['items'] as List?)
            ?.whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList() ??
        <Map<String, dynamic>>[];
    final hasCachedData =
        cachedLeaves != null ||
        cachedTasks != null ||
        cachedAttendance != null ||
        cachedPerformance != null;
    if (hasCachedData && mounted) {
      setState(() {
        _overviewLeaves = _mergeQueued(queuedLeaves, cachedLeaveRows);
        _overviewTasks = cachedTaskRows;
        _overviewAttendance = _mergeQueued(
          queuedAttendance,
          cachedAttendanceRows,
        );
        _overviewPerformance = cachedPerformanceRows;
        _overviewFetchedAt =
            cachedLeaves?['fetched_at']?.toString() ??
            cachedTasks?['fetched_at']?.toString() ??
            cachedAttendance?['fetched_at']?.toString() ??
            cachedPerformance?['fetched_at']?.toString();
        _overviewHasData = true;
        _overviewLoading = false;
      });
    }

    try {
      final responses = await Future.wait([
        _safeGet('/employee/leaves'),
        _safeGet('/employee/tasks'),
        _safeGet('/employee/performance'),
        _safeGet('/employee/attendance'),
      ]);
      if (!mounted) return;

      final liveLeaves = _readRows(responses[0], 'leaves');
      final liveTasks = _readRows(responses[1], 'tasks');
      final livePerformance = _readRows(responses[2], 'performance');
      final liveAttendance = _readRows(responses[3], 'attendance');
      final success = responses
          .map((response) => ApiService.isSuccess(response['status']))
          .toList();
      final hasFailure = success.any((ok) => !ok);

      if (success[0]) {
        try {
          await OfflineSyncService.saveCachedItems('leaves', liveLeaves);
          cachedLeaves = await OfflineSyncService.readCachedItems('leaves');
        } catch (_) {
          // Live results remain usable if local storage cannot be updated.
        }
      }
      if (success[1]) {
        try {
          await OfflineSyncService.saveCachedItems('tasks', liveTasks);
          cachedTasks = await OfflineSyncService.readCachedItems('tasks');
        } catch (_) {
          // Live results remain usable if local storage cannot be updated.
        }
      }
      if (success[2]) {
        try {
          await OfflineSyncService.saveCachedItems(
            'performance',
            livePerformance,
          );
          cachedPerformance = await OfflineSyncService.readCachedItems(
            'performance',
          );
        } catch (_) {
          // Live results remain usable if local storage cannot be updated.
        }
      }
      if (success[3]) {
        try {
          await OfflineSyncService.saveCachedItems(
            'attendance',
            liveAttendance,
          );
          cachedAttendance = await OfflineSyncService.readCachedItems(
            'attendance',
          );
        } catch (_) {
          // Live results remain usable if local storage cannot be updated.
        }
      }
      try {
        queuedLeaves = await OfflineSyncService.getQueueItems(
          operation: 'leave',
        );
        queuedAttendance = await OfflineSyncService.getQueueItems(
          operation: 'attendance',
        );
      } catch (_) {
        // Live history can still be shown without local queue details.
      }

      final visibleTasks = success[1]
          ? ((cachedTasks?['items'] as List?)
                    ?.whereType<Map>()
                    .map((row) => Map<String, dynamic>.from(row))
                    .toList() ??
                liveTasks)
          : _overviewTasks;

      setState(() {
        _overviewLeaves = _mergeQueued(
          queuedLeaves,
          success[0]
              ? liveLeaves
              : _overviewLeaves
                    .where((row) => !row.containsKey('sync_status'))
                    .toList(),
        );
        _overviewTasks = visibleTasks;
        _overviewPerformance = success[2]
            ? livePerformance
            : _overviewPerformance;
        _overviewAttendance = _mergeQueued(
          queuedAttendance,
          success[3]
              ? liveAttendance
              : _overviewAttendance
                    .where((row) => !row.containsKey('sync_status'))
                    .toList(),
        );
        _overviewFetchedAt =
            cachedLeaves?['fetched_at']?.toString() ??
            cachedTasks?['fetched_at']?.toString() ??
            cachedAttendance?['fetched_at']?.toString() ??
            cachedPerformance?['fetched_at']?.toString() ??
            _overviewFetchedAt;
        _overviewHasData =
            _overviewLeaves.isNotEmpty ||
            _overviewTasks.isNotEmpty ||
            _overviewPerformance.isNotEmpty ||
            _overviewAttendance.isNotEmpty;
        _overviewOffline = hasFailure && (_overviewHasData || hasCachedData);
        _overviewError = hasFailure && !_overviewHasData
            ? 'Your work summary is unavailable right now.'
            : null;
        _overviewLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _overviewOffline = hasCachedData || _overviewHasData;
          _overviewError = _overviewHasData
              ? null
              : 'Your work summary is unavailable right now.';
          _overviewLoading = false;
        });
      }
    } finally {
      _overviewRequestInFlight = false;
    }
  }

  Future<void> _refreshDashboard() async {
    await Future.wait([getProfile(), _loadOverview()]);
  }

  @override
  void initState() {
    super.initState();
    OfflineSyncService.queueRevision.addListener(_onQueueChanged);
    _autoRefresh = AutoRefreshController(
      owner: this,
      onRefresh: _refreshDashboard,
    )..start();
    getProfile();
    _loadOverview();
  }

  @override
  void dispose() {
    OfflineSyncService.queueRevision.removeListener(_onQueueChanged);
    _autoRefresh.dispose();
    super.dispose();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _refreshDashboard();
  }

  Widget _overviewSection(double width) {
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    Map<String, dynamic>? todayAttendance;
    for (final record in _overviewAttendance) {
      if (record['attendance_date']?.toString().startsWith(todayKey) == true) {
        todayAttendance = record;
        break;
      }
    }
    final localAttendance = todayAttendance?.containsKey('sync_status') == true;
    final syncStatus = todayAttendance?['sync_status']?.toString();
    final attendanceValue = todayAttendance == null
        ? 'Not recorded'
        : localAttendance
        ? syncStatus == 'synced'
              ? 'Confirmed'
              : syncStatus == 'failed'
              ? 'Needs attention'
              : 'Saved offline'
        : (todayAttendance['status']?.toString() ?? 'Recorded');
    final attendanceTime = todayAttendance?['check_in']?.toString();

    final pendingLeaves = _overviewLeaves
        .where(
          (leave) =>
              !leave.containsKey('sync_status') && leave['status'] == 'pending',
        )
        .length;
    final queuedLeaves = _overviewLeaves
        .where(
          (leave) =>
              leave.containsKey('sync_status') &&
              leave['sync_status'] != 'synced',
        )
        .length;
    final openTasks = _overviewTasks
        .where((assignment) => assignment['status'] != 'completed')
        .length;
    final ratingValues = _overviewPerformance
        .map((record) => double.tryParse(record['rating']?.toString() ?? ''))
        .whereType<double>()
        .toList();
    final averageRating = ratingValues.isEmpty
        ? null
        : ratingValues.reduce((a, b) => a + b) / ratingValues.length;
    final columns = width >= 900 ? 4 : 2;

    if (_overviewLoading && !_overviewHasData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: AppLoader(message: 'Loading your work overview'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_overviewOffline)
          OfflineCacheBanner(
            fetchedAt: _overviewFetchedAt,
            onRetry: _refreshDashboard,
          ),
        if (_overviewError != null)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.warningSurface,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(_overviewError!)),
                TextButton(
                  onPressed: _loadOverview,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        const AppSectionHeader(
          title: 'Today at a glance',
          subtitle: 'A snapshot from your attendance and work records',
        ),
        GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: width >= 900 ? 1.45 : 0.95,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            AppStatCard(
              label: 'Today’s attendance',
              value: attendanceValue,
              icon: Icons.fingerprint_rounded,
              supportingText: attendanceTime == null
                  ? 'Check-in status'
                  : 'Check-in $attendanceTime',
              accent: AppColors.green,
              onTap: () => _open(const AttendanceScreen()),
            ),
            AppStatCard(
              label: 'Pending leave requests',
              value: '$pendingLeaves',
              icon: Icons.event_note_outlined,
              supportingText: queuedLeaves == 0
                  ? 'Awaiting a decision'
                  : '$queuedLeaves saved on this device',
              accent: AppColors.warning,
              onTap: () => _open(const LeavesScreen()),
            ),
            AppStatCard(
              label: 'Open tasks',
              value: '$openTasks',
              icon: Icons.assignment_outlined,
              supportingText: 'Of ${_overviewTasks.length} assigned tasks',
              accent: AppColors.info,
              onTap: () => _open(const EmployeeTasksScreen()),
            ),
            AppStatCard(
              label: 'Average review rating',
              value: averageRating?.toStringAsFixed(1) ?? '—',
              icon: Icons.insights_outlined,
              supportingText: '${_overviewPerformance.length} reviews shared',
              accent: AppColors.emerald,
              onTap: () => _open(const PerformanceScreen()),
            ),
          ],
        ),
        AppSectionHeader(
          title: 'Recent leave requests',
          subtitle: 'Your latest submissions and decisions',
          trailing: TextButton(
            onPressed: () => _open(const LeavesScreen()),
            child: const Text('View all'),
          ),
        ),
        if (_overviewLeaves.isEmpty)
          const AppEmptyState(
            icon: Icons.event_note_outlined,
            title: 'No leave requests yet',
            description:
                'Your leave history will appear here after you submit a request.',
          ),
        for (final leave in _overviewLeaves.take(3)) _overviewLeaveCard(leave),
        AppSectionHeader(
          title: 'Assigned tasks',
          subtitle: 'Your current work and progress',
          trailing: TextButton(
            onPressed: () => _open(const EmployeeTasksScreen()),
            child: const Text('View all'),
          ),
        ),
        if (_overviewTasks.isEmpty)
          const AppEmptyState(
            icon: Icons.task_alt_outlined,
            title: 'No tasks assigned',
            description: 'New assignments will appear here.',
          ),
        for (final assignment in _overviewTasks.take(3))
          _overviewTaskCard(assignment),
      ],
    );
  }

  Widget _overviewLeaveCard(Map<String, dynamic> leave) {
    final local = leave.containsKey('sync_status');
    final rawStatus =
        leave['sync_status']?.toString() ??
        leave['status']?.toString() ??
        'pending';
    final start = leave['start_date']?.toString().split('T').first ?? '—';
    final end = leave['end_date']?.toString().split('T').first ?? '—';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: const Icon(Icons.event_note_outlined),
        title: Text(leave['leave_type']?.toString() ?? 'Leave request'),
        subtitle: Text('$start  –  $end'),
        trailing: AppStatusBadge(
          status: local
              ? rawStatus == 'synced'
                    ? 'synced'
                    : rawStatus == 'failed'
                    ? 'failed'
                    : 'pending'
              : rawStatus,
          label: local
              ? rawStatus == 'synced'
                    ? 'Confirmed'
                    : rawStatus == 'failed'
                    ? 'Needs attention'
                    : 'Waiting to sync'
              : rawStatus,
          compact: true,
        ),
        onTap: () => _open(const LeavesScreen()),
      ),
    );
  }

  Widget _overviewTaskCard(Map<String, dynamic> assignment) {
    final task = assignment['task'] is Map
        ? Map<String, dynamic>.from(assignment['task'])
        : <String, dynamic>{};
    final project = task['project'] is Map
        ? task['project']['name']?.toString()
        : null;
    final status = assignment['status']?.toString() ?? 'assigned';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: const Icon(Icons.assignment_outlined),
        title: Text(task['title']?.toString() ?? 'Task'),
        subtitle: Text(
          [
            if (project != null && project.isNotEmpty) project,
            'Due ${task['due_date'] ?? 'not set'}',
          ].join(' · '),
        ),
        trailing: AppStatusBadge(status: status, compact: true),
        onTap: () => _open(const EmployeeTasksScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rawName = widget.user['name']?.toString().trim() ?? '';
    final displayName = rawName.isEmpty ? 'there' : rawName;
    final email = widget.user['email']?.toString();
    final department = employee?['department']?.toString();
    final designation = employee?['designation']?.toString();
    final employeeId = employee?['employee_id']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My workspace'),
        actions: const [LogoutAction()],
      ),
      body: loading && employee == null
          ? const AppLoader()
          : error != null && !_offlineMode
          ? AppError(message: error!, onRetry: getProfile)
          : RefreshIndicator(
              onRefresh: _refreshDashboard,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900 ? 3 : 2;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      if (_offlineMode && !_overviewOffline)
                        Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.warningSurface,
                            borderRadius: BorderRadius.circular(
                              AppRadius.medium,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cloud_off_outlined,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  error ?? 'Showing saved profile information.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              TextButton(
                                onPressed: getProfile,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      _welcomePanel(
                        displayName: displayName,
                        email: email,
                        employeeId: employeeId,
                        department: department,
                        designation: designation,
                      ),
                      _overviewSection(constraints.maxWidth),
                      const AppSectionHeader(
                        title: 'Your workspace',
                        subtitle: 'Everyday tools and information in one place',
                      ),
                      GridView.count(
                        crossAxisCount: columns,
                        crossAxisSpacing: AppSpacing.sm,
                        mainAxisSpacing: AppSpacing.sm,
                        childAspectRatio: columns == 3 ? 1.5 : 1.2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          DashboardCard(
                            icon: Icons.fingerprint_rounded,
                            title: 'Attendance',
                            onTap: () => _open(const AttendanceScreen()),
                          ),
                          DashboardCard(
                            icon: Icons.event_note_rounded,
                            title: 'Leave requests',
                            onTap: () => _open(const LeavesScreen()),
                          ),
                          DashboardCard(
                            icon: Icons.assignment_outlined,
                            title: 'My tasks',
                            onTap: () => _open(const EmployeeTasksScreen()),
                          ),
                          DashboardCard(
                            icon: Icons.insights_outlined,
                            title: 'Performance',
                            onTap: () => _open(const PerformanceScreen()),
                          ),
                          DashboardCard(
                            icon: Icons.person_outline_rounded,
                            title: 'My profile',
                            onTap: () => _open(const ProfileScreen()),
                          ),
                          DashboardCard(
                            icon: Icons.forum_outlined,
                            title: 'Feedback',
                            onTap: () => _open(const EmployeeFeedbackScreen()),
                          ),
                        ],
                      ),
                      if (employee == null && !_offlineMode)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.lg),
                          child: AppEmptyState(
                            icon: Icons.badge_outlined,
                            title: 'Profile details are unavailable',
                            description:
                                'Your workspace shortcuts are ready. Contact HR if your employee profile needs to be linked.',
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _welcomePanel({
    required String displayName,
    String? email,
    String? employeeId,
    String? department,
    String? designation,
  }) {
    final roleDetails = [
      if (designation != null && designation.trim().isNotEmpty) designation,
      if (department != null && department.trim().isNotEmpty) department,
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.extraLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 16,
                color: AppColors.heroLabel,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'EMPLOYEE PORTAL',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.heroLabel,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                child: Text(
                  displayName.isEmpty ? 'E' : displayName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Welcome back,',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.heroText),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (email != null && email.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.heroText),
            ),
          ],
          if (roleDetails.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              roleDetails,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.heroText),
            ),
          ],
          if (employeeId != null && employeeId.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                'Employee ID  $employeeId',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
