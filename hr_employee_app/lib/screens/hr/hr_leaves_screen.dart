import 'package:flutter/material.dart';
import '../../components/logout_action.dart';

import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';
import '../../theme/app_colors.dart';

class HRLeavesScreen extends StatefulWidget {
  const HRLeavesScreen({super.key});

  @override
  State<HRLeavesScreen> createState() => _HRLeavesScreenState();
}

class _HRLeavesScreenState extends State<HRLeavesScreen> {
  late final AutoRefreshController _autoRefresh;
  bool _requestInFlight = false;
  int _mutationRevision = 0;
  bool loading = true;
  String? error;

  List<dynamic> leaves = [];
  final Set<int> _updatingLeaveIds = {};

  @override
  void initState() {
    super.initState();
    _autoRefresh = AutoRefreshController(owner: this, onRefresh: loadLeaves)
      ..start();
    loadLeaves();
  }

  Future<void> loadLeaves() async {
    if (!mounted || _requestInFlight) return;
    _requestInFlight = true;
    final requestRevision = _mutationRevision;
    if (leaves.isEmpty && !loading) setState(() => loading = true);

    try {
      final response = await ApiService.get('/hr/leaves');

      if (!mounted || requestRevision != _mutationRevision) return;

      if (ApiService.isSuccess(response['status']) && response['data'] is Map) {
        setState(() {
          leaves = response['data']['leaves'] ?? [];
          loading = false;
          error = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          final data = response['data'];
          final message = data is Map
              ? data['message']?.toString() ?? 'Failed to load leaves'
              : ApiService.messageForStatus(response['status']);
          loading = false;
          if (leaves.isEmpty) error = message;
        });
      }
    } catch (e) {
      if (!mounted || requestRevision != _mutationRevision) return;
      setState(() {
        if (leaves.isEmpty) error = 'Something went wrong';
        loading = false;
      });
    } finally {
      _requestInFlight = false;
    }
  }

  @override
  void dispose() {
    _autoRefresh.dispose();
    super.dispose();
  }

  Future<void> updateLeaveStatus(int leaveId, String status) async {
    final remarksController = TextEditingController();

    final remarks = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(status == 'approved' ? 'Approve Leave' : 'Reject Leave'),
          content: TextField(
            controller: remarksController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Remarks',
              hintText: 'Enter remarks (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, remarksController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'approved'
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.error,
              ),
              child: Text(status == 'approved' ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );

    if (remarks == null) {
      remarksController.dispose();
      return;
    }

    if (_updatingLeaveIds.contains(leaveId)) {
      remarksController.dispose();
      return;
    }
    setState(() => _updatingLeaveIds.add(leaveId));

    try {
      final response = await ApiService.patch('/hr/leaves/$leaveId/status', {
        'status': status,
        'admin_remarks': remarks,
      });

      if (ApiService.isSuccess(response['status'])) {
        if (!mounted) return;
        _mutationRevision++;

        final updated = response['data'] is Map
            ? response['data']['leave']
            : null;
        if (updated is Map) {
          setState(() {
            leaves = leaves.map((item) {
              if (item is Map && '${item['id']}' == '$leaveId') {
                return Map<String, dynamic>.from(updated);
              }
              return item;
            }).toList();
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave status updated successfully')),
        );
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['data'] is Map
                  ? response['data']['message'] ?? 'Failed to update leave'
                  : ApiService.messageForStatus(response['status']),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Something went wrong')));
    } finally {
      remarksController.dispose();
      if (mounted) setState(() => _updatingLeaveIds.remove(leaveId));
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Management'),
        actions: const [LogoutAction()],
      ),
      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: loadLeaves)
          : RefreshIndicator(
              onRefresh: loadLeaves,
              child: leaves.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: 250),
                        Center(child: Text('No leave requests found')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: leaves.length,
                      itemBuilder: (context, index) {
                        final leave = leaves[index];

                        final employee = leave['employee'];
                        final user = employee?['user'];

                        final status = (leave['status'] ?? 'pending')
                            .toString();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        user?['name'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(status.toUpperCase()),
                                      backgroundColor: statusColor(
                                        status,
                                      ).withValues(alpha: 0.15),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  'Employee ID: '
                                  '${employee?['employee_id'] ?? '-'}',
                                ),

                                Text(
                                  'Leave Type: '
                                  '${leave['leave_type'] ?? '-'}',
                                ),

                                Text(
                                  'Start: '
                                  '${leave['start_date'] ?? '-'}',
                                ),

                                Text(
                                  'End: '
                                  '${leave['end_date'] ?? '-'}',
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  'Reason: '
                                  '${leave['reason'] ?? '-'}',
                                ),

                                if (leave['admin_remarks'] != null &&
                                    leave['admin_remarks']
                                        .toString()
                                        .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Remarks: '
                                      '${leave['admin_remarks']}',
                                    ),
                                  ),

                                const SizedBox(height: 12),

                                if (status.toLowerCase() == 'pending')
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              _updatingLeaveIds.contains(
                                                leave['id'],
                                              )
                                              ? null
                                              : () {
                                                  updateLeaveStatus(
                                                    leave['id'],
                                                    'approved',
                                                  );
                                                },
                                          icon: const Icon(Icons.check),
                                          label: const Text('Approve'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              _updatingLeaveIds.contains(
                                                leave['id'],
                                              )
                                              ? null
                                              : () {
                                                  updateLeaveStatus(
                                                    leave['id'],
                                                    'rejected',
                                                  );
                                                },
                                          icon: const Icon(Icons.close),
                                          label: const Text('Reject'),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
