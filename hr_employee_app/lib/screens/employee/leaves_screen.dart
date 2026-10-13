import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../components/logout_action.dart';
import '../../components/offline_cache_banner.dart';
import '../../components/app_status_badge.dart';
import '../../components/app_sync_indicator.dart';
import '../../components/app_section_header.dart';
import '../../components/app_empty_state.dart';
import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';
import '../../services/offline_sync_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'apply_leave_screen.dart';

class LeavesScreen extends StatefulWidget {
  const LeavesScreen({super.key});

  @override
  State<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen> {
  late final AutoRefreshController _autoRefresh;
  bool _requestInFlight = false;
  bool _refreshQueued = false;
  bool _hasLoaded = false;
  List<Map<String, dynamic>> leaves = [];
  bool loading = true;
  String? error;
  String? _cacheFetchedAt;
  bool _hasCachedData = false;
  bool _offlineMode = false;
  final Set<String> _retrying = {};

  @override
  void initState() {
    super.initState();
    _autoRefresh = AutoRefreshController(owner: this, onRefresh: getLeaves)
      ..start();
    OfflineSyncService.queueRevision.addListener(_onQueueChanged);
    getLeaves();
  }

  void _onQueueChanged() => unawaited(getLeaves());

  Future<void> getLeaves() async {
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
      local = await OfflineSyncService.getQueueItems(operation: 'leave');
    } catch (_) {
      localStorageError = 'Offline request storage is unavailable.';
      if (mounted && !_hasLoaded) {
        setState(() => error = localStorageError);
      }
    }

    Map<String, dynamic>? cached;
    try {
      cached = await OfflineSyncService.readCachedItems('leaves');
    } catch (_) {
      localStorageError ??=
          'Saved leave history is unavailable on this device.';
    }
    final cachedRemote =
        (cached?['items'] as List?)
            ?.whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList() ??
        <Map<String, dynamic>>[];
    if (cached != null && mounted) {
      final cacheSnapshot = cached;
      setState(() {
        leaves = _mergeLeaves(local, cachedRemote);
        _cacheFetchedAt = cacheSnapshot['fetched_at']?.toString();
        _hasCachedData = true;
        loading = false;
        _hasLoaded = true;
      });
    }

    try {
      final response = await ApiService.get('/employee/leaves');
      if (!mounted) return;
      if (ApiService.isSuccess(response['status']) && response['data'] is Map) {
        final serverRows = response['data']['leaves'];
        final remote = serverRows is List
            ? serverRows
                  .whereType<Map>()
                  .map(Map<String, dynamic>.from)
                  .toList()
            : <Map<String, dynamic>>[];
        Map<String, dynamic>? savedCache;
        try {
          await OfflineSyncService.saveCachedItems('leaves', remote);
          savedCache = await OfflineSyncService.readCachedItems('leaves');
        } catch (_) {
          // Keep the live server response usable if local storage fails.
        }
        final knownIds = remote
            .map((leave) => leave['sync_id']?.toString())
            .whereType<String>()
            .toSet();
        final localOnly = local.where(
          (item) => !knownIds.contains(item['client_id']),
        );
        setState(() {
          leaves = [...localOnly, ...remote];
          loading = false;
          error = localStorageError;
          _offlineMode = false;
          _hasCachedData = true;
          _cacheFetchedAt = savedCache?['fetched_at']?.toString();
          _hasLoaded = true;
        });
      } else {
        final data = response['data'];
        final message = data is Map
            ? data['message']?.toString() ??
                  ApiService.messageForStatus(response['status'])
            : ApiService.messageForStatus(response['status']);
        setState(() {
          final currentRemote = leaves
              .where((leave) => !leave.containsKey('sync_status'))
              .toList();
          final remoteIds = currentRemote
              .map((leave) => leave['sync_id']?.toString())
              .whereType<String>()
              .toSet();
          leaves = [
            ...local.where((item) => !remoteIds.contains(item['client_id'])),
            ...currentRemote,
          ];
          error = localStorageError ?? message;
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
        final currentRemote = leaves
            .where((leave) => !leave.containsKey('sync_status'))
            .toList();
        final remoteIds = currentRemote
            .map((leave) => leave['sync_id']?.toString())
            .whereType<String>()
            .toSet();
        leaves = [
          ...local.where((item) => !remoteIds.contains(item['client_id'])),
          ...currentRemote,
        ];
        error =
            localStorageError ??
            'Unable to reach the server. Saved offline requests remain on this device.';
        _offlineMode = _hasCachedData;
        loading = false;
        _hasLoaded = true;
      });
    } finally {
      _requestInFlight = false;
      if (_refreshQueued && mounted) {
        _refreshQueued = false;
        unawaited(Future<void>.delayed(Duration.zero, getLeaves));
      }
    }
  }

  List<Map<String, dynamic>> _mergeLeaves(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> remote,
  ) {
    final knownIds = remote
        .map((leave) => leave['sync_id']?.toString())
        .whereType<String>()
        .toSet();
    return [
      ...local.where(
        (item) => !knownIds.contains(item['client_id']?.toString()),
      ),
      ...remote,
    ];
  }

  Future<void> _retry(Map<String, dynamic> leave) async {
    final id = leave['queue_id']?.toString();
    if (id == null || _retrying.contains(id)) return;
    setState(() => _retrying.add(id));
    try {
      await OfflineSyncService.retryQueueItem(id);
      await getLeaves();
    } finally {
      if (mounted) setState(() => _retrying.remove(id));
    }
  }

  Future<void> _edit(Map<String, dynamic> leave) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ApplyLeaveScreen(queueId: leave['queue_id']?.toString()),
      ),
    );
    if (mounted) await getLeaves();
  }

  Future<void> _editServerLeave(Map<String, dynamic> leave) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ApplyLeaveScreen(existingLeave: leave)),
    );
    if (mounted) await getLeaves();
  }

  String _localStatus(Map<String, dynamic> leave) {
    return switch (leave['sync_status']) {
      'syncing' => 'Syncing',
      'retry' => 'Waiting to retry',
      'failed' => 'Needs attention',
      'synced' => 'Server confirmed',
      _ => 'Waiting to sync',
    };
  }

  @override
  void dispose() {
    _autoRefresh.dispose();
    OfflineSyncService.queueRevision.removeListener(_onQueueChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leaves'),
        actions: [
          IconButton(
            tooltip: 'Refresh leave requests',
            onPressed: getLeaves,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const LogoutAction(),
        ],
      ),
      body: loading
          ? const AppLoader()
          : error != null && leaves.isEmpty && !_offlineMode
          ? AppError(message: error!, onRetry: getLeaves)
          : RefreshIndicator(
              onRefresh: () async {
                await OfflineSyncService.syncPendingLeaves(force: true);
                await getLeaves();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  const AppSectionHeader(
                    title: 'Leave requests',
                    subtitle: 'Track submissions and review decisions',
                  ),
                  if (_offlineMode)
                    OfflineCacheBanner(
                      fetchedAt: _cacheFetchedAt,
                      onRetry: () async {
                        await OfflineSyncService.syncPendingLeaves(force: true);
                        await getLeaves();
                      },
                    )
                  else if (error != null)
                    _warningMessage(error!, getLeaves),
                  if (leaves.isEmpty)
                    const AppEmptyState(
                      icon: Icons.event_note_outlined,
                      title: 'No leave requests yet',
                      description:
                          'Your saved and submitted requests will appear here.',
                    ),
                  for (final leave in leaves) _leaveCard(leave),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Request leave',
        onPressed: () => _edit(const {}),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _warningMessage(String message, VoidCallback onRetry) {
    return Container(
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
          Expanded(child: Text(message)),
          IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh)),
        ],
      ),
    );
  }

  Widget _leaveCard(Map<String, dynamic> leave) {
    final local = leave.containsKey('sync_status');
    final rawStatus = local
        ? leave['sync_status']?.toString() ?? 'pending'
        : leave['status']?.toString() ?? 'pending';
    final statusLabel = local ? _localStatus(leave) : rawStatus;
    final statusKey = local
        ? switch (rawStatus) {
            'synced' => 'synced',
            'failed' => 'failed',
            'syncing' => 'in_progress',
            _ => 'pending',
          }
        : rawStatus;
    final queueId = leave['queue_id']?.toString();
    final start = leave['start_date']?.toString().split('T').first ?? '—';
    final end = leave['end_date']?.toString().split('T').first ?? '—';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.infoSurface,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Icon(
                    local ? Icons.cloud_upload_outlined : Icons.event_note,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    leave['leave_type']?.toString() ?? 'Leave request',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (!local)
                  AppStatusBadge(status: statusKey, label: statusLabel)
                else
                  AppStatusBadge(
                    status: statusKey,
                    label: statusLabel,
                    compact: true,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text('$start  –  $end')),
              ],
            ),
            if ((leave['reason']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                leave['reason'].toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (local) ...[
              const SizedBox(height: AppSpacing.sm),
              AppSyncIndicator(
                state: switch (rawStatus) {
                  'synced' => AppSyncState.synchronized,
                  'syncing' => AppSyncState.syncing,
                  'failed' => AppSyncState.failed,
                  _ => AppSyncState.pending,
                },
                detail: rawStatus == 'synced'
                    ? 'The server confirmed this request.'
                    : rawStatus == 'failed'
                    ? leave['last_error']?.toString()
                    : 'Saved on this device. Waiting for server confirmation.',
              ),
              if (queueId != null && rawStatus != 'synced')
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      if (rawStatus == 'failed')
                        TextButton.icon(
                          onPressed: () => _edit(leave),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit request'),
                        ),
                      TextButton.icon(
                        onPressed: _retrying.contains(queueId)
                            ? null
                            : () => _retry(leave),
                        icon: const Icon(Icons.sync_rounded),
                        label: Text(
                          _retrying.contains(queueId)
                              ? 'Syncing'
                              : 'Retry sync',
                        ),
                      ),
                    ],
                  ),
                ),
            ] else if (rawStatus == 'pending')
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _editServerLeave(leave),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit request'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
