import 'package:flutter/material.dart';
import '../../components/logout_action.dart';

import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';
import '../../components/app_loader.dart';
import '../../components/app_error.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  late final AutoRefreshController _autoRefresh;
  bool _requestInFlight = false;
  bool _hasLoaded = false;
  List<dynamic> attendance = [];

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _autoRefresh = AutoRefreshController(owner: this, onRefresh: getAttendance)
      ..start();
    getAttendance();
  }

  Future<void> getAttendance() async {
    if (!mounted || _requestInFlight) return;
    _requestInFlight = true;
    if (!_hasLoaded && !loading) setState(() => loading = true);

    try {
      final response = await ApiService.get('/admin/attendance');
      if (!mounted) return;

      if (ApiService.isSuccess(response['status'])) {
        setState(() {
          attendance = response['data']['attendance'] ?? [];
          loading = false;
          error = null;
          _hasLoaded = true;
        });
      } else {
        setState(() {
          if (!_hasLoaded) {
            error = response['data']['message'] ?? 'Failed to load attendance';
          }
          loading = false;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!_hasLoaded) error = 'Something went wrong';
          loading = false;
          _hasLoaded = true;
        });
      }
    } finally {
      _requestInFlight = false;
    }
  }

  @override
  void dispose() {
    _autoRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: const [LogoutAction()],
      ),
      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: getAttendance)
          : attendance.isEmpty
          ? const Center(child: Text('No attendance records found'))
          : RefreshIndicator(
              onRefresh: getAttendance,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: attendance.length,
                itemBuilder: (context, index) {
                  final record = attendance[index];

                  final employee = record['employee'];

                  final user = employee?['user'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.access_time),
                      ),
                      title: Text(
                        user?['name'] ?? 'Unknown Employee',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Employee ID: '
                        '${employee?['employee_id'] ?? '-'}\n'
                        'Date: '
                        '${record['attendance_date'] ?? '-'}\n'
                        'Status: '
                        '${record['status'] ?? '-'}\n'
                        'Check In: '
                        '${record['check_in'] ?? '-'}\n'
                        'Check Out: '
                        '${record['check_out'] ?? '-'}',
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
