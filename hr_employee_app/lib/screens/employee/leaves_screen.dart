import 'package:flutter/material.dart';

import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../components/logout_action.dart';
import '../../services/api_service.dart';
import '../../services/offline_sync_service.dart';
import 'apply_leave_screen.dart';

class LeavesScreen extends StatefulWidget {
  const LeavesScreen({super.key});

  @override
  State<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen> {
  List<Map<String, dynamic>> leaves = [];
  bool loading = true;
  String? error;
  final Set<String> _retrying = {};

  @override
  void initState() {
    super.initState();
    getLeaves();
  }

  Future<void> getLeaves() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    List<Map<String, dynamic>> local = [];
    try {
      local = await OfflineSyncService.getQueueItems(operation: 'leave');
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Offline request storage is unavailable.');
      }
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
        });
      } else {
        final data = response['data'];
        final message = data is Map
            ? data['message']?.toString() ??
                  ApiService.messageForStatus(response['status'])
            : ApiService.messageForStatus(response['status']);
        setState(() {
          leaves = local;
          error = message;
          loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        leaves = local;
        error =
            'Unable to reach the server. Saved offline requests remain on this device.';
        loading = false;
      });
    }
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leaves'),
        actions: const [LogoutAction()],
      ),
      body: loading
          ? const AppLoader()
          : error != null && leaves.isEmpty
          ? AppError(message: error!, onRetry: getLeaves)
          : RefreshIndicator(
              onRefresh: () async {
                await OfflineSyncService.syncPendingLeaves(force: true);
                await getLeaves();
              },
              child: leaves.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 220),
                        Center(child: Text('No leave requests found')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: leaves.length + (error == null ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (error != null && index == 0) {
                          return Card(
                            color: Colors.orange.shade50,
                            child: ListTile(
                              leading: const Icon(Icons.cloud_off),
                              title: Text(error!),
                              trailing: IconButton(
                                tooltip: 'Retry sync',
                                onPressed: () async {
                                  await OfflineSyncService.syncPendingLeaves(
                                    force: true,
                                  );
                                  await getLeaves();
                                },
                                icon: const Icon(Icons.refresh),
                              ),
                            ),
                          );
                        }

                        final leave = leaves[index - (error == null ? 0 : 1)];
                        final local = leave.containsKey('sync_status');
                        final status = local
                            ? _localStatus(leave)
                            : (leave['status'] ?? 'pending').toString();
                        final color = local
                            ? (leave['sync_status'] == 'failed'
                                  ? Colors.red
                                  : leave['sync_status'] == 'synced'
                                  ? Colors.green
                                  : Colors.blue)
                            : status == 'approved'
                            ? Colors.green
                            : status == 'rejected'
                            ? Colors.red
                            : Colors.orange;
                        final queueId = leave['queue_id']?.toString();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: .12),
                              child: Icon(
                                local
                                    ? Icons.cloud_upload_outlined
                                    : Icons.event_note,
                                color: color,
                              ),
                            ),
                            title: Text(
                              leave['leave_type']?.toString() ??
                                  'Leave request',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${leave['start_date']} → ${leave['end_date']}\n'
                                  '${leave['reason'] ?? 'No reason'}',
                                ),
                                if (local) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    leave['sync_status'] == 'synced'
                                        ? 'Server confirmed; waiting for the leave list to refresh.'
                                        : 'Saved on this device. It has not reached the server yet.',
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (leave['last_error'] != null)
                                    Text(
                                      leave['last_error'].toString(),
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  if (queueId != null &&
                                      leave['sync_status'] == 'failed')
                                    TextButton.icon(
                                      onPressed: () => _edit(leave),
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Edit request'),
                                    )
                                  else if (queueId != null &&
                                      leave['sync_status'] != 'synced')
                                    TextButton.icon(
                                      onPressed: _retrying.contains(queueId)
                                          ? null
                                          : () => _retry(leave),
                                      icon: const Icon(Icons.sync),
                                      label: Text(
                                        _retrying.contains(queueId)
                                            ? 'Syncing…'
                                            : 'Retry sync',
                                      ),
                                    ),
                                ],
                              ],
                            ),
                            isThreeLine: true,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(const {}),
        child: const Icon(Icons.add),
      ),
    );
  }
}
