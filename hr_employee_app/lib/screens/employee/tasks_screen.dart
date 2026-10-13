import 'package:flutter/material.dart';

import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../components/logout_action.dart';
import '../../services/api_service.dart';

class EmployeeTasksScreen extends StatefulWidget {
  const EmployeeTasksScreen({super.key});

  @override
  State<EmployeeTasksScreen> createState() => _EmployeeTasksScreenState();
}

class _EmployeeTasksScreenState extends State<EmployeeTasksScreen> {
  List<Map<String, dynamic>> assignments = [];
  bool loading = true;
  String? error;

  Future<void> loadTasks() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await ApiService.get('/employee/tasks');
      if (!mounted) return;
      if (!ApiService.isSuccess(response['status'])) {
        setState(() {
          error = ApiService.messageFromResponse(
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
      setState(() {
        assignments = rows is List
            ? rows
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
            : <Map<String, dynamic>>[];
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Unable to reach the task service.';
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
          : assignments.isEmpty
          ? const Center(child: Text('No tasks have been assigned to you.'))
          : RefreshIndicator(
              onRefresh: loadTasks,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: assignments.length,
                itemBuilder: (context, index) {
                  final assignment = assignments[index];
                  final task = assignment['task'] is Map
                      ? Map<String, dynamic>.from(assignment['task'])
                      : <String, dynamic>{};
                  final project = task['project'] is Map
                      ? task['project']['name']?.toString()
                      : null;
                  final status = assignment['status']?.toString() ?? 'assigned';
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.assignment_outlined),
                      ),
                      title: Text(
                        task['title']?.toString() ?? 'Task',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          ?project,
                          'Priority: ${task['priority'] ?? 'normal'}',
                          'Due: ${task['due_date'] ?? 'Not set'}',
                          'Status: ${status.replaceAll('_', ' ')}',
                        ].join('  •  '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmployeeTaskDetailScreen(
                              assignment: assignment,
                            ),
                          ),
                        );
                        if (changed == true && mounted) loadTasks();
                      },
                    ),
                  );
                },
              ),
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
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            task['title']?.toString() ?? 'Task',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (project != null) ...[
            const SizedBox(height: 8),
            Text('Project: $project'),
          ],
          const SizedBox(height: 12),
          Text('Priority: ${task['priority'] ?? 'normal'}'),
          Text('Due date: ${task['due_date'] ?? 'Not set'}'),
          Text('Assigned: ${widget.assignment['assigned_at'] ?? '—'}'),
          const SizedBox(height: 20),
          Text(task['description']?.toString() ?? 'No description provided.'),
          const SizedBox(height: 24),
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
