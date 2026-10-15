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

  test(
    'task progress is cached optimistically and each offline change is queued in order',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final ownerId = DateTime.now().microsecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({'user': '{"id": $ownerId}'});
      final assignment = <String, dynamic>{
        'id': 4101,
        'task_id': 2901,
        'status': 'assigned',
        'progress_notes': null,
        'progress_version': 0,
        'updated_at': '2026-10-15T03:00:00.000000Z',
        'task': {'id': 2901, 'title': 'Prepare monthly report'},
      };
      await OfflineSyncService.saveCachedItems('tasks', [assignment]);

      final firstQueueId = await OfflineSyncService.queueTaskStatusUpdate(
        assignment: assignment,
        status: 'in_progress',
        progressNotes: 'Started offline.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final secondQueueId = await OfflineSyncService.queueTaskStatusUpdate(
        assignment: assignment,
        status: 'completed',
        progressNotes: 'Finished offline.',
      );

      final queued = await OfflineSyncService.getQueueItems(
        operation: 'task_status',
        includeSynced: false,
      );
      final first = queued.firstWhere(
        (item) => item['queue_id'] == firstQueueId,
      );
      final second = queued.firstWhere(
        (item) => item['queue_id'] == secondQueueId,
      );
      expect(first['assignment_id'], 4101);
      expect(first['task_id'], 2901);
      expect(first['status'], 'in_progress');
      expect(first['expected_version'], 0);
      expect(first['original_updated_at'], isNotNull);
      expect(second['status'], 'completed');
      expect(second['expected_version'], 1);

      // A live refresh that temporarily omits a queued assignment must not
      // remove the employee's cached task or optimistic status.
      await OfflineSyncService.saveCachedItems('tasks', []);
      final cached = await OfflineSyncService.readCachedItems('tasks');
      final cachedAssignment = (cached?['items'] as List).first as Map;
      expect(cachedAssignment['status'], 'completed');
      expect(cachedAssignment['sync_status'], 'waiting');
      expect(cachedAssignment['sync_queue_id'], secondQueueId);
    },
  );
}
