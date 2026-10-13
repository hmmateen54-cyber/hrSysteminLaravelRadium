import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/app_button.dart';
import '../../components/app_text_field.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import '../../navigation/dashboard_router.dart';
import '../../services/offline_sync_service.dart';

class LoginScreen extends StatefulWidget {
  final String? logoutMessage;

  const LoginScreen({super.key, this.logoutMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  @override
  void initState() {
    super.initState();
    final message = widget.logoutMessage;
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      });
    }
  }

  Future<void> login() async {
    setState(() {
      loading = true;
    });

    try {
      final response = await ApiService.login(
        emailController.text,
        passwordController.text,
      );

      final data = response['data'];

      if (ApiService.isSuccess(response['status']) && data is Map) {
        final user = userFromJson(data['user']);
        final token = data['token'];
        if (user == null || token is! String || token.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('The server returned an invalid login response'),
              ),
            );
          }
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        // Remove the prior account's cached profile before switching sessions.
        await prefs.remove('cached_employee');
        await ApiService.storeToken(token);
        await prefs.setString('user', jsonEncode(user));
        unawaited(OfflineSyncService.syncPendingLeaves());

        if (!mounted) return;

        final dashboard = dashboardForUser(user);
        if (dashboard == null) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => dashboard),
        );
      } else {
        if (!mounted) return;
        final message = data is Map
            ? data['message']?.toString() ?? 'Login failed'
            : 'Login failed';

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to reach the server')),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HR Management')),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            const Text(
              'Employee Login',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 30),

            AppTextField(
              controller: emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 16),

            AppTextField(
              controller: passwordController,
              label: 'Password',
              obscureText: true,
            ),

            const SizedBox(height: 24),

            AppButton(text: 'Login', loading: loading, onPressed: login),
          ],
        ),
      ),
    );
  }
}
