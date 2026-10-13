import 'package:flutter/material.dart';
import '../../components/logout_action.dart';
import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';

class HRAttendanceScreen extends StatefulWidget {
  const HRAttendanceScreen({super.key});

  @override
  State<HRAttendanceScreen> createState() => _HRAttendanceScreenState();
}

class _HRAttendanceScreenState extends State<HRAttendanceScreen> {
  late final AutoRefreshController _autoRefresh;
  bool _requestInFlight = false;
  bool _hasLoaded = false;
  bool loading = true;
  String? error;

  List<dynamic> attendance = [];

  @override
  void initState() {
    super.initState();
    _autoRefresh = AutoRefreshController(owner: this, onRefresh: loadAttendance)
      ..start();
    loadAttendance();
  }

  Future<void> loadAttendance() async {
    if (!mounted || _requestInFlight) return;
    _requestInFlight = true;
    if (!_hasLoaded && !loading) setState(() => loading = true);

    try {
      final response = await ApiService.get('/hr/attendance');
      if (!mounted) return;

      if (response['status'] == 200) {
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
          ? AppError(message: error!, onRetry: loadAttendance)
          : RefreshIndicator(
              onRefresh: loadAttendance,
              child: attendance.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: 250),
                        Center(child: Text('No attendance records found')),
                      ],
                    )
                  : ListView.builder(
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
                              user?['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
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
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
