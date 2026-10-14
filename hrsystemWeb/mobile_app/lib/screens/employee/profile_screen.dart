import 'package:flutter/material.dart';
import '../../components/logout_action.dart';
import '../../components/app_error.dart';
import '../../components/app_loader.dart';
import '../../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? user;
  Map<String, dynamic>? employee;

  bool loading = true;
  String? error;

  Future<void> getProfile() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await ApiService.get('/employee/profile');

      if (ApiService.isSuccess(response['status'])) {
        final data = response['data'];

        setState(() {
          user = data['user'];
          employee = data['employee'];
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
          error = response['data']['message'] ?? 'Failed to load profile';
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        error = 'Unable to connect to server';
      });
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
        title: const Text('My Profile'),
        actions: const [LogoutAction()],
      ),

      body: loading
          ? const AppLoader()
          : error != null
          ? AppError(message: error!, onRetry: getProfile)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 45,
                    child: Icon(Icons.person, size: 50),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    user?['name'] ?? '-',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    user?['email'] ?? '-',
                    style: const TextStyle(fontSize: 16),
                  ),

                  const SizedBox(height: 30),

                  profileItem('Employee ID', employee?['employee_id']),

                  profileItem('Phone', employee?['phone']),

                  profileItem('Department', employee?['department']),

                  profileItem('Designation', employee?['designation']),

                  profileItem('Joining Date', employee?['joining_date']),

                  profileItem('Salary', employee?['salary']),
                ],
              ),
            ),
    );
  }

  Widget profileItem(String title, dynamic value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value?.toString() ?? '-'),
      ),
    );
  }
}
