import 'package:flutter/material.dart';

import '../../components/app_button.dart';
import '../../components/app_text_field.dart';
import '../../components/logout_action.dart';
import '../../services/api_service.dart';
import '../../services/offline_sync_service.dart';

class ApplyLeaveScreen extends StatefulWidget {
  final String? queueId;
  final Map<String, dynamic>? existingLeave;

  const ApplyLeaveScreen({super.key, this.queueId, this.existingLeave});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final startDateController = TextEditingController();
  final endDateController = TextEditingController();
  final reasonController = TextEditingController();

  String leaveType = 'Casual';
  String? queueId;
  int? serverLeaveId;
  String? loadError;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    queueId = widget.queueId;
    final existingLeave = widget.existingLeave;
    if (existingLeave != null) {
      serverLeaveId = int.tryParse(existingLeave['id']?.toString() ?? '');
      startDateController.text = existingLeave['start_date']?.toString() ?? '';
      endDateController.text = existingLeave['end_date']?.toString() ?? '';
      reasonController.text = existingLeave['reason']?.toString() ?? '';
      leaveType = existingLeave['leave_type']?.toString() ?? leaveType;
    } else if (queueId != null) {
      _loadQueuedRequest();
    }
  }

  Future<void> _loadQueuedRequest() async {
    try {
      final rows = await OfflineSyncService.getQueueItems(operation: 'leave');
      final matches = rows.where((row) => row['queue_id'] == queueId);
      if (matches.isEmpty) {
        if (mounted) {
          setState(() => loadError = 'This saved request could not be found.');
        }
        return;
      }
      final leave = matches.first;
      startDateController.text = leave['start_date']?.toString() ?? '';
      endDateController.text = leave['end_date']?.toString() ?? '';
      reasonController.text = leave['reason']?.toString() ?? '';
      if (mounted) {
        setState(() {
          leaveType = leave['leave_type']?.toString() ?? leaveType;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loadError = 'Unable to open the saved request.');
      }
    }
  }

  Future<void> _chooseDate(TextEditingController controller) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(controller.text);
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    controller.text =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> submitLeave() async {
    final start = DateTime.tryParse(startDateController.text.trim());
    final end = DateTime.tryParse(endDateController.text.trim());
    if (start == null || end == null || end.isBefore(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter valid dates and make sure the end date is not before the start date.',
          ),
        ),
      );
      return;
    }
    if (leaveType.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose a leave type.')));
      return;
    }

    setState(() => loading = true);
    try {
      if (serverLeaveId != null) {
        final response =
            await ApiService.patch('/employee/leaves/$serverLeaveId', {
              'start_date': startDateController.text.trim(),
              'end_date': endDateController.text.trim(),
              'leave_type': leaveType,
              'reason': reasonController.text,
            });
        if (!mounted) return;
        if (!ApiService.isSuccess(response['status'])) {
          final message = ApiService.messageFromResponse(
            response['data'],
            response['status'],
          );
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pending leave request updated.')),
        );
        Navigator.pop(context, true);
        return;
      }

      queueId = await OfflineSyncService.queueLeaveRequest(
        startDate: startDateController.text.trim(),
        endDate: endDateController.text.trim(),
        leaveType: leaveType,
        reason: reasonController.text,
        queueId: queueId,
      );
      await OfflineSyncService.syncPendingLeaves(force: true);
      final queue = await OfflineSyncService.getQueueItems(operation: 'leave');
      final matching = queue
          .where((row) => row['queue_id'] == queueId)
          .toList();
      final item = matching.isEmpty ? null : matching.first;

      if (!mounted) return;
      if (item?['sync_status'] == 'failed') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              item?['last_error']?.toString() ??
                  'The server rejected this request.',
            ),
          ),
        );
        return;
      }

      final message = item?['sync_status'] == 'synced'
          ? 'The server confirmed your leave request.'
          : 'Saved offline. This request has not reached the server yet.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ArgumentError
                ? error.message.toString()
                : 'Could not save the request on this device.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    startDateController.dispose();
    endDateController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          serverLeaveId != null
              ? 'Edit Pending Leave'
              : queueId == null
              ? 'Apply Leave'
              : 'Edit Saved Leave',
        ),
        actions: const [LogoutAction()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (loadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  loadError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            GestureDetector(
              onTap: () => _chooseDate(startDateController),
              child: AbsorbPointer(
                child: AppTextField(
                  controller: startDateController,
                  label: 'Start Date',
                  hint: 'YYYY-MM-DD',
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _chooseDate(endDateController),
              child: AbsorbPointer(
                child: AppTextField(
                  controller: endDateController,
                  label: 'End Date',
                  hint: 'YYYY-MM-DD',
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: leaveType,
              decoration: const InputDecoration(
                labelText: 'Leave Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Casual', child: Text('Casual')),
                DropdownMenuItem(value: 'Sick', child: Text('Sick')),
                DropdownMenuItem(value: 'Annual', child: Text('Annual')),
                DropdownMenuItem(value: 'Emergency', child: Text('Emergency')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => leaveType = value);
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: reasonController,
              label: 'Reason',
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            AppButton(
              text: serverLeaveId != null
                  ? 'Save Changes'
                  : queueId == null
                  ? 'Submit Leave'
                  : 'Save and Retry',
              loading: loading,
              onPressed: submitLeave,
            ),
          ],
        ),
      ),
    );
  }
}
