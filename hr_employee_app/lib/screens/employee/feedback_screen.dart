import 'package:flutter/material.dart';

import '../../components/app_error.dart';
import '../../components/app_empty_state.dart';
import '../../components/app_loader.dart';
import '../../components/logout_action.dart';
import '../../components/offline_cache_banner.dart';
import '../../components/app_section_header.dart';
import '../../components/app_status_badge.dart';
import '../../services/api_service.dart';
import '../../services/offline_sync_service.dart';

class EmployeeFeedbackScreen extends StatefulWidget {
  const EmployeeFeedbackScreen({super.key});

  @override
  State<EmployeeFeedbackScreen> createState() => _EmployeeFeedbackScreenState();
}

class _EmployeeFeedbackScreenState extends State<EmployeeFeedbackScreen> {
  static const categories = [
    'workplace',
    'payroll',
    'benefits',
    'management',
    'other',
  ];

  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String category = 'workplace';
  int? rating;
  bool loading = true;
  bool submitting = false;
  bool offlineMode = false;
  String? error;
  String? cacheFetchedAt;
  List<Map<String, dynamic>> records = [];
  final Set<String> _retrying = {};

  @override
  void initState() {
    super.initState();
    OfflineSyncService.queueRevision.addListener(_onQueueChanged);
    loadFeedback();
  }

  void _onQueueChanged() => loadFeedback();

  Future<void> loadFeedback() async {
    if (!mounted) return;
    try {
      final cached = await OfflineSyncService.readCachedItems('feedback');
      final queued = await OfflineSyncService.getQueueItems(
        operation: 'feedback',
      );
      if (cached != null && mounted) {
        setState(() {
          records = _mergeFeedback(queued, cached['items'] as List? ?? []);
          cacheFetchedAt = cached['fetched_at']?.toString();
          loading = false;
        });
      }

      final response = await ApiService.get('/employee/feedback');
      if (!mounted) return;
      if (!ApiService.isSuccess(response['status'])) {
        setState(() {
          error = ApiService.messageFromResponse(
            response['data'],
            response['status'],
          );
          offlineMode = cached != null || queued.isNotEmpty;
          loading = false;
        });
        return;
      }
      final paginator = response['data'] is Map
          ? response['data']['feedback']
          : null;
      final rows = paginator is Map ? paginator['data'] : paginator;
      final remote = rows is List
          ? rows
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList()
          : <Map<String, dynamic>>[];
      await OfflineSyncService.saveCachedItems('feedback', remote);
      final saved = await OfflineSyncService.readCachedItems('feedback');
      final currentQueue = await OfflineSyncService.getQueueItems(
        operation: 'feedback',
      );
      setState(() {
        records = _mergeFeedback(currentQueue, remote);
        cacheFetchedAt = saved?['fetched_at']?.toString();
        offlineMode = false;
        error = null;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      final cached = await OfflineSyncService.readCachedItems('feedback');
      final queued = await OfflineSyncService.getQueueItems(
        operation: 'feedback',
      );
      setState(() {
        records = _mergeFeedback(queued, cached?['items'] as List? ?? []);
        cacheFetchedAt = cached?['fetched_at']?.toString();
        offlineMode = cached != null || queued.isNotEmpty;
        error = offlineMode ? null : 'Unable to reach the feedback service.';
        loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _mergeFeedback(
    List<Map<String, dynamic>> queued,
    List cachedOrRemote,
  ) {
    final remote = cachedOrRemote
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final knownIds = remote
        .map((row) => row['client_submission_id']?.toString())
        .whereType<String>()
        .toSet();
    final localOnly = queued.where(
      (row) => !knownIds.contains(row['client_id']?.toString()),
    );
    return [...localOnly, ...remote];
  }

  Future<void> submitFeedback() async {
    if (submitting) return;
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a subject and feedback message.')),
      );
      return;
    }

    setState(() => submitting = true);
    try {
      final queueId = await OfflineSyncService.queueFeedback(
        category: category,
        subject: subject,
        message: message,
        rating: rating,
      );
      await OfflineSyncService.syncPendingLeaves(force: true);
      final queued = await OfflineSyncService.getQueueItems(
        operation: 'feedback',
      );
      final matches = queued.where((row) => row['queue_id'] == queueId);
      final item = matches.isEmpty ? null : matches.first;
      if (!mounted) return;
      if (item?['sync_status'] == 'failed') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              item?['last_error']?.toString() ?? 'Feedback was rejected.',
            ),
          ),
        );
        return;
      }
      _subjectController.clear();
      _messageController.clear();
      setState(() => rating = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            item?['sync_status'] == 'synced'
                ? 'Feedback submitted and confirmed by the server.'
                : 'Feedback saved on this device and waiting to sync.',
          ),
        ),
      );
      await loadFeedback();
    } catch (exception) {
      if (mounted) {
        final message = exception is ArgumentError
            ? exception.message.toString()
            : 'Feedback could not be saved on this device.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> retry(Map<String, dynamic> record) async {
    final id = record['queue_id']?.toString();
    if (id == null || _retrying.contains(id)) return;
    setState(() => _retrying.add(id));
    try {
      await OfflineSyncService.retryQueueItem(id);
      await loadFeedback();
    } finally {
      if (mounted) setState(() => _retrying.remove(id));
    }
  }

  @override
  void dispose() {
    OfflineSyncService.queueRevision.removeListener(_onQueueChanged);
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Feedback'),
        actions: [
          IconButton(onPressed: loadFeedback, icon: const Icon(Icons.refresh)),
          const LogoutAction(),
        ],
      ),
      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: loadFeedback)
          : RefreshIndicator(
              onRefresh: loadFeedback,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const AppSectionHeader(
                    title: 'Feedback',
                    subtitle: 'Share a workplace suggestion or raise a concern',
                  ),
                  if (offlineMode)
                    OfflineCacheBanner(
                      fetchedAt: cacheFetchedAt,
                      onRetry: () async {
                        await OfflineSyncService.syncPendingLeaves(force: true);
                        await loadFeedback();
                      },
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'New submission',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Choose a category and include enough detail for HR to follow up.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: categories
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                      value[0].toUpperCase() +
                                          value.substring(1),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: submitting
                                ? null
                                : (value) => setState(() => category = value!),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _subjectController,
                            maxLength: 160,
                            decoration: const InputDecoration(
                              labelText: 'Subject',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _messageController,
                            minLines: 3,
                            maxLines: 6,
                            maxLength: 5000,
                            decoration: const InputDecoration(
                              labelText: 'Message',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Optional rating',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Skip'),
                                selected: rating == null,
                                onSelected: submitting
                                    ? null
                                    : (_) => setState(() => rating = null),
                              ),
                              for (var value = 1; value <= 5; value++)
                                ChoiceChip(
                                  label: Text('$value / 5'),
                                  selected: rating == value,
                                  onSelected: submitting
                                      ? null
                                      : (_) => setState(() => rating = value),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: submitting ? null : submitFeedback,
                            icon: submitting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_outlined),
                            label: Text(
                              submitting ? 'Submitting…' : 'Submit feedback',
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your submission is associated with your account. HR remarks are private.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your previous feedback',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (records.isEmpty)
                    const AppEmptyState(
                      icon: Icons.forum_outlined,
                      title: 'No feedback submitted',
                      description:
                          'Your past submissions and their review status will appear here.',
                    ),
                  for (final record in records) _feedbackCard(record),
                ],
              ),
            ),
    );
  }

  Widget _feedbackCard(Map<String, dynamic> record) {
    final local = record.containsKey('sync_status');
    final status = local
        ? switch (record['sync_status']) {
            'synced' => 'Server confirmed',
            'syncing' => 'Syncing',
            'failed' => 'Needs attention',
            'retry' => 'Waiting to retry',
            _ => 'Waiting to sync',
          }
        : (record['status']?.toString() ?? 'new');
    final statusKey = local
        ? switch (record['sync_status']) {
            'synced' => 'synced',
            'failed' => 'failed',
            'syncing' => 'in_progress',
            _ => 'pending',
          }
        : record['status']?.toString() ?? 'new';
    final queueId = record['queue_id']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record['subject']?.toString() ?? 'Feedback',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                AppStatusBadge(status: statusKey, label: status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${record['category'] ?? 'other'}  •  ${record['created_at'] ?? 'Saved just now'}',
            ),
            const SizedBox(height: 8),
            Text(record['message']?.toString() ?? ''),
            if (local && record['sync_status'] == 'failed' && queueId != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _retrying.contains(queueId)
                      ? null
                      : () => retry(record),
                  icon: const Icon(Icons.sync),
                  label: Text(
                    _retrying.contains(queueId)
                        ? 'Retrying…'
                        : 'Retry submission',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
