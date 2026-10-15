import 'package:flutter/material.dart';

import '../../components/app_error.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_loader.dart';
import '../../components/logout_action.dart';
import '../../components/app_status_badge.dart';
import '../../components/app_section_header.dart';
import '../../components/offline_cache_banner.dart';
import '../../services/api_service.dart';
import '../../services/offline_sync_service.dart';
import '../../theme/app_spacing.dart';

class EmployeeTasksScreen extends StatefulWidget {
  const EmployeeTasksScreen({super.key});

  @override
  State<EmployeeTasksScreen> createState() => _EmployeeTasksScreenState();
}

class _EmployeeTasksScreenState extends State<EmployeeTasksScreen> {
  List<Map<String, dynamic>> assignments = [];
  bool loading = true;
  bool offlineMode = false;
  String? cacheFetchedAt;
  String? error;

  void _onQueueChanged() => _loadCachedTasks();

  Future<void> _loadCachedTasks() async {
    try {
      final cached = await OfflineSyncService.readCachedItems('tasks');
      final rows = (cached?['items'] as List?)
          ?.whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      if (rows != null && mounted) {
        setState(() {
          assignments = rows;
          cacheFetchedAt = cached?['fetched_at']?.toString();
        });
      }
    } catch (_) {
      // Keep the current list visible if the local database is unavailable.
    }
  }

  Future<void> loadTasks() async {
    if (!mounted) return;
    if (assignments.isEmpty) setState(() => loading = true);
    Map<String, dynamic>? cached;
    try {
      cached = await OfflineSyncService.readCachedItems('tasks');
      final rows = (cached?['items'] as List?)
          ?.whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      if (rows != null && mounted) {
        setState(() {
          assignments = rows;
          cacheFetchedAt = cached?['fetched_at']?.toString();
          loading = false;
        });
      }
    } catch (_) {
      // Continue with the live task service if local storage is unavailable.
    }
    try {
      final response = await ApiService.get('/employee/tasks');
      if (!mounted) return;
      if (!ApiService.isSuccess(response['status'])) {
        setState(() {
          offlineMode = cached != null;
          error = offlineMode
              ? null
              : cached == null
              ? 'My Tasks has not been loaded on this device yet. Connect to the server and load it once before making offline updates.'
              : ApiService.messageFromResponse(
                  response['data'],
                  response['status'],
                );
          loading = false;
        });
        return;
      }
      final taskValue = response['data'] is Map
          ? response['data']['tasks']
          : null;
      final rows = taskValue is Map ? taskValue['data'] : taskValue;
      final remote = rows is List
          ? rows
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList()
          : <Map<String, dynamic>>[];
      var visible = remote;
      try {
        await OfflineSyncService.saveCachedItems('tasks', remote);
        final saved = await OfflineSyncService.readCachedItems('tasks');
        cacheFetchedAt = saved?['fetched_at']?.toString();
        visible =
            (saved?['items'] as List?)
                ?.whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList() ??
            remote;
      } catch (_) {
        // Keep the live response even if the local cache cannot be updated.
      }
      setState(() {
        assignments = visible;
        offlineMode = false;
        error = null;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          offlineMode = cached != null;
          error = offlineMode
              ? null
              : 'My Tasks has not been loaded on this device yet. Connect to the server and load it once before making offline updates.';
          loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    OfflineSyncService.queueRevision.addListener(_onQueueChanged);
    loadTasks();
  }

  @override
  void dispose() {
    OfflineSyncService.queueRevision.removeListener(_onQueueChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            tooltip: 'Refresh tasks',
            onPressed: loadTasks,
            icon: const Icon(Icons.refresh),
          ),
          const LogoutAction(),
        ],
      ),
      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: loadTasks)
          : RefreshIndicator(
              onRefresh: loadTasks,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const AppSectionHeader(
                    title: 'Assigned to you',
                    subtitle: 'Review deadlines and update your progress',
                  ),
                  if (offlineMode)
                    OfflineCacheBanner(
                      fetchedAt: cacheFetchedAt,
                      onRetry: loadTasks,
                    ),
                  if (assignments.isEmpty)
                    const AppEmptyState(
                      icon: Icons.task_alt_outlined,
                      title: 'No tasks assigned',
                      description: 'New work assigned to you will appear here.',
                    ),
                  for (final assignment in assignments)
                    _assignmentTile(assignment),
                ],
              ),
            ),
    );
  }

  Widget _assignmentTile(Map<String, dynamic> assignment) {
    final task = assignment['task'] is Map
        ? Map<String, dynamic>.from(assignment['task'])
        : <String, dynamic>{};
    final project = task['project'] is Map
        ? task['project']['name']?.toString()
        : null;
    final status = assignment['status']?.toString() ?? 'assigned';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
        title: Text(
          task['title']?.toString() ?? 'Task',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(
          [
            ?project,
            'Priority: ${task['priority'] ?? 'normal'}',
            'Due: ${task['due_date']?.toString().split("T").first ?? 'Not set'}',
            'Status: ${status.replaceAll('_', ' ')}',
          ].join('  •  '),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppStatusBadge(status: status),
            if (assignment['sync_status'] != null) ...[
              const SizedBox(height: 5),
              _syncLabel(assignment['sync_status']?.toString()),
            ],
          ],
        ),
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => EmployeeTaskDetailScreen(assignment: assignment),
            ),
          );
          if (changed == true && mounted) loadTasks();
        },
      ),
    );
  }

  Widget _syncLabel(String? status) {
    final (label, icon, color) = switch (status) {
      'syncing' => (
        'Syncing',
        Icons.sync,
        Theme.of(context).colorScheme.primary,
      ),
      'synced' => ('Synced', Icons.cloud_done_outlined, Colors.green.shade700),
      'failed' => (
        'Failed · retry available',
        Icons.error_outline,
        Colors.red.shade700,
      ),
      _ => (
        'Pending sync',
        Icons.cloud_upload_outlined,
        Colors.orange.shade800,
      ),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class EmployeeTaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> assignment;

  const EmployeeTaskDetailScreen({super.key, required this.assignment});

  @override
  State<EmployeeTaskDetailScreen> createState() =>
      _EmployeeTaskDetailScreenState();
}

class _EmployeeTaskDetailScreenState extends State<EmployeeTaskDetailScreen> {
  late String status;
  late final TextEditingController notesController;
  bool queueing = false;
  bool changed = false;
  String? syncStatus;
  String? syncError;
  String? queueId;

  static const statuses = ['assigned', 'in_progress', 'completed', 'on_hold'];

  @override
  void initState() {
    super.initState();
    status = widget.assignment['status']?.toString() ?? 'assigned';
    syncStatus = widget.assignment['sync_status']?.toString();
    syncError = widget.assignment['sync_error']?.toString();
    queueId = widget.assignment['sync_queue_id']?.toString();
    notesController = TextEditingController(
      text: widget.assignment['progress_notes']?.toString() ?? '',
    );
    OfflineSyncService.queueRevision.addListener(_refreshSyncState);
    _refreshSyncState();
  }

  Future<void> _refreshSyncState() async {
    final assignmentId = widget.assignment['id']?.toString();
    if (assignmentId == null) return;
    try {
      final state = await OfflineSyncService.getTaskSyncState(assignmentId);
      if (state == null || !mounted) return;
      setState(() {
        syncStatus = state['sync_status']?.toString();
        syncError = state['last_error']?.toString();
        queueId = state['queue_id']?.toString();
        if (state['sync_status'] != 'synced' && state['status'] != null) {
          status = state['status'].toString();
        }
      });
    } catch (_) {
      // The selected local status remains available if queue details cannot be read.
    }
  }

  Future<void> _queueProgress(String nextStatus) async {
    if (queueing) return;
    final previousStatus = status;
    final previousSyncStatus = syncStatus;
    final previousSyncError = syncError;
    final previousQueueId = queueId;
    final previousChanged = changed;
    setState(() {
      status = nextStatus;
      syncStatus = 'waiting';
      syncError = null;
      queueing = true;
      changed = true;
    });
    try {
      final id = await OfflineSyncService.queueTaskStatusUpdate(
        assignment: widget.assignment,
        status: nextStatus,
        progressNotes: notesController.text,
      );
      if (!mounted) return;
      setState(() {
        queueId = id;
        queueing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Progress saved on this device. Sync will continue automatically.',
          ),
        ),
      );
      _refreshSyncState();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        status = previousStatus;
        syncStatus = previousSyncStatus;
        syncError = previousSyncError;
        queueId = previousQueueId;
        queueing = false;
        changed = previousChanged;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ArgumentError
                ? error.message.toString()
                : 'Unable to save this update on the device.',
          ),
        ),
      );
    }
  }

  Future<void> _retrySync() async {
    final id = queueId;
    if (id == null || queueing) return;
    setState(() => queueing = true);
    try {
      await OfflineSyncService.retryQueueItem(id);
    } finally {
      if (mounted) {
        setState(() => queueing = false);
        await _refreshSyncState();
      }
    }
  }

  @override
  void dispose() {
    OfflineSyncService.queueRevision.removeListener(_refreshSyncState);
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.assignment['task'] is Map
        ? Map<String, dynamic>.from(widget.assignment['task'])
        : <String, dynamic>{};
    final project = task['project'] is Map
        ? task['project']['name']?.toString()
        : null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context, changed),
          icon: const BackButtonIcon(),
          tooltip: 'Back',
        ),
        title: const Text('Task details'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  task['title']?.toString() ?? 'Task',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(width: 12),
              AppStatusBadge(status: status),
            ],
          ),
          if (project != null) ...[
            const SizedBox(height: 8),
            Text('Project: $project'),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task details',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  Text('Priority  ·  ${task['priority'] ?? 'normal'}'),
                  const SizedBox(height: 6),
                  Text(
                    'Due date  ·  ${task['due_date']?.toString().split("T").first ?? 'Not set'}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Assigned  ·  ${widget.assignment['assigned_at']?.toString().split("T").first ?? '—'}',
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Text(
                    task['description']?.toString() ??
                        'No description provided.',
                  ),
                ],
              ),
            ),
          ),
          const AppSectionHeader(
            title: 'Update progress',
            subtitle: 'Your changes are shared with your manager',
          ),
          DropdownButtonFormField<String>(
            initialValue: statuses.contains(status) ? status : 'assigned',
            decoration: const InputDecoration(labelText: 'Progress status'),
            items: statuses
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.replaceAll('_', ' ')),
                  ),
                )
                .toList(),
            onChanged: queueing || syncStatus == 'failed'
                ? null
                : (value) {
                    if (value != null && value != status) {
                      _queueProgress(value);
                    }
                  },
          ),
          if (syncStatus != null) ...[
            const SizedBox(height: 10),
            _syncStatePanel(),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: notesController,
            minLines: 3,
            maxLines: 6,
            maxLength: 3000,
            decoration: const InputDecoration(
              labelText: 'Progress notes',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: queueing || syncStatus == 'failed'
                ? null
                : () => _queueProgress(status),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save progress and notes'),
          ),
        ],
      ),
    );
  }

  Widget _syncStatePanel() {
    final (label, icon, color) = switch (syncStatus) {
      'syncing' => (
        'Syncing',
        Icons.sync,
        Theme.of(context).colorScheme.primary,
      ),
      'synced' => ('Synced', Icons.cloud_done_outlined, Colors.green.shade700),
      'failed' => (
        'Failed — retry available',
        Icons.error_outline,
        Colors.red.shade700,
      ),
      _ => (
        'Pending sync',
        Icons.cloud_upload_outlined,
        Colors.orange.shade800,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
              if (syncStatus == 'failed')
                TextButton(
                  onPressed: queueing ? null : _retrySync,
                  child: const Text('Retry'),
                ),
            ],
          ),
          if (syncError != null && syncError!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                syncError!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
