import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/logout_action.dart';
import 'performance_screen.dart';
import '../../components/dashboard_card.dart';
import '../../components/app_loader.dart';
import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';
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
  late final AutoRefreshController _autoRefresh;
  bool _requestInFlight = false;
  bool _offlineMode = false;
  Map<String, dynamic>? employee;
  bool loading = true;
  String? error;

  Future<void> getProfile() async {
    if (!mounted || _requestInFlight) return;
    _requestInFlight = true;
    if (employee == null && !loading) setState(() => loading = true);

    try {
      if (employee == null) {
        final cached = await _readCachedProfile();
        if (cached != null && mounted) {
          setState(() {
            employee = cached;
            loading = false;
            error = null;
          });
        }
      }

      final response = await ApiService.get('/employee/profile');
      if (!mounted) return;

      if (ApiService.isSuccess(response['status'])) {
        final data = response['data'];
        final profile = data is Map ? data['employee'] : null;
        if (profile is Map<String, dynamic>) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'cached_employee',
              jsonEncode({
                'user_id': widget.user['id'],
                'employee': {
                  'employee_id': profile['employee_id'],
                  'department': profile['department'],
                  'designation': profile['designation'],
                },
              }),
            );
          } catch (_) {
            // The live profile is still usable if local caching is unavailable.
          }
        }

        if (mounted) {
          setState(() {
            employee = profile is Map<String, dynamic> ? profile : null;
            loading = false;
            error = null;
            _offlineMode = false;
            if (employee == null) {
              error = 'The server returned an invalid employee profile.';
            }
          });
        }
      } else {
        final status = response['status'];
        final serverMessage = response['data'] is Map
            ? response['data']['message']?.toString()
            : null;
        if (mounted) {
          setState(() {
            loading = false;
            if (status == 429 || (status is int && status >= 500)) {
              _offlineMode = true;
              error = 'Showing saved information. The server is unavailable.';
            } else {
              _offlineMode = false;
              error = status == 404
                  ? 'Employee profile not found. Contact HR to link this account.'
                  : serverMessage ?? ApiService.messageForStatus(status);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          _offlineMode = true;
          error = 'Showing saved information. The server is unavailable.';
        });
      }
    } finally {
      _requestInFlight = false;
    }
  }

  Future<Map<String, dynamic>?> _readCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cached_employee');
      if (raw == null) return null;
      final cached = jsonDecode(raw);
      if (cached is! Map || '${cached['user_id']}' != '${widget.user['id']}') {
        return null;
      }
      final profile = cached['employee'];
      return profile is Map ? Map<String, dynamic>.from(profile) : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _autoRefresh = AutoRefreshController(owner: this, onRefresh: getProfile)
      ..start();
    getProfile();
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
        title: const Text('Employee Dashboard'),
        actions: const [LogoutAction()],
      ),

      body: loading && employee == null
          ? const AppLoader()
          : error != null && !_offlineMode
          ? AppError(message: error!, onRetry: getProfile)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  if (error != null && _offlineMode)
                    MaterialBanner(
                      content: Text(error!),
                      leading: const Icon(Icons.cloud_off),
                      actions: [
                        TextButton(
                          onPressed: getProfile,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
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
