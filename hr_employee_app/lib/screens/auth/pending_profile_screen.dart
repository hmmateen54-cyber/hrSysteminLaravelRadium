import 'package:flutter/material.dart';

import '../../components/app_button.dart';
import 'login_screen.dart';

class PendingProfileScreen extends StatelessWidget {
  final String message;

  const PendingProfileScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile awaiting HR')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.hourglass_top, size: 56),
            const SizedBox(height: 20),
            Text(
              'Your profile is pending',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            AppButton(
              text: 'Back to login',
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
