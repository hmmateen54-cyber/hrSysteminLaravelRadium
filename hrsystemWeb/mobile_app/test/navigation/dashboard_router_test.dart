import 'package:flutter_test/flutter_test.dart';
import 'package:hr_employee_app/navigation/dashboard_router.dart';
import 'package:hr_employee_app/screens/admin/admin_dashboard_screen.dart';
import 'package:hr_employee_app/screens/employee/dashboard_screen.dart';
import 'package:hr_employee_app/screens/hr/hr_dashboard_screen.dart';

void main() {
  group('dashboardForUser', () {
    test('uses the server role for each supported dashboard', () {
      expect(
        dashboardForUser({'id': 1, 'role': 'admin'}),
        isA<AdminDashboardScreen>(),
      );
      expect(
        dashboardForUser({'id': 2, 'role': 'hr'}),
        isA<HRDashboardScreen>(),
      );
      expect(
        dashboardForUser({'id': 3, 'role': 'employee'}),
        isA<DashboardScreen>(),
      );
    });

    test('rejects unknown roles and malformed users', () {
      expect(dashboardForUser({'id': 1, 'role': 'manager'}), isNull);
      expect(userFromJson({'id': 'bad', 'role': 'employee'}), isNull);
      expect(userFromJson({'id': 4, 'role': 'manager'}), isNull);
    });

    test('safely parses server IDs and retains the authenticated role', () {
      expect(
        userFromJson({
          'id': '5',
          'name': 'Employee',
          'email': 'employee@example.test',
          'role': 'employee',
        }),
        {
          'id': 5,
          'name': 'Employee',
          'email': 'employee@example.test',
          'role': 'employee',
        },
      );
    });
  });
}
