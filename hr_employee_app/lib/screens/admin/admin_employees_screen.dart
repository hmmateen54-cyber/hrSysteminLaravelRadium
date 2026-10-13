import 'package:flutter/material.dart';
import '../../components/logout_action.dart';

import '../../services/api_service.dart';
import '../../services/auto_refresh_controller.dart';
import '../../components/app_loader.dart';
import '../../components/app_error.dart';

class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  late final AutoRefreshController _autoRefresh;
  bool _requestInFlight = false;
  bool _hasLoaded = false;
  List<dynamic> employees = [];

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _autoRefresh = AutoRefreshController(owner: this, onRefresh: getEmployees)
      ..start();
    getEmployees();
  }

  Future<void> getEmployees() async {
    if (!mounted || _requestInFlight) return;
    _requestInFlight = true;
    if (!_hasLoaded && !loading) setState(() => loading = true);

    try {
      final response = await ApiService.get('/admin/employees');
      if (!mounted) return;

      if (ApiService.isSuccess(response['status'])) {
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
          ? AppError(message: error!, onRetry: getEmployees)
          : employees.isEmpty
          ? const Center(child: Text('No employees found'))
          : RefreshIndicator(
              onRefresh: getEmployees,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: employees.length,
                itemBuilder: (context, index) {
                  final employee = employees[index];

                  final user = employee['user'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(
                        user?['name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Employee ID: '
                        '${employee['employee_id'] ?? '-'}\n'
                        'Department: '
                        '${employee['department'] ?? '-'}\n'
                        'Designation: '
                        '${employee['designation'] ?? '-'}',
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
