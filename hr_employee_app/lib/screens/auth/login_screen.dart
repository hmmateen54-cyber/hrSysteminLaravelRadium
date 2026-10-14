import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/app_button.dart';
import '../../components/app_text_field.dart';
import '../../services/api_service.dart';
import 'dart:convert';
import '../../navigation/dashboard_router.dart';
import '../../services/offline_sync_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? logoutMessage;
  final String? initialMessage;

  const LoginScreen({super.key, this.logoutMessage, this.initialMessage});

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
    final message = widget.initialMessage ?? widget.logoutMessage;
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
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email and password.')),
      );
      return;
    }

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
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
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
            Text(
              'Employee Login',
              style: Theme.of(context).textTheme.headlineSmall,
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
            const SizedBox(height: 16),
            TextButton(
              onPressed: loading
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
              child: const Text('Create an employee account'),
            ),
          ],
        ),
      ),
    );
  }
}
