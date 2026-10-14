import 'package:flutter/material.dart';

import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../components/dashboard_card.dart';
import '../../components/logout_action.dart';
import '../../services/api_service.dart';
import 'hr_attendance_screen.dart';
import 'hr_employees_screen.dart';
import 'hr_leaves_screen.dart';
import 'hr_performance_screen.dart';

class HRDashboardScreen extends StatefulWidget {
  const HRDashboardScreen({super.key});

  @override
  State<HRDashboardScreen> createState() => _HRDashboardScreenState();
}

class _HRDashboardScreenState extends State<HRDashboardScreen> {
  bool loading = true;
  String? error;
  Map<String, dynamic> dashboard = {};

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await ApiService.get('/hr/dashboard');
      if (!mounted) return;

      if (ApiService.isSuccess(response['status']) && response['data'] is Map) {
        setState(() {
          dashboard = Map<String, dynamic>.from(response['data']);
          loading = false;
        });
      } else {
        final data = response['data'];
        setState(() {
          error = data is Map
              ? data['message']?.toString() ?? 'Failed to load dashboard'
              : ApiService.messageForStatus(response['status']);
          loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Unable to load dashboard. Check your connection and retry.';
        loading = false;
      });
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HR Dashboard'),
        actions: const [LogoutAction()],
      ),
      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: loadDashboard)
          : RefreshIndicator(
              onRefresh: loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'HR Overview',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      DashboardCard(
                        icon: Icons.people,
                        title:
                            'Employees\n${dashboard['total_employees'] ?? 0}',
                        onTap: () => _open(const HREmployeesScreen()),
                      ),
                      DashboardCard(
                        icon: Icons.access_time,
                        title:
                            'Attendance\n${dashboard['total_attendance'] ?? 0}',
                        onTap: () => _open(const HRAttendanceScreen()),
                      ),
                      DashboardCard(
                        icon: Icons.pending_actions,
                        title:
                            'Pending Leaves\n${dashboard['pending_leaves'] ?? 0}',
                        onTap: () => _open(const HRLeavesScreen()),
                      ),
                      DashboardCard(
                        icon: Icons.check_circle,
                        title:
                            'Approved Leaves\n${dashboard['approved_leaves'] ?? 0}',
                        onTap: () => _open(const HRLeavesScreen()),
                      ),
                      DashboardCard(
                        icon: Icons.cancel_outlined,
                        title:
                            'Rejected Leaves\n${dashboard['rejected_leaves'] ?? 0}',
                        onTap: () => _open(const HRLeavesScreen()),
                      ),
                      DashboardCard(
                        icon: Icons.star,
                        title:
                            'Performance\n${dashboard['performance_records'] ?? 0}',
                        onTap: () => _open(const HRPerformanceScreen()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
