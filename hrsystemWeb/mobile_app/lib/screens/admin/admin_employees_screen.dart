import 'package:flutter/material.dart';
import '../../components/logout_action.dart';

import '../../services/api_service.dart';
import '../../components/app_loader.dart';
import '../../components/app_error.dart';

class AdminEmployeesScreen extends StatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  State<AdminEmployeesScreen> createState() => _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState extends State<AdminEmployeesScreen> {
  List<dynamic> employees = [];

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    getEmployees();
  }

  Future<void> getEmployees() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await ApiService.get('/admin/employees');

      if (ApiService.isSuccess(response['status'])) {
        setState(() {
          employees = response['data']['employees'] ?? [];
          loading = false;
        });
      } else {
        setState(() {
          error = response['data']['message'] ?? 'Failed to load employees';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Something went wrong';
        loading = false;
      });
    }
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
