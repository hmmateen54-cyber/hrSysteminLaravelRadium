import 'package:flutter/material.dart';

import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../components/logout_action.dart';
import '../../services/api_service.dart';

class ManagementTasksScreen extends StatefulWidget {
  const ManagementTasksScreen({super.key});

  @override
  State<ManagementTasksScreen> createState() => _ManagementTasksScreenState();
}

class _ManagementTasksScreenState extends State<ManagementTasksScreen> {
  List<Map<String, dynamic>> tasks = [];
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> projects = [];
  bool loading = true;
  String? error;
  String statusFilter = 'all';
  String priorityFilter = 'all';
  String dueFilter = 'all';
  String assignmentFilter = 'all';

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.get('/management/task-options'),
        ApiService.get('/management/tasks${_queryString()}'),
      ]);
      if (!mounted) return;
      final optionsResponse = results[0];
      final taskResponse = results[1];
      if (!ApiService.isSuccess(optionsResponse['status']) ||
          !ApiService.isSuccess(taskResponse['status'])) {
        final failed = !ApiService.isSuccess(optionsResponse['status'])
            ? optionsResponse
            : taskResponse;
        setState(() {
          error = ApiService.messageFromResponse(
            failed['data'],
            failed['status'],
          );
          loading = false;
        });
        return;
      }
      final options = optionsResponse['data'];
      final taskData = taskResponse['data'];
      final paginator = taskData is Map ? taskData['tasks'] : null;
      final rows = paginator is Map ? paginator['data'] : paginator;
      setState(() {
        employees = (options is Map && options['employees'] is List)
            ? (options['employees'] as List)
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
            : [];
        projects = (options is Map && options['projects'] is List)
            ? (options['projects'] as List)
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
            : [];
        tasks = rows is List
            ? rows
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
            : [];
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Unable to load task management data.';
          loading = false;
        });
      }
    }
  }

  String _queryString() {
    final values = <String, String>{};
    if (statusFilter != 'all') values['status'] = statusFilter;
    if (priorityFilter != 'all') values['priority'] = priorityFilter;
    if (dueFilter == 'overdue') values['due'] = dueFilter;
    if (assignmentFilter == 'unassigned') {
      values['assignment'] = assignmentFilter;
    }
    if (values.isEmpty) return '';
    return '?${values.entries.map((entry) => '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
  }

  Future<void> openForm({Map<String, dynamic>? task}) async {
    final taskId = task?['id']?.toString();
    final titleController = TextEditingController(
      text: task?['title']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: task?['description']?.toString() ?? '',
    );
    final dueController = TextEditingController(
      text: task?['due_date']?.toString() ?? '',
    );
    var priority = task?['priority']?.toString() ?? 'normal';
    var projectId = task?['project_id']?.toString();
    final assigned = <int>{};
    final rawAssignments = task?['assignments'];
    if (rawAssignments is List) {
      for (final assignment in rawAssignments.whereType<Map>()) {
        final employeeId = assignment['employee'] is Map
            ? assignment['employee']['id']
            : assignment['employee_id'];
        final parsed = int.tryParse(employeeId?.toString() ?? '');
        if (parsed != null) assigned.add(parsed);
      }
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refreshDialog) => AlertDialog(
          title: Text(task == null ? 'Create task' : 'Edit task'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    maxLength: 180,
                    decoration: const InputDecoration(labelText: 'Task title'),
                  ),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 10000,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                    ],
                    onChanged: (value) =>
                        refreshDialog(() => priority = value!),
                  ),
                  if (projects.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      initialValue:
                          projects.any((row) => '${row['id']}' == projectId)
                          ? projectId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Project (optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No project'),
                        ),
                        ...projects.map(
                          (row) => DropdownMenuItem<String?>(
                            value: row['id'].toString(),
                            child: Text(row['name']?.toString() ?? 'Project'),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          refreshDialog(() => projectId = value),
                    ),
                  TextField(
                    controller: dueController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Due date',
                      hintText: 'Optional',
                      suffixIcon: IconButton(
                        tooltip: 'Choose due date',
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final now = DateTime.now();
                          final date = await showDatePicker(
                            context: dialogContext,
                            initialDate:
                                DateTime.tryParse(dueController.text) ?? now,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            dueController.text =
                                '${date.year.toString().padLeft(4, '0')}-'
                                '${date.month.toString().padLeft(2, '0')}-'
                                '${date.day.toString().padLeft(2, '0')}';
                            refreshDialog(() {});
                          }
                        },
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        dueController.clear();
                        refreshDialog(() {});
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear due date'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Assign to employees',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  if (employees.isEmpty)
                    const Text('No active employee profiles are available.')
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: employees.map((employee) {
                        final id = int.tryParse(employee['id'].toString());
                        if (id == null) return const SizedBox.shrink();
                        final name = employee['name']?.toString() ?? 'Employee';
                        return FilterChip(
                          label: Text(
                            '$name · ${employee['employee_id'] ?? ''}',
                          ),
                          selected: assigned.contains(id),
                          onSelected: (selected) => refreshDialog(() {
                            if (selected) {
                              assigned.add(id);
                            } else {
                              assigned.remove(id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a task title.')),
                  );
                  return;
                }
                final payload = {
                  'project_id': projectId == null
                      ? null
                      : int.tryParse(projectId!),
                  'title': titleController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'priority': priority,
                  'due_date': dueController.text.isEmpty
                      ? null
                      : dueController.text,
                  'employee_ids': assigned.toList(),
                };
                final response = taskId == null
                    ? await ApiService.post('/management/tasks', payload)
                    : await ApiService.patch(
                        '/management/tasks/$taskId',
                        payload,
                      );
                if (!mounted || !dialogContext.mounted) return;
                if (ApiService.isSuccess(response['status'])) {
                  Navigator.pop(dialogContext, true);
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
              },
              child: const Text('Save task'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    descriptionController.dispose();
    dueController.dispose();
    if (saved == true && mounted) load();
  }

  Future<void> manageProjects() async {
    try {
      final response = await ApiService.get('/management/projects');
      if (!mounted) return;
      if (!ApiService.isSuccess(response['status'])) {
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
        return;
      }
      final paginator = response['data'] is Map
          ? response['data']['projects']
          : null;
      final rows = paginator is Map ? paginator['data'] : paginator;
      final projectRows = rows is List
          ? rows
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      final result = await showDialog<dynamic>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Manage projects'),
          content: SizedBox(
            width: 520,
            child: projectRows.isEmpty
                ? const Text('No projects have been created yet.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: projectRows.length,
                    itemBuilder: (context, index) {
                      final project = projectRows[index];
                      return ListTile(
                        title: Text(project['name']?.toString() ?? 'Project'),
                        subtitle: Text(
                          '${project['status'] ?? 'active'}  •  ${project['tasks_count'] ?? 0} task(s)',
                        ),
                        trailing: IconButton(
                          tooltip: 'Edit project',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              Navigator.pop(dialogContext, project),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, 'new'),
              icon: const Icon(Icons.add),
              label: const Text('New project'),
            ),
          ],
        ),
      );
      if (result == 'new' && mounted) {
        await editProject();
      } else if (result is Map<String, dynamic> && mounted) {
        await editProject(project: result);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load project management.')),
        );
      }
    }
  }

  Future<void> editProject({Map<String, dynamic>? project}) async {
    final id = project?['id']?.toString();
    final name = TextEditingController(
      text: project?['name']?.toString() ?? '',
    );
    final description = TextEditingController(
      text: project?['description']?.toString() ?? '',
    );
    var status = project?['status']?.toString() ?? 'active';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refreshDialog) => AlertDialog(
          title: Text(project == null ? 'Create project' : 'Edit project'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Project name'),
                ),
                TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 5000,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Completed'),
                    ),
                    DropdownMenuItem(value: 'on_hold', child: Text('On hold')),
                  ],
                  onChanged: (value) => refreshDialog(() => status = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a project name.')),
                  );
                  return;
                }
                final payload = {
                  'name': name.text.trim(),
                  'description': description.text.trim(),
                  'status': status,
                };
                final response = id == null
                    ? await ApiService.post('/management/projects', payload)
                    : await ApiService.patch(
                        '/management/projects/$id',
                        payload,
                      );
                if (!mounted || !dialogContext.mounted) return;
                if (ApiService.isSuccess(response['status'])) {
                  Navigator.pop(dialogContext, true);
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
              },
              child: const Text('Save project'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    if (saved == true && mounted) load();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects & Tasks'),
        actions: [
          IconButton(
            tooltip: 'Manage projects',
            onPressed: manageProjects,
            icon: const Icon(Icons.folder_outlined),
          ),
          const LogoutAction(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openForm(),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: load)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _filter<String>(
                        'Status',
                        statusFilter,
                        const [
                          'all',
                          'assigned',
                          'in_progress',
                          'completed',
                          'on_hold',
                        ],
                        (v) => setState(() => statusFilter = v),
                      ),
                      _filter<String>(
                        'Priority',
                        priorityFilter,
                        const ['all', 'low', 'normal', 'high', 'urgent'],
                        (v) => setState(() => priorityFilter = v),
                      ),
                      _filter<String>('Due date', dueFilter, const [
                        'all',
                        'overdue',
                      ], (v) => setState(() => dueFilter = v)),
                      _filter<String>(
                        'Assignment',
                        assignmentFilter,
                        const ['all', 'unassigned'],
                        (v) => setState(() => assignmentFilter = v),
                      ),
                      OutlinedButton.icon(
                        onPressed: load,
                        icon: const Icon(Icons.filter_alt),
                        label: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: tasks.isEmpty
                      ? const Center(
                          child: Text('No tasks match these filters.'),
                        )
                      : RefreshIndicator(
                          onRefresh: load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              final assignments = task['assignments'] is List
                                  ? task['assignments'] as List
                                  : const [];
                              final statuses = assignments
                                  .whereType<Map>()
                                  .map(
                                    (row) =>
                                        row['status']?.toString() ?? 'assigned',
                                  )
                                  .toSet();
                              final due = DateTime.tryParse(
                                task['due_date']?.toString() ?? '',
                              );
                              final hasOpenAssignee = assignments
                                  .whereType<Map>()
                                  .any((row) => row['status'] != 'completed');
                              final overdue =
                                  due != null &&
                                  DateUtils.dateOnly(due).isBefore(
                                    DateUtils.dateOnly(DateTime.now()),
                                  ) &&
                                  hasOpenAssignee;
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: overdue
                                        ? Colors.red.withValues(alpha: .1)
                                        : null,
                                    child: Icon(
                                      overdue
                                          ? Icons.warning_amber
                                          : Icons.assignment_outlined,
                                      color: overdue ? Colors.red : null,
                                    ),
                                  ),
                                  title: Text(
                                    task['title']?.toString() ?? 'Task',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    [
                                      task['project'] is Map
                                          ? task['project']['name']
                                                    ?.toString() ??
                                                ''
                                          : '',
                                      'Priority: ${task['priority'] ?? 'normal'}',
                                      'Due: ${task['due_date'] ?? 'Not set'}${overdue ? ' · Overdue' : ''}',
                                      assignments.isEmpty
                                          ? 'Unassigned'
                                          : '${assignments.length} assignment(s): ${statuses.map((value) => value.replaceAll('_', ' ')).join(', ')}',
                                    ].where((value) => value.isNotEmpty).join('  •  '),
                                  ),
                                  isThreeLine: true,
                                  trailing: IconButton(
                                    tooltip: 'Edit task',
                                    onPressed: () => openForm(task: task),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filter<T>(
    String label,
    T value,
    List<T> values,
    ValueChanged<T> onChanged,
  ) {
    return DropdownButton<T>(
      value: value,
      hint: Text(label),
      items: values
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString().replaceAll('_', ' ')),
            ),
          )
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}
