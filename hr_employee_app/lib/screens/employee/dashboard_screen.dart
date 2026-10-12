import 'package:flutter/material.dart';
import '../../components/logout_action.dart';
import 'performance_screen.dart';
import '../../components/dashboard_card.dart';
import '../../components/app_loader.dart';
import '../../services/api_service.dart';
import 'profile_screen.dart';
import 'attendance_screen.dart';
import 'leaves_screen.dart';
import '../../components/app_error.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? employee;
  bool loading = true;
  String? error;

  Future<void> getProfile() async {
    setState(() {
      loading = true;
      error = null;
      employee = null;
    });

    try {
      final response = await ApiService.get('/employee/profile');

      if (ApiService.isSuccess(response['status'])) {
        final data = response['data'];
        final profile = data is Map ? data['employee'] : null;

        if (mounted) {
          setState(() {
            employee = profile is Map<String, dynamic> ? profile : null;
            loading = false;
            if (employee == null) {
              error = 'The server returned an invalid employee profile.';
            }
          });
        }
      } else {
        if (mounted) {
          final serverMessage = response['data'] is Map
              ? response['data']['message']?.toString()
              : null;
          setState(() {
            loading = false;
            error = response['status'] == 404
                ? 'Employee profile not found. Contact HR to link this account.'
                : serverMessage ??
                      ApiService.messageForStatus(response['status']);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error =
              'Unable to load your employee profile. Check your connection and retry.';
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    getProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Dashboard'),
        actions: const [LogoutAction()],
      ),

      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: getProfile)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'Welcome, ${widget.user['name']} 👋',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    widget.user['email'],
                    style: const TextStyle(fontSize: 16),
                  ),

                  if (employee != null) ...[
                    const SizedBox(height: 20),

                    Text('Employee ID: ${employee!['employee_id']}'),

                    Text('Department: ${employee!['department']}'),

                    Text('Designation: ${employee!['designation']}'),
                  ],

                  const SizedBox(height: 30),

                  Row(
                    children: [
                      Expanded(
                        child: DashboardCard(
                          icon: Icons.calendar_month,
                          title: 'Attendance',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AttendanceScreen(),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(width: 15),

                      Expanded(
                        child: DashboardCard(
                          icon: Icons.event_note,
                          title: 'Leaves',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LeavesScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: DashboardCard(
                          icon: Icons.assessment,
                          title: 'Performance',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PerformanceScreen(),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(width: 15),

                      Expanded(
                        child: DashboardCard(
                          icon: Icons.person,
                          title: 'Profile',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
