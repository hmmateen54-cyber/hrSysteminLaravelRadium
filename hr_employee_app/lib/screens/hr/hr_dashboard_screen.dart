import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../components/app_section_header.dart';
import '../../components/dashboard_card.dart';
import '../../components/logout_action.dart';
import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';
import 'hr_attendance_screen.dart';
import 'hr_employees_screen.dart';
import 'hr_leaves_screen.dart';
import 'hr_performance_screen.dart';
import 'management_tasks_screen.dart';
import 'management_feedback_screen.dart';
import 'management_locations_screen.dart';

class HRDashboardScreen extends StatefulWidget {
  const HRDashboardScreen({super.key});

  @override
  State<HRDashboardScreen> createState() => _HRDashboardScreenState();
}

class _HRDashboardScreenState extends State<HRDashboardScreen> {
  late final AutoRefreshController _autoRefresh;
  bool _requestInFlight = false;
  bool _refreshQueued = false;
  bool loading = true;
  String? error;
  Map<String, dynamic> dashboard = {};

  @override
  void initState() {
    super.initState();
    _autoRefresh = AutoRefreshController(owner: this, onRefresh: loadDashboard)
      ..start();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    if (!mounted) return;
    if (_requestInFlight) {
      _refreshQueued = true;
      return;
    }
    _requestInFlight = true;
    if (dashboard.isEmpty && !loading) setState(() => loading = true);

    try {
      final response = await ApiService.get('/hr/dashboard');
      if (!mounted) return;

      if (ApiService.isSuccess(response['status']) && response['data'] is Map) {
        setState(() {
          dashboard = Map<String, dynamic>.from(response['data']);
          loading = false;
          error = null;
        });
      } else {
        final data = response['data'];
        setState(() {
          final message = data is Map
              ? data['message']?.toString() ?? 'Failed to load dashboard'
              : ApiService.messageForStatus(response['status']);
          loading = false;
          if (dashboard.isEmpty) error = message;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (dashboard.isEmpty) {
          error = 'Unable to load dashboard. Check your connection and retry.';
        }
        loading = false;
      });
    } finally {
      _requestInFlight = false;
      if (_refreshQueued && mounted) {
        _refreshQueued = false;
        unawaited(Future<void>.delayed(Duration.zero, loadDashboard));
      }
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await loadDashboard();
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  const AppSectionHeader(
                    title: 'People operations',
                    subtitle: 'A live overview of your team and requests',
                  ),
                  GridView.count(
                    crossAxisCount: MediaQuery.sizeOf(context).width >= 900
                        ? 3
                        : MediaQuery.sizeOf(context).width < 360
                        ? 1
                        : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: MediaQuery.sizeOf(context).width >= 900
                        ? 1.5
                        : 1.2,
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
                      DashboardCard(
                        icon: Icons.assignment_outlined,
                        title:
                            'Projects & Tasks\n${dashboard['total_tasks'] ?? 0}\n${dashboard['unassigned_tasks'] ?? 0} unassigned',
                        onTap: () => _open(const ManagementTasksScreen()),
                      ),
                      DashboardCard(
                        icon: Icons.feedback_outlined,
                        title:
                            'New Feedback\n${dashboard['new_feedback'] ?? 0}',
                        onTap: () => _open(const ManagementFeedbackScreen()),
                      ),
                      DashboardCard(
                        icon: Icons.location_on_outlined,
                        title:
                            'Locations\n${dashboard['locations_received'] ?? 0} recorded',
                        onTap: () => _open(const ManagementLocationsScreen()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
