import 'package:flutter/material.dart';

import '../../components/app_button.dart';
import '../../components/app_text_field.dart';
import '../../services/api_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  bool _loading = false;
  String? _successMessage;
  String? _serverMessage;
  Map<String, String> _serverErrors = {};

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field) || _serverMessage != null) {
      setState(() {
        _serverErrors = {..._serverErrors}..remove(field);
        _serverMessage = null;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _serverErrors = {};
      _serverMessage = null;
    });

    try {
      final response = await ApiService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _confirmationController.text,
      );
      if (!mounted) return;
      final data = response['data'];

      if (response['status'] == 201 && data is Map) {
        setState(() {
          _successMessage = ApiService.messageFromResponse(data, 201);
        });
        return;
      }

      if (data is Map && data['errors'] is Map) {
        final errors = <String, String>{};
        (data['errors'] as Map).forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            errors[key.toString()] = value.first.toString();
          }
        });
        setState(() {
          _serverErrors = errors;
          _serverMessage = errors.isEmpty
              ? ApiService.messageFromResponse(data, response['status'])
              : null;
        });
        return;
      }

      setState(() {
        _serverMessage = ApiService.messageFromResponse(
          data,
          response['status'],
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverMessage = 'Unable to reach the server. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _continueToLogin() {
    final message = _successMessage;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(initialMessage: message)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final successMessage = _successMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: successMessage == null
              ? Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Employee registration',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your account. HR will complete your employee profile before you can sign in.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      AppTextField(
                        controller: _nameController,
                        label: 'Full name',
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter your full name.'
                            : null,
                        onChanged: (_) => _clearServerError('name'),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _emailController,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Enter your email address.';
                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(email)) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                        onChanged: (_) => _clearServerError('email'),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _passwordController,
                        label: 'Password',
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        validator: (value) => (value?.length ?? 0) < 8
                            ? 'Use at least 8 characters.'
                            : null,
                        onChanged: (_) => _clearServerError('password'),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _confirmationController,
                        label: 'Confirm password',
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirm your password.';
                          }
                          return value != _passwordController.text
                              ? 'Passwords do not match.'
                              : null;
                        },
                        onChanged: (_) =>
                            _clearServerError('password_confirmation'),
                      ),
                      if (_serverErrors.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ..._serverErrors.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '${_fieldLabel(entry.key)}: ${entry.value}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_serverMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _serverMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      AppButton(
                        text: 'Create account',
                        loading: _loading,
                        onPressed: _loading ? null : _register,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Back to login'),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'Registration received',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(successMessage, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    AppButton(
                      text: 'Back to login',
                      onPressed: _continueToLogin,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _fieldLabel(String field) => switch (field) {
    'name' => 'Name',
    'email' => 'Email',
    'password' => 'Password',
    'password_confirmation' => 'Password confirmation',
    _ => field,
  };
}
