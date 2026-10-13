import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_employee_app/services/offline_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'offline attendance queue preserves the original GPS and action times',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final ownerId = DateTime.now().microsecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({'user': '{"id": $ownerId}'});
      final actionAt = DateTime.parse('2026-10-13T08:15:22+05:00');
      final capturedAt = DateTime.parse('2026-10-13T03:15:24.300Z');

      final queueId = await OfflineSyncService.queueAttendanceAction(
        attendanceDate: '2026-10-13',
        actionType: 'check_in',
        actionAt: actionAt,
        capturedAt: capturedAt,
        latitude: 24.8607123,
        longitude: 67.0011456,
        accuracy: 8.45,
      );
      final items = await OfflineSyncService.getQueueItems(
        operation: 'attendance',
      );
      final item = items.firstWhere((row) => row['queue_id'] == queueId);

      expect(item['sync_status'], 'waiting');
      expect(item['action_type'], 'check_in');
      expect(item['action_at'], actionAt.toUtc().toIso8601String());
      expect(item['captured_at'], capturedAt.toUtc().toIso8601String());
      expect(item['latitude'], 24.8607123);
      expect(item['longitude'], 67.0011456);
      expect(item['accuracy'], 8.45);
      expect(item['address_status'], 'pending');
      expect(item['address'], isNull);
    },
  );
}
