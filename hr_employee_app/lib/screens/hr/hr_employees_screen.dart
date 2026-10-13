import 'package:flutter/material.dart';
import '../../components/logout_action.dart';

import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';

class HREmployeesScreen extends StatefulWidget {
  const HREmployeesScreen({super.key});

  @override
  State<HREmployeesScreen> createState() => _HREmployeesScreenState();
}

class _HREmployeesScreenState extends State<HREmployeesScreen> {
  late final AutoRefreshController _autoRefresh;
  bool _requestInFlight = false;
  bool _hasLoaded = false;
  bool loading = true;
  String? error;

  List<dynamic> employees = [];

  @override
  void initState() {
    super.initState();
    _autoRefresh = AutoRefreshController(owner: this, onRefresh: loadEmployees)
      ..start();
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    if (!mounted || _requestInFlight) return;
    _requestInFlight = true;
    if (!_hasLoaded && !loading) setState(() => loading = true);

    try {
      final response = await ApiService.get('/hr/employees');
      if (!mounted) return;

      if (response['status'] == 200) {
        setState(() {
          employees = response['data']['employees'] ?? [];
          loading = false;
          error = null;
          _hasLoaded = true;
        });
      } else {
        setState(() {
          if (!_hasLoaded) {
            error = response['data']['message'] ?? 'Failed to load employees';
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
        title: const Text('Employees'),
        actions: const [LogoutAction()],
      ),
      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: loadEmployees)
          : RefreshIndicator(
              onRefresh: loadEmployees,
              child: employees.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: 250),
                        Center(child: Text('No employees found')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: employees.length,
                      itemBuilder: (context, index) {
                        final employee = employees[index];
                        final user = employee['user'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                (user?['name'] ?? 'E')
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                              ),
                            ),
                            title: Text(
                              user?['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'ID: ${employee['employee_id'] ?? '-'}\n'
                              'Department: ${employee['department'] ?? '-'}\n'
                              'Designation: ${employee['designation'] ?? '-'}',
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
