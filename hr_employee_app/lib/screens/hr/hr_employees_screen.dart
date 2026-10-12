import 'package:flutter/material.dart';
import '../../components/logout_action.dart';

import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../services/api_service.dart';

class HREmployeesScreen extends StatefulWidget {
  const HREmployeesScreen({super.key});

  @override
  State<HREmployeesScreen> createState() => _HREmployeesScreenState();
}

class _HREmployeesScreenState extends State<HREmployeesScreen> {
  bool loading = true;
  String? error;

  List<dynamic> employees = [];

  @override
  void initState() {
    super.initState();
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await ApiService.get('/hr/employees');

      if (response['status'] == 200) {
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
