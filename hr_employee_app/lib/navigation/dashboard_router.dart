import 'package:flutter/material.dart';

import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/employee/dashboard_screen.dart';
import '../screens/hr/hr_dashboard_screen.dart';

Widget? dashboardForUser(Map<String, dynamic> user) {
  return switch (user['role']) {
    'admin' => const AdminDashboardScreen(),
    'hr' => const HRDashboardScreen(),
    'employee' => DashboardScreen(user: user),
    _ => null,
  };
}

Map<String, dynamic>? userFromJson(dynamic value) {
  if (value is! Map) return null;
  final id = value['id'];
  final parsedId = id is int ? id : int.tryParse(id?.toString() ?? '');
  final role = value['role'];
  if (parsedId == null ||
      role is! String ||
      dashboardForRoleIsValid(role) == false) {
    return null;
  }

  return {
    'id': parsedId,
    'name': value['name']?.toString() ?? '',
    'email': value['email']?.toString() ?? '',
    'role': role,
  };
}

bool dashboardForRoleIsValid(String role) =>
    role == 'admin' || role == 'hr' || role == 'employee';
