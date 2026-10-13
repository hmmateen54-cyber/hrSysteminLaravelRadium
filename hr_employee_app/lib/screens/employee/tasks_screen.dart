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
      try {
        await OfflineSyncService.saveCachedItems('tasks', remote);
        final saved = await OfflineSyncService.readCachedItems('tasks');
        cacheFetchedAt = saved?['fetched_at']?.toString();
      } catch (_) {
        // Keep the live response even if the local cache cannot be updated.
      }
      setState(() {
        assignments = remote;
        offlineMode = false;
        error = null;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          offlineMode = cached != null;
          error = offlineMode ? null : 'Unable to reach the task service.';
          loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    loadTasks();
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
            'Due: ${task['due_date'] ?? 'Not set'}',
            'Status: ${status.replaceAll('_', ' ')}',
          ].join('  •  '),
        ),
        trailing: AppStatusBadge(status: status),
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
  bool saving = false;

  static const statuses = ['assigned', 'in_progress', 'completed', 'on_hold'];

  @override
  void initState() {
    super.initState();
    status = widget.assignment['status']?.toString() ?? 'assigned';
    notesController = TextEditingController(
      text: widget.assignment['progress_notes']?.toString() ?? '',
    );
  }

  Future<void> saveProgress() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final id = widget.assignment['id'];
      final response = await ApiService.patch('/employee/tasks/$id/progress', {
        'status': status,
        'progress_notes': notesController.text,
      });
      if (!mounted) return;
      if (ApiService.isSuccess(response['status'])) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiService.messageFromResponse(
                response['data'],
                response['status'],
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save task progress.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
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
      appBar: AppBar(title: const Text('Task details')),
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
                  Text('Due date  ·  ${task['due_date'] ?? 'Not set'}'),
                  const SizedBox(height: 6),
                  Text(
                    'Assigned  ·  ${widget.assignment['assigned_at'] ?? '—'}',
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
            onChanged: saving
                ? null
                : (value) => setState(() => status = value!),
          ),
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
            onPressed: saving ? null : saveProgress,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Saving…' : 'Save progress'),
          ),
        ],
      ),
    );
  }
}
