import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../services/api_service.dart';

class LogoutAction extends StatefulWidget {
  const LogoutAction({super.key});

  @override
  State<LogoutAction> createState() => _LogoutActionState();
}

class _LogoutActionState extends State<LogoutAction> {
  bool loggingOut = false;

  Future<void> _logout() async {
    if (loggingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Your saved offline requests will stay on this device under this account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => loggingOut = true);
    final result = await ApiService.revokeCurrentToken();
    await ApiService.clearSession();

    if (!mounted) return;
    final revoked = result != null && ApiService.isSuccess(result['status']);
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          logoutMessage: revoked
              ? 'You have been signed out.'
              : 'Signed out on this device. Server token revocation could not be confirmed.',
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Log out',
      enabled: !loggingOut,
      icon: loggingOut
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.logout),
      onSelected: (value) {
        if (value == 'logout') _logout();
      },
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout),
              SizedBox(width: 12),
              Text('Log out'),
            ],
          ),
        ),
      ],
    );
  }
}
