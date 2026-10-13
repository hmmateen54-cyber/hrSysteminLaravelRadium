import 'package:flutter/material.dart';
import '../../components/logout_action.dart';

import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';
import '../../components/app_loader.dart';
import '../../components/app_error.dart';
import '../../theme/app_colors.dart';

class AdminLeavesScreen extends StatefulWidget {
  const AdminLeavesScreen({super.key});

  @override
  State<AdminLeavesScreen> createState() => _AdminLeavesScreenState();
}

class _AdminLeavesScreenState extends State<AdminLeavesScreen> {
  late final AutoRefreshController _autoRefresh;
  bool _requestInFlight = false;
  int _mutationRevision = 0;
  final Set<int> _updatingLeaveIds = {};

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
              labelText: 'Admin Remarks',
              hintText: 'Enter remarks...',
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
                Navigator.pop(context, remarksController.text);
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
      final response = await ApiService.patch('/admin/leaves/$leaveId/status', {
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

  List<dynamic> leaves = [];

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _autoRefresh = AutoRefreshController(owner: this, onRefresh: getLeaves)
      ..start();
    getLeaves();
  }

  Future<void> getLeaves() async {
    if (!mounted || _requestInFlight) return;
    _requestInFlight = true;
    final requestRevision = _mutationRevision;
    if (leaves.isEmpty && !loading) setState(() => loading = true);

    try {
      final response = await ApiService.get('/admin/leaves');

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

  Color getStatusColor(String status) {
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
          ? AppError(message: error!, onRetry: getLeaves)
          : leaves.isEmpty
          ? const Center(child: Text('No leave requests found'))
          : RefreshIndicator(
              onRefresh: getLeaves,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: leaves.length,
                itemBuilder: (context, index) {
                  final leave = leaves[index];

                  final employee = leave['employee'];

                  final user = employee?['user'];

                  final status = leave['status'] ?? 'pending';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(child: Icon(Icons.event_note)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  user?['name'] ?? 'Unknown Employee',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                status.toString().toUpperCase(),
                                style: TextStyle(
                                  color: getStatusColor(status.toString()),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          Text(
                            'Employee ID: '
                            '${employee?['employee_id'] ?? '-'}',
                          ),

                          Text(
                            'Leave Type: '
                            '${leave['leave_type'] ?? '-'}',
                          ),

                          Text(
                            'Start Date: '
                            '${leave['start_date'] ?? '-'}',
                          ),

                          Text(
                            'End Date: '
                            '${leave['end_date'] ?? '-'}',
                          ),

                          Text(
                            'Reason: '
                            '${leave['reason'] ?? 'No reason'}',
                          ),

                          Text(
                            'Remarks: '
                            '${leave['admin_remarks'] ?? '-'}',
                          ),

                          const SizedBox(height: 12),

                          if (status.toString().toLowerCase() == 'pending')
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _updatingLeaveIds.contains(leave['id'])
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
                                        _updatingLeaveIds.contains(leave['id'])
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
