import 'package:flutter/material.dart';

import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../components/logout_action.dart';
import '../../services/api_service.dart';

class ManagementFeedbackScreen extends StatefulWidget {
  const ManagementFeedbackScreen({super.key});

  @override
  State<ManagementFeedbackScreen> createState() =>
      _ManagementFeedbackScreenState();
}

class _ManagementFeedbackScreenState extends State<ManagementFeedbackScreen> {
  List<Map<String, dynamic>> feedback = [];
  String category = 'all';
  String status = 'all';
  bool loading = true;
  String? error;

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    final params = <String, String>{};
    if (category != 'all') params['category'] = category;
    if (status != 'all') params['status'] = status;
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((entry) => '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}').join('&')}';
    try {
      final response = await ApiService.get('/management/feedback$query');
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
      final paginator = response['data'] is Map
          ? response['data']['feedback']
          : null;
      final rows = paginator is Map ? paginator['data'] : paginator;
      setState(() {
        feedback = rows is List
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
          error = 'Unable to load employee feedback.';
          loading = false;
        });
      }
    }
  }

  Future<void> editFeedback(Map<String, dynamic> record) async {
    var nextStatus = record['status']?.toString() ?? 'new';
    final notes = TextEditingController(
      text: record['internal_remarks']?.toString() ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, refreshDialog) => AlertDialog(
          title: Text(record['subject']?.toString() ?? 'Feedback details'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From: ${record['author'] is Map ? record['author']['name'] ?? record['author']['email'] : 'Employee'}',
                  ),
                  Text('Category: ${record['category'] ?? 'other'}'),
                  if (record['rating'] != null)
                    Text('Rating: ${record['rating']} / 5'),
                  const SizedBox(height: 12),
                  Text(record['message']?.toString() ?? ''),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: nextStatus,
                    decoration: const InputDecoration(
                      labelText: 'Handling status',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'new', child: Text('New')),
                      DropdownMenuItem(
                        value: 'reviewing',
                        child: Text('Reviewing'),
                      ),
                      DropdownMenuItem(
                        value: 'resolved',
                        child: Text('Resolved'),
                      ),
                    ],
                    onChanged: (value) =>
                        refreshDialog(() => nextStatus = value!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    maxLength: 5000,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Internal HR remarks',
                      alignLabelWithHint: true,
                    ),
                  ),
                  Text(
                    'Internal remarks are visible to HR/Admin only.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () async {
                final response = await ApiService.patch(
                  '/management/feedback/${record['id']}',
                  {'status': nextStatus, 'internal_remarks': notes.text},
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
              child: const Text('Save review'),
            ),
          ],
        ),
      ),
    );
    notes.dispose();
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
        title: const Text('Employee Feedback'),
        actions: const [LogoutAction()],
      ),
      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: load)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    children: [
                      _filter(
                        'Category',
                        category,
                        const [
                          'all',
                          'workplace',
                          'payroll',
                          'benefits',
                          'management',
                          'other',
                        ],
                        (value) => setState(() => category = value),
                      ),
                      _filter('Status', status, const [
                        'all',
                        'new',
                        'reviewing',
                        'resolved',
                      ], (value) => setState(() => status = value)),
                      OutlinedButton.icon(
                        onPressed: load,
                        icon: const Icon(Icons.filter_alt),
                        label: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: feedback.isEmpty
                      ? const Center(
                          child: Text('No feedback matches these filters.'),
                        )
                      : RefreshIndicator(
                          onRefresh: load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: feedback.length,
                            itemBuilder: (context, index) {
                              final record = feedback[index];
                              final author = record['author'] is Map
                                  ? record['author']['name']?.toString() ??
                                        'Employee'
                                  : 'Employee';
                              return Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.feedback_outlined),
                                  ),
                                  title: Text(
                                    record['subject']?.toString() ?? 'Feedback',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$author  •  ${record['category'] ?? 'other'}  •  ${record['created_at'] ?? ''}\n${record['message'] ?? ''}',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  isThreeLine: true,
                                  trailing: Text(
                                    (record['status']?.toString() ?? 'new')
                                        .toUpperCase(),
                                  ),
                                  onTap: () => editFeedback(record),
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

  Widget _filter(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButton<String>(
      value: value,
      hint: Text(label),
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                item == 'all'
                    ? 'All $label'
                    : item[0].toUpperCase() + item.substring(1),
              ),
            ),
          )
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}
