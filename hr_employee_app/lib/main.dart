import 'dart:async';

import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/pending_profile_screen.dart';
import 'services/api_service.dart';
import 'screens/auth/splash_screen.dart';
import 'theme/app_theme.dart';
import 'services/offline_sync_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.onUnauthorized = () async {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  };
  ApiService.onPendingProfile = (message) async {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => PendingProfileScreen(message: message),
      ),
      (route) => false,
    );
  };

  runApp(const HRApp());
}

class HRApp extends StatefulWidget {
  const HRApp({super.key});

  @override
  State<HRApp> createState() => _HRAppState();
}

class _HRAppState extends State<HRApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OfflineSyncService.startConnectivityListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(OfflineSyncService.syncPendingLeaves());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'HR Management',

      theme: AppTheme.lightTheme,

      home: const SplashScreen(),
    );
  }
}
