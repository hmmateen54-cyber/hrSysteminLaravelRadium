import 'admin_leaves_screen.dart';
import 'admin_employees_screen.dart';
import 'package:flutter/material.dart';
import '../../components/logout_action.dart';
import '../../components/dashboard_card.dart';
import '../../services/api_service.dart';
import '../../components/app_loader.dart';
import '../../components/app_error.dart';
import 'admin_attendance_screen.dart';
import 'admin_performance_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int totalUsers = 0;
  int totalEmployees = 0;
  int totalHr = 0;
  int pendingLeaves = 0;
  int approvedLeaves = 0;
  int rejectedLeaves = 0;

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    getDashboardData();
  }

  Future<void> getDashboardData() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await ApiService.get('/admin/dashboard');

      if (ApiService.isSuccess(response['status'])) {
        final data = response['data'];

        if (!mounted) return;
        setState(() {
          totalUsers = _count(data['total_users']);
          totalEmployees = _count(data['total_employees']);
          totalHr = _count(data['total_hr']);
          pendingLeaves = _count(data['pending_leaves']);
          approvedLeaves = _count(data['approved_leaves']);
          rejectedLeaves = _count(data['rejected_leaves']);
          loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          final data = response['data'];
          error = data is Map
              ? data['message']?.toString() ?? 'Failed to load dashboard'
              : ApiService.messageForStatus(response['status']);
          loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Something went wrong';
        loading = false;
      });
    }
  }

  int _count(dynamic value) =>
      value is int ? value : int.tryParse('$value') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: const [LogoutAction()],
      ),
      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: getDashboardData)
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RefreshIndicator(
                  onRefresh: getDashboardData,
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      DashboardCard(
                        icon: Icons.people,
                        title: 'Users\n$totalUsers',
                      ),

                      DashboardCard(
                        icon: Icons.event_note,
                        title:
                            'Leaves\nPending $pendingLeaves\nApproved $approvedLeaves\nRejected $rejectedLeaves',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminLeavesScreen(),
                            ),
                          );
                          await getDashboardData();
                        },
                      ),
                      DashboardCard(
                        icon: Icons.assessment,
                        title: 'Performance',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AdminPerformanceScreen(),
                            ),
                          );
                          await getDashboardData();
                        },
                      ),

                      DashboardCard(
                        icon: Icons.access_time,
                        title: 'Attendance',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AdminAttendanceScreen(),
                            ),
                          );
                          await getDashboardData();
                        },
                      ),
                      DashboardCard(
                        icon: Icons.badge,
                        title: 'Employees\n$totalEmployees',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AdminEmployeesScreen(),
                            ),
                          );
                          await getDashboardData();
                        },
                      ),

                      DashboardCard(
                        icon: Icons.admin_panel_settings,
                        title: 'HR\n$totalHr',
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
