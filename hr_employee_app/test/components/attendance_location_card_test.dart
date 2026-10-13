import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_employee_app/components/attendance_location_card.dart';

void main() {
  testWidgets('shows the resolved address and OpenStreetMap attribution', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AttendanceLocationCard(
            syncStatus: 'synced',
            addressStatus: 'resolved',
            address: 'DHA Phase 6, Karachi, Sindh, Pakistan',
            message: 'Check-in location confirmed by the server.',
          ),
        ),
      ),
    );

    expect(find.text('Current Location'), findsOneWidget);
    expect(find.text('DHA Phase 6, Karachi, Sindh, Pakistan'), findsOneWidget);
    expect(
      find.text('Address data © OpenStreetMap contributors'),
      findsOneWidget,
    );
  });

  testWidgets('shows separate offline address and synchronization states', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AttendanceLocationCard(
            syncStatus: 'waiting',
            addressStatus: 'pending',
            message: 'Check-in location saved on this device.',
          ),
        ),
      ),
    );

    expect(find.text('Saved offline — address pending'), findsOneWidget);
    expect(find.text('Synchronization pending'), findsOneWidget);
  });

  testWidgets('shows an unavailable address without inventing a place name', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AttendanceLocationCard(
            syncStatus: 'synced',
            addressStatus: 'unavailable',
            message: 'The attendance event is saved on the server.',
          ),
        ),
      ),
    );

    expect(find.text('Address unavailable'), findsOneWidget);
    expect(find.textContaining('Karachi'), findsNothing);
  });
}
