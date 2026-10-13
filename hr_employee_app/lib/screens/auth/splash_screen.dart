import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../components/app_error.dart';
import '../../navigation/dashboard_router.dart';
import '../../services/api_service.dart';
import '../../services/offline_sync_service.dart';
import 'login_screen.dart';
import 'pending_profile_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool loading = true;
  String? error;
  Widget? restoredScreen;

  @override
  void initState() {
    super.initState();
    restoreSession();
  }

  Future<void> restoreSession() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
        restoredScreen = null;
      });
    }

    try {
      final token = await ApiService.getStoredToken();
      if (token == null || token.trim().isEmpty) {
        await ApiService.clearSession();
        if (mounted) setState(() => restoredScreen = const LoginScreen());
        return;
      }

      final response = await ApiService.get('/user', handleUnauthorized: false);

      if (response['status'] == 401) {
        await ApiService.clearSession();
        if (mounted) setState(() => restoredScreen = const LoginScreen());
        return;
      }

      if (response['status'] == 403 &&
          ApiService.isPendingProfileResponse(response['data'])) {
        final message = ApiService.messageFromResponse(response['data'], 403);
        await ApiService.revokeCurrentToken();
        await ApiService.clearSession();
        if (mounted) {
          setState(
            () => restoredScreen = PendingProfileScreen(message: message),
          );
        }
        return;
      }

      if (!ApiService.isSuccess(response['status'])) {
        final status = response['status'];
        if (status == 429 || (status is int && status >= 500)) {
          if (await _restoreCachedSession()) return;
        }
        if (mounted) {
          setState(() {
            error = ApiService.messageFromResponse(
              response['data'],
              response['status'],
            );
          });
        }
        return;
      }

      final user = userFromJson(response['data']);
      if (user == null) {
        if (mounted) {
          setState(() {
            error =
                'The server returned incomplete account information. Retry or contact your administrator.';
          });
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(user));
      unawaited(OfflineSyncService.syncPendingLeaves());
      final destination = dashboardForUser(user);
      if (mounted) {
        setState(() {
          restoredScreen = destination ?? const LoginScreen();
        });
      }
    } catch (_) {
      // Network and timeout errors do not invalidate or erase the stored token.
      if (!await _restoreCachedSession() && mounted) {
        setState(() {
          error =
              'Unable to reach the server. Your saved session is still on this device.';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<bool> _restoreCachedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serializedUser = prefs.getString('user');
      if (serializedUser == null) return false;
      final user = userFromJson(jsonDecode(serializedUser));
      final destination = user == null ? null : dashboardForUser(user);
      if (destination == null || !mounted) return false;

      unawaited(OfflineSyncService.syncPendingLeaves());
      setState(() {
        error = null;
        restoredScreen = destination;
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppError(message: error!, onRetry: restoreSession),
          ),
        ),
      );
    }

    return restoredScreen ?? const LoginScreen();
  }
}
