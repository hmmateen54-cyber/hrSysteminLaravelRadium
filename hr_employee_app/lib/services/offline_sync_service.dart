import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

import 'api_service.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class OfflineSyncService {
  static final ValueNotifier<int> queueRevision = ValueNotifier<int>(0);
  static bool _databaseFactoryInitialized = false;

  static void _initializeDatabaseFactory() {
    if (_databaseFactoryInitialized) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _databaseFactoryInitialized = true;
  }

  static Database? _db;
  static bool _syncing = false;
  static bool _syncRequestedWhileRunning = false;
  static Timer? _retryTimer;
  static StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;
  static const _uuid = Uuid();

  static void _queueChanged() {
    queueRevision.value++;
  }

  static Future<Database> get database async {
    _initializeDatabaseFactory();

    if (_db != null) return _db!;

    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'hr_offline_sync.db'),
      version: 6,
      onCreate: (db, _) async {
        await _createQueueTable(db);
        await _createUserCacheTable(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 3) await _migrateLegacyQueues(db);
        if (oldVersion < 4) await _createUserCacheTable(db);
        if (oldVersion < 5) {
          await _addQueueColumnIfMissing(db, 'synced_at', 'TEXT');
        }
        if (oldVersion < 6) {
          await _addQueueColumnIfMissing(
            db,
            'address_status',
            "TEXT NOT NULL DEFAULT 'none'",
          );
          await _addQueueColumnIfMissing(
            db,
            'address_retry_count',
            'INTEGER NOT NULL DEFAULT 0',
          );
          await _addQueueColumnIfMissing(db, 'address_next_attempt_at', 'TEXT');
        }
      },
      onOpen: (db) async {
        await db.update(
          'sync_queue',
          {
            'status': 'waiting',
            'last_error': 'Sync was interrupted. It is ready to retry.',
          },
          where: 'status = ?',
          whereArgs: ['syncing'],
        );
      },
    );
  }

  static Future<void> _createQueueTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE sync_queue (
        queue_id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        client_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'waiting',
        retry_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_at TEXT,
        last_error TEXT,
        server_record_id INTEGER,
        synced_at TEXT,
        address_status TEXT NOT NULL DEFAULT 'none',
        address_retry_count INTEGER NOT NULL DEFAULT 0,
        address_next_attempt_at TEXT,
        UNIQUE(owner_id, operation, client_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX sync_queue_owner_status_idx ON sync_queue(owner_id, status)',
    );
    await db.execute(
      'CREATE INDEX sync_queue_owner_operation_idx ON sync_queue(owner_id, operation)',
    );
  }

  static Future<void> _addQueueColumnIfMissing(
    DatabaseExecutor db,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info(sync_queue)');
    if (columns.any((row) => row['name'] == column)) return;
    await db.execute('ALTER TABLE sync_queue ADD COLUMN $column $definition');
  }

  static Future<void> _createUserCacheTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE user_cache (
        owner_id TEXT NOT NULL,
        cache_key TEXT NOT NULL,
        payload TEXT NOT NULL,
        fetched_at TEXT NOT NULL,
        PRIMARY KEY (owner_id, cache_key)
      )
    ''');
  }

  static Future<void> saveCachedItems(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    final owner = await ApiService.getCurrentUserId();
    if (owner == null) return;
    final db = await database;
    var savedItems = items;
    if (key == 'tasks') {
      final cachedRows = await db.query(
        'user_cache',
        where: 'owner_id = ? AND cache_key = ?',
        whereArgs: [owner.toString(), 'tasks'],
        limit: 1,
      );
      if (cachedRows.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedRows.first['payload'] as String);
          final previous = decoded is List
              ? decoded
                    .whereType<Map>()
                    .map((row) => Map<String, dynamic>.from(row))
                    .toList()
              : <Map<String, dynamic>>[];
          final queuedRows = await db.query(
            'sync_queue',
            where: "owner_id = ? AND operation = ? AND status != 'synced'",
            whereArgs: [owner.toString(), 'task_status'],
          );
          final pendingAssignmentIds = <String>{};
          for (final row in queuedRows) {
            final payload = jsonDecode(row['payload'] as String);
            if (payload is Map && payload['assignment_id'] != null) {
              pendingAssignmentIds.add(payload['assignment_id'].toString());
            }
          }
          if (pendingAssignmentIds.isNotEmpty) {
            final remoteIds = items
                .map((item) => item['id']?.toString())
                .toSet();
            savedItems = [
              ...items,
              ...previous.where(
                (item) =>
                    pendingAssignmentIds.contains(item['id']?.toString()) &&
                    !remoteIds.contains(item['id']?.toString()),
              ),
            ];
          }
        } on FormatException {
          // Keep the live response if an old cached task payload is malformed.
        }
      }
    }
    await db.insert('user_cache', {
      'owner_id': owner.toString(),
      'cache_key': key,
      'payload': jsonEncode(savedItems),
      'fetched_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    if (key == 'tasks') await _refreshCachedTasks(owner.toString(), db);
  }

  static Future<Map<String, dynamic>?> readCachedItems(String key) async {
    final owner = await ApiService.getCurrentUserId();
    if (owner == null) return null;
    final db = await database;
    if (key == 'tasks') await _refreshCachedTasks(owner.toString(), db);
    final rows = await db.query(
      'user_cache',
      where: 'owner_id = ? AND cache_key = ?',
      whereArgs: [owner.toString(), key],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    try {
      final decoded = jsonDecode(rows.first['payload'] as String);
      if (decoded is! List) return null;
      return {
        'items': decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
        'fetched_at': rows.first['fetched_at'],
      };
    } on FormatException {
      return null;
    }
  }

  static const taskStatuses = {
    'assigned',
    'in_progress',
    'completed',
    'on_hold',
  };

  static Future<String> queueTaskStatusUpdate({
    required Map<String, dynamic> assignment,
    required String status,
    required String progressNotes,
  }) async {
    if (!taskStatuses.contains(status)) {
      throw ArgumentError('Choose a valid task status.');
    }
    final assignmentId = _positiveId(assignment['id']);
    final task = assignment['task'] is Map
        ? Map<String, dynamic>.from(assignment['task'])
        : <String, dynamic>{};
    final taskId = _positiveId(task['id']);
    if (assignmentId == null || taskId == null) {
      throw ArgumentError(
        'Load this task from the server before updating it offline.',
      );
    }
    if (progressNotes.length > 3000) {
      throw ArgumentError('Progress notes must be 3000 characters or fewer.');
    }

    final owner = await _currentOwnerId();
    final db = await database;
    late String queueId;
    final now = DateTime.now().toUtc();
    final originalUpdatedAt = now.toIso8601String();
    final clientId = _uuid.v4();
    queueId = 'task-status-$owner-$clientId';

    await db.transaction((txn) async {
      final cacheRows = await txn.query(
        'user_cache',
        where: 'owner_id = ? AND cache_key = ?',
        whereArgs: [owner, 'tasks'],
        limit: 1,
      );
      List<Map<String, dynamic>> cachedAssignments;
      String? fetchedAt;
      if (cacheRows.isEmpty) {
        // The screen supplied a server-loaded assignment; seed the same cache
        // used by My Tasks and the employee dashboard.
        cachedAssignments = [Map<String, dynamic>.from(assignment)];
      } else {
        final decoded = jsonDecode(cacheRows.first['payload'] as String);
        cachedAssignments = decoded is List
            ? decoded
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
            : <Map<String, dynamic>>[];
        fetchedAt = cacheRows.first['fetched_at']?.toString();
      }

      final taskEvents = await txn.query(
        'sync_queue',
        columns: ['payload', 'status'],
        where: 'owner_id = ? AND operation = ?',
        whereArgs: [owner, 'task_status'],
        orderBy: 'rowid ASC',
      );
      var outstandingCount = 0;
      for (final event in taskEvents) {
        final eventPayload = jsonDecode(event['payload'] as String);
        if (eventPayload is Map &&
            eventPayload['assignment_id']?.toString() ==
                assignmentId.toString() &&
            event['status'] != 'synced') {
          outstandingCount++;
        }
      }

      final cachedIndex = cachedAssignments.indexWhere(
        (row) => row['id']?.toString() == assignmentId.toString(),
      );
      final base = cachedIndex >= 0
          ? cachedAssignments[cachedIndex]
          : Map<String, dynamic>.from(assignment);
      final serverVersion =
          int.tryParse(base['progress_version']?.toString() ?? '') ??
          int.tryParse(assignment['progress_version']?.toString() ?? '') ??
          0;
      final payload = <String, dynamic>{
        'assignment_id': assignmentId,
        'task_id': taskId,
        'status': status,
        'progress_notes': progressNotes,
        'expected_version': serverVersion + outstandingCount,
        'original_updated_at': originalUpdatedAt,
      };

      await txn.insert('sync_queue', {
        'queue_id': queueId,
        'owner_id': owner,
        'operation': 'task_status',
        'client_id': clientId,
        'payload': jsonEncode(payload),
        'created_at': originalUpdatedAt,
        'status': 'waiting',
      });

      final optimistic = Map<String, dynamic>.from(base)
        ..['status'] = status
        ..['progress_notes'] = progressNotes
        ..['sync_status'] = 'waiting'
        ..['sync_queue_id'] = queueId
        ..remove('sync_error');
      if (cachedIndex >= 0) {
        cachedAssignments[cachedIndex] = optimistic;
      } else {
        cachedAssignments.insert(0, optimistic);
      }
      await txn.insert('user_cache', {
        'owner_id': owner,
        'cache_key': 'tasks',
        'payload': jsonEncode(cachedAssignments),
        'fetched_at': fetchedAt ?? originalUpdatedAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    _queueChanged();
    unawaited(syncPendingLeaves());
    return queueId;
  }

  static int? _positiveId(dynamic value) {
    final id = int.tryParse(value?.toString() ?? '');
    return id != null && id > 0 ? id : null;
  }

  static Future<Map<String, dynamic>?> getTaskSyncState(
    String assignmentId,
  ) async {
    final owner = await ApiService.getCurrentUserId();
    if (owner == null) return null;
    final db = await database;
    final rows = await db.query(
      'sync_queue',
      where: 'owner_id = ? AND operation = ?',
      whereArgs: [owner.toString(), 'task_status'],
      orderBy: 'rowid ASC',
    );
    Map<String, Object?>? latestRow;
    Map<String, Object?>? failedRow;
    for (final row in rows) {
      final payload = jsonDecode(row['payload'] as String);
      if (payload is Map &&
          payload['assignment_id']?.toString() == assignmentId) {
        latestRow = row;
        if (failedRow == null && row['status'] == 'failed') failedRow = row;
      }
    }
    if (latestRow == null) return null;
    final latestPayload = jsonDecode(latestRow['payload'] as String) as Map;
    final stateRow = failedRow ?? latestRow;
    return {
      ...Map<String, dynamic>.from(latestPayload),
      'queue_id': stateRow['queue_id'],
      'sync_status': stateRow['status'],
      'last_error': stateRow['last_error'],
    };
  }

  static Future<void> _refreshCachedTasks(
    String owner,
    DatabaseExecutor db,
  ) async {
    final cacheRows = await db.query(
      'user_cache',
      where: 'owner_id = ? AND cache_key = ?',
      whereArgs: [owner, 'tasks'],
      limit: 1,
    );
    if (cacheRows.isEmpty) return;

    try {
      final decoded = jsonDecode(cacheRows.first['payload'] as String);
      if (decoded is! List) return;
      final assignments = decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final rows = await db.query(
        'sync_queue',
        where: 'owner_id = ? AND operation = ?',
        whereArgs: [owner, 'task_status'],
        orderBy: 'rowid ASC',
      );
      final latestByAssignment = <String, Map<String, Object?>>{};
      final failedByAssignment = <String, Map<String, Object?>>{};
      for (final row in rows) {
        final payload = jsonDecode(row['payload'] as String);
        if (payload is Map && payload['assignment_id'] != null) {
          final assignmentId = payload['assignment_id'].toString();
          latestByAssignment[assignmentId] = row;
          if (row['status'] == 'failed') {
            failedByAssignment.putIfAbsent(assignmentId, () => row);
          }
        }
      }

      for (final assignment in assignments) {
        final assignmentId = assignment['id']?.toString();
        if (assignmentId == null) continue;
        final latestRow = latestByAssignment[assignmentId];
        if (latestRow == null) continue;
        final latestPayload = jsonDecode(latestRow['payload'] as String) as Map;
        final latestStatus = latestRow['status']?.toString() ?? 'waiting';
        if (latestStatus != 'synced') {
          assignment['status'] = latestPayload['status'];
          assignment['progress_notes'] = latestPayload['progress_notes'];
        }

        final stateRow = failedByAssignment[assignmentId] ?? latestRow;
        assignment['sync_status'] = stateRow['status']?.toString() ?? 'waiting';
        assignment['sync_error'] = stateRow['last_error'];
        assignment['sync_queue_id'] = stateRow['queue_id'];
        if (stateRow['status'] == 'synced') assignment.remove('sync_error');
      }

      await db.update(
        'user_cache',
        {'payload': jsonEncode(assignments)},
        where: 'owner_id = ? AND cache_key = ?',
        whereArgs: [owner, 'tasks'],
      );
    } on FormatException {
      // Keep the cache available to the caller if its JSON is malformed.
    }
  }

  static Future<void> _migrateLegacyQueues(DatabaseExecutor db) async {
    await _createQueueTable(db);
    final now = DateTime.now().toUtc().toIso8601String();

    final oldLeaves = await _readLegacyTable(db, 'leaves_queue');
    for (final row in oldLeaves) {
      final owner = row['user_id']?.toString();
      final clientId = row['sync_id']?.toString();
      if (owner == null || clientId == null) continue;
      final payload = {
        'start_date': row['start_date'],
        'end_date': row['end_date'],
        'leave_type': row['leave_type'],
        'reason': row['reason'],
      };
      await _insertMigrated(db, owner, 'leave', clientId, payload, now);
    }

    final oldAttendance = await _readLegacyTable(db, 'attendance_queue');
    for (final row in oldAttendance) {
      final owner = row['user_id']?.toString();
      final clientId = row['sync_id']?.toString();
      if (owner == null || clientId == null) continue;
      final payload = {
        'attendance_date': row['attendance_date'],
        'check_in': row['check_in'],
        'latitude': row['latitude'],
        'longitude': row['longitude'],
      };
      await _insertMigrated(db, owner, 'attendance', clientId, payload, now);
    }

    // The transaction keeps source rows if the copy fails. Each valid legacy
    // request is now represented in the unified queue before old tables go.
    await db.execute('DROP TABLE IF EXISTS leaves_queue');
    await db.execute('DROP TABLE IF EXISTS attendance_queue');
  }

  static Future<List<Map<String, Object?>>> _readLegacyTable(
    DatabaseExecutor db,
    String table,
  ) async {
    try {
      return await db.query(table);
    } on DatabaseException {
      return const [];
    }
  }

  static Future<void> _insertMigrated(
    DatabaseExecutor db,
    String owner,
    String operation,
    String clientId,
    Map<String, dynamic> payload,
    String createdAt,
  ) async {
    await db.insert('sync_queue', {
      'queue_id': '$operation-$owner-$clientId',
      'owner_id': owner,
      'operation': operation,
      'client_id': clientId,
      'payload': jsonEncode(payload),
      'created_at': createdAt,
      'status': 'waiting',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<String> _currentOwnerId() async {
    final id = await ApiService.getCurrentUserId();
    if (id == null) {
      throw StateError('Sign in before saving an offline request.');
    }
    return id.toString();
  }

  static Future<String> queueLeaveRequest({
    required String startDate,
    required String endDate,
    required String leaveType,
    required String reason,
    String? queueId,
  }) async {
    final start = DateTime.tryParse(startDate);
    final end = DateTime.tryParse(endDate);
    if (start == null ||
        end == null ||
        _dateOnly(end).isBefore(_dateOnly(start))) {
      throw ArgumentError(
        'Enter valid dates and make sure the end date is not before the start date.',
      );
    }
    if (leaveType.trim().isEmpty) throw ArgumentError('Choose a leave type.');
    if (reason.length > 5000) {
      throw ArgumentError('The reason must be 5000 characters or fewer.');
    }

    final owner = await _currentOwnerId();
    final db = await database;
    final existing = queueId == null
        ? null
        : await db.query(
            'sync_queue',
            where: 'queue_id = ? AND owner_id = ?',
            whereArgs: [queueId, owner],
            limit: 1,
          );
    final clientId = existing?.isNotEmpty == true
        ? existing!.first['client_id'] as String
        : _uuid.v4();
    final id = existing?.isNotEmpty == true
        ? queueId!
        : 'leave-$owner-$clientId';
    final payload = {
      'start_date': _dateOnly(start).toIso8601String().substring(0, 10),
      'end_date': _dateOnly(end).toIso8601String().substring(0, 10),
      'leave_type': leaveType.trim(),
      'reason': reason.trim().isEmpty ? null : reason.trim(),
    };

    if (existing?.isNotEmpty == true) {
      await db.update(
        'sync_queue',
        {
          'payload': jsonEncode(payload),
          'status': 'waiting',
          'retry_count': 0,
          'next_attempt_at': null,
          'last_error': null,
        },
        where: 'queue_id = ? AND owner_id = ?',
        whereArgs: [id, owner],
      );
    } else {
      await db.insert('sync_queue', {
        'queue_id': id,
        'owner_id': owner,
        'operation': 'leave',
        'client_id': clientId,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'waiting',
      });
    }
    _queueChanged();
    return id;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  static Future<String> queueLocationEvent({
    required double latitude,
    required double longitude,
    required DateTime recordedAt,
    double? accuracy,
    String purpose = 'Employee requested location check',
  }) async {
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('The location coordinates are invalid.');
    }
    final owner = await _currentOwnerId();
    final clientId = _uuid.v4();
    final id = 'location-$owner-$clientId';
    final payload = {
      'client_event_id': clientId,
      'latitude': latitude,
      'longitude': longitude,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
      'accuracy': accuracy,
      'purpose': purpose,
    };
    final db = await database;
    await db.insert('sync_queue', {
      'queue_id': id,
      'owner_id': owner,
      'operation': 'location',
      'client_id': clientId,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'waiting',
    });
    _queueChanged();
    return id;
  }

  static Future<String> queueFeedback({
    required String category,
    required String subject,
    required String message,
    int? rating,
  }) async {
    if (category.trim().isEmpty ||
        subject.trim().isEmpty ||
        message.trim().isEmpty) {
      throw ArgumentError(
        'Complete the feedback category, subject, and message.',
      );
    }
    if (subject.trim().length > 160 || message.trim().length > 5000) {
      throw ArgumentError('Feedback is longer than the allowed limit.');
    }
    if (rating != null && (rating < 1 || rating > 5)) {
      throw ArgumentError('Choose a rating from 1 to 5.');
    }

    final owner = await _currentOwnerId();
    final db = await database;
    final clientId = _uuid.v4();
    final id = 'feedback-$owner-$clientId';
    final payload = {
      'client_submission_id': clientId,
      'category': category,
      'subject': subject.trim(),
      'message': message.trim(),
      'rating': rating,
    };
    await db.insert('sync_queue', {
      'queue_id': id,
      'owner_id': owner,
      'operation': 'feedback',
      'client_id': clientId,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'waiting',
    });
    _queueChanged();
    return id;
  }

  static Future<String> queueAttendance({
    required String attendanceDate,
    required String checkIn,
    double? latitude,
    double? longitude,
  }) async {
    final parsedDate = DateTime.tryParse(attendanceDate);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(attendanceDate) ||
        parsedDate == null ||
        parsedDate.toIso8601String().substring(0, 10) != attendanceDate) {
      throw ArgumentError('Enter a valid attendance date.');
    }
    if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d$').hasMatch(checkIn)) {
      throw ArgumentError('Enter a valid check-in time.');
    }
    if ((latitude != null && (latitude < -90 || latitude > 90)) ||
        (longitude != null && (longitude < -180 || longitude > 180))) {
      throw ArgumentError('The location coordinates are invalid.');
    }

    final owner = await _currentOwnerId();
    final db = await database;
    late String id;

    await db.transaction((txn) async {
      // Serialize local check-and-insert so two taps cannot queue two records
      // for the same employee and date.
      final existingItems = await txn.query(
        'sync_queue',
        where: 'owner_id = ? AND operation = ?',
        whereArgs: [owner, 'attendance'],
      );

      for (final item in existingItems) {
        final payload = jsonDecode(item['payload'] as String);
        if (payload is Map &&
            payload['attendance_date']?.toString() == attendanceDate) {
          throw Exception('Attendance already exists for this date.');
        }
      }

      final clientId = _uuid.v4();
      id = 'attendance-$owner-$clientId';
      final payload = {
        'attendance_date': attendanceDate,
        'check_in': checkIn,
        'latitude': latitude,
        'longitude': longitude,
      };

      await txn.insert('sync_queue', {
        'queue_id': id,
        'owner_id': owner,
        'operation': 'attendance',
        'client_id': clientId,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'waiting',
      });
    });

    _queueChanged();
    return id;
  }

  static Future<String> queueAttendanceAction({
    required String attendanceDate,
    required String actionType,
    required DateTime actionAt,
    required DateTime capturedAt,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    final parsedDate = DateTime.tryParse(attendanceDate);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(attendanceDate) ||
        parsedDate == null ||
        parsedDate.toIso8601String().substring(0, 10) != attendanceDate) {
      throw ArgumentError('Enter a valid attendance date.');
    }
    if (actionType != 'check_in' && actionType != 'check_out') {
      throw ArgumentError('Choose a valid attendance action.');
    }
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw ArgumentError('The location coordinates are invalid.');
    }
    if (!accuracy.isFinite || accuracy < 0 || accuracy > 100) {
      throw ArgumentError('The GPS accuracy is outside the attendance limit.');
    }

    final actionDate =
        '${actionAt.year.toString().padLeft(4, '0')}-'
        '${actionAt.month.toString().padLeft(2, '0')}-'
        '${actionAt.day.toString().padLeft(2, '0')}';
    final actionTime =
        '${actionAt.hour.toString().padLeft(2, '0')}:'
        '${actionAt.minute.toString().padLeft(2, '0')}:'
        '${actionAt.second.toString().padLeft(2, '0')}';
    if (actionType == 'check_in' && actionDate != attendanceDate) {
      throw ArgumentError('Check-in date must match the attendance date.');
    }

    final owner = await _currentOwnerId();
    final db = await database;
    late String queueId;
    await db.transaction((txn) async {
      final existingItems = await txn.query(
        'sync_queue',
        where: 'owner_id = ? AND operation = ?',
        whereArgs: [owner, 'attendance'],
      );
      for (final item in existingItems) {
        final payload = jsonDecode(item['payload'] as String);
        if (payload is! Map ||
            payload['attendance_date']?.toString() != attendanceDate) {
          continue;
        }
        final queuedAction = payload['action_type']?.toString() ?? 'check_in';
        if (queuedAction == actionType) {
          throw StateError(
            actionType == 'check_in'
                ? 'Attendance already has a check-in for this date.'
                : 'Attendance already has a check-out for this date.',
          );
        }
      }

      final clientId = _uuid.v4();
      queueId = 'attendance-$owner-$clientId';
      final payload = {
        'action_type': actionType,
        'attendance_date': attendanceDate,
        'action_date': actionDate,
        'action_time': actionTime,
        'action_at': actionAt.toUtc().toIso8601String(),
        'captured_at': capturedAt.toUtc().toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'address_status': 'pending',
      };
      await txn.insert('sync_queue', {
        'queue_id': queueId,
        'owner_id': owner,
        'operation': 'attendance',
        'client_id': clientId,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'waiting',
        'address_status': 'pending',
        'address_retry_count': 0,
      });
    });

    _queueChanged();
    return queueId;
  }

  static Future<List<Map<String, dynamic>>> getQueueItems({
    String? operation,
    bool includeSynced = true,
  }) async {
    final owner = await ApiService.getCurrentUserId();
    if (owner == null) return [];
    final db = await database;
    final where = <String>['owner_id = ?'];
    final args = <Object?>[owner.toString()];
    if (operation != null) {
      where.add('operation = ?');
      args.add(operation);
    }
    if (!includeSynced) where.add("status != 'synced'");
    final rows = await db.query(
      'sync_queue',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC',
    );

    return rows.map((row) {
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      return {
        ...payload,
        'queue_id': row['queue_id'],
        'owner_id': row['owner_id'],
        'operation': row['operation'],
        'client_id': row['client_id'],
        'created_at': row['created_at'],
        'sync_status': row['status'],
        'retry_count': row['retry_count'],
        'last_error': row['last_error'],
        'server_record_id': row['server_record_id'],
        'synced_at': row['synced_at'],
        'address_status': row['address_status'],
        'address_retry_count': row['address_retry_count'],
        'address_next_attempt_at': row['address_next_attempt_at'],
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getPendingLeaves() async =>
      getQueueItems(operation: 'leave', includeSynced: false);

  static Future<List<Map<String, dynamic>>> getPendingAttendance() async =>
      getQueueItems(operation: 'attendance', includeSynced: false);

  static Future<void> retryQueueItem(String queueId) async {
    final owner = await ApiService.getCurrentUserId();
    if (owner == null) return;
    final db = await database;
    final rows = await db.query(
      'sync_queue',
      where: 'queue_id = ? AND owner_id = ?',
      whereArgs: [queueId, owner.toString()],
      limit: 1,
    );
    if (rows.isNotEmpty && rows.first['operation'] == 'task_status') {
      await _retryTaskQueueItem(rows.first, owner.toString());
      return;
    }
    await db.update(
      'sync_queue',
      {
        'status': 'waiting',
        'retry_count': 0,
        'next_attempt_at': null,
        'last_error': null,
      },
      where: 'queue_id = ? AND owner_id = ?',
      whereArgs: [queueId, owner.toString()],
    );
    _queueChanged();
    await syncPendingLeaves(force: true);
  }

  static Future<void> _retryTaskQueueItem(
    Map<String, Object?> row,
    String owner,
  ) async {
    final queueId = row['queue_id'] as String;
    final payload =
        jsonDecode(row['payload'] as String) as Map<String, dynamic>;
    final assignmentId = payload['assignment_id']?.toString();
    if (assignmentId == null) return;

    Map<String, dynamic>? serverAssignment;
    try {
      final response = await ApiService.get('/employee/tasks/$assignmentId');
      final data = response['data'];
      if (ApiService.isSuccess(response['status']) && data is Map) {
        final assignment = data['assignment'];
        if (assignment is Map && assignment['id']?.toString() == assignmentId) {
          serverAssignment = Map<String, dynamic>.from(assignment);
        }
      }
    } catch (_) {
      // Keep the failed event intact when the server cannot be reached.
    }
    if (serverAssignment == null) return;

    final db = await database;
    final serverVersion =
        int.tryParse(serverAssignment['progress_version']?.toString() ?? '') ??
        0;
    await db.transaction((txn) async {
      final currentRows = await txn.query(
        'sync_queue',
        columns: ['rowid', 'payload'],
        where: 'queue_id = ? AND owner_id = ?',
        whereArgs: [queueId, owner],
        limit: 1,
      );
      if (currentRows.isEmpty) return;
      final currentPayload =
          jsonDecode(currentRows.first['payload'] as String)
              as Map<String, dynamic>;
      currentPayload['expected_version'] = serverVersion;
      await txn.update(
        'sync_queue',
        {
          'payload': jsonEncode(currentPayload),
          'status': 'waiting',
          'retry_count': 0,
          'next_attempt_at': null,
          'last_error': null,
        },
        where: 'queue_id = ? AND owner_id = ?',
        whereArgs: [queueId, owner],
      );
      await _rebaseFollowingTaskUpdates(
        txn,
        owner,
        assignmentId,
        currentRows.first['rowid'] as int,
        serverVersion + 1,
      );
      await _storeTaskAssignmentInCache(txn, owner, serverAssignment!);
    });
    await _refreshCachedTasks(owner, db);
    _queueChanged();
    await syncPendingLeaves(force: true);
  }

  static Future<void> _rebaseFollowingTaskUpdates(
    DatabaseExecutor db,
    String owner,
    String assignmentId,
    int afterRowId,
    int nextVersion,
  ) async {
    final rows = await db.query(
      'sync_queue',
      where: 'owner_id = ? AND operation = ? AND rowid > ?',
      whereArgs: [owner, 'task_status', afterRowId],
      orderBy: 'rowid ASC',
    );
    var expectedVersion = nextVersion;
    for (final row in rows) {
      final payload = jsonDecode(row['payload'] as String);
      if (payload is! Map ||
          payload['assignment_id']?.toString() != assignmentId ||
          row['status'] == 'synced') {
        continue;
      }
      final updated = Map<String, dynamic>.from(payload)
        ..['expected_version'] = expectedVersion;
      await db.update(
        'sync_queue',
        {'payload': jsonEncode(updated)},
        where: 'queue_id = ? AND owner_id = ?',
        whereArgs: [row['queue_id'], owner],
      );
      expectedVersion++;
    }
  }

  static Future<void> _storeTaskAssignmentInCache(
    DatabaseExecutor db,
    String owner,
    Map<String, dynamic> serverAssignment,
  ) async {
    final cacheRows = await db.query(
      'user_cache',
      where: 'owner_id = ? AND cache_key = ?',
      whereArgs: [owner, 'tasks'],
      limit: 1,
    );
    if (cacheRows.isEmpty) return;
    try {
      final decoded = jsonDecode(cacheRows.first['payload'] as String);
      if (decoded is! List) return;
      final assignments = decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      final index = assignments.indexWhere(
        (row) => row['id']?.toString() == serverAssignment['id']?.toString(),
      );
      if (index >= 0) {
        assignments[index] = Map<String, dynamic>.from(serverAssignment);
        await db.update(
          'user_cache',
          {'payload': jsonEncode(assignments)},
          where: 'owner_id = ? AND cache_key = ?',
          whereArgs: [owner, 'tasks'],
        );
      }
    } on FormatException {
      // A later successful task-list fetch will repair malformed cache JSON.
    }
  }

  static Future<void> retryAddressResolution(String queueId) async {
    final owner = await ApiService.getCurrentUserId();
    if (owner == null) return;
    final db = await database;
    await db.update(
      'sync_queue',
      {'address_retry_count': 0, 'address_next_attempt_at': null},
      where: "queue_id = ? AND owner_id = ? AND address_status = 'pending'",
      whereArgs: [queueId, owner.toString()],
    );
    _queueChanged();
    await syncPendingLeaves(force: true);
  }

  static Future<void> syncPendingLeaves({bool force = false}) async {
    if (_syncing) {
      _syncRequestedWhileRunning = true;
      return;
    }
    _syncing = true;
    try {
      final owner = await ApiService.getCurrentUserId();
      final token = await ApiService.getStoredToken();
      if (owner == null || token == null || token.isEmpty) return;

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.isEmpty ||
          connectivity.every((result) => result == ConnectivityResult.none)) {
        return;
      }

      for (final operation in ['leave', 'attendance', 'location', 'feedback']) {
        final items = await _rowsReadyToSync(
          owner.toString(),
          operation,
          force,
        );
        for (final item in items) {
          if (await ApiService.getCurrentUserId() != owner) return;
          if (await ApiService.getStoredToken() != token) return;
          await _syncItem(item);
        }
      }
      await _syncTaskQueue(owner.toString(), force: force, token: token);
      await _syncPendingAddresses(owner.toString(), force: force);
    } catch (error) {
      // Do not log payloads, tokens, or exact coordinates.
      // debugPrint('Offline sync could not run: ${error.runtimeType}');

      debugPrint('Offline sync failed (${error.runtimeType}).');
    } finally {
      _syncing = false;
      await _scheduleRetry();
      if (_syncRequestedWhileRunning) {
        _syncRequestedWhileRunning = false;
        unawaited(syncPendingLeaves());
      }
    }
  }

  static Future<void> _syncTaskQueue(
    String owner, {
    required bool force,
    required String token,
  }) async {
    final db = await database;
    final rows = await db.query(
      'sync_queue',
      where: 'owner_id = ? AND operation = ?',
      whereArgs: [owner, 'task_status'],
      orderBy: 'rowid ASC',
    );
    final blockedAssignments = <String>{};
    final now = DateTime.now().toUtc();

    for (final row in rows) {
      final payload = jsonDecode(row['payload'] as String);
      if (payload is! Map) continue;
      final assignmentId = payload['assignment_id']?.toString();
      if (assignmentId == null || blockedAssignments.contains(assignmentId)) {
        continue;
      }

      final status = row['status']?.toString();
      if (status == 'synced') continue;
      if (status == 'failed' || (status != 'waiting' && status != 'retry')) {
        blockedAssignments.add(assignmentId);
        continue;
      }
      final nextAttempt = DateTime.tryParse(
        row['next_attempt_at']?.toString() ?? '',
      );
      if (!force && nextAttempt != null && nextAttempt.isAfter(now)) {
        blockedAssignments.add(assignmentId);
        continue;
      }

      if (await ApiService.getCurrentUserId() != int.tryParse(owner) ||
          await ApiService.getStoredToken() != token) {
        return;
      }
      await _syncItem(row);

      final refreshed = await db.query(
        'sync_queue',
        columns: ['status'],
        where: 'queue_id = ? AND owner_id = ?',
        whereArgs: [row['queue_id'], owner],
        limit: 1,
      );
      if (refreshed.isEmpty || refreshed.first['status'] != 'synced') {
        blockedAssignments.add(assignmentId);
      }
    }
  }

  static Future<List<Map<String, Object?>>> _rowsReadyToSync(
    String owner,
    String operation,
    bool force,
  ) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    return db.query(
      'sync_queue',
      where: force
          ? "owner_id = ? AND operation = ? AND status IN ('waiting', 'retry')"
          : "owner_id = ? AND operation = ? AND status IN ('waiting', 'retry') AND (next_attempt_at IS NULL OR next_attempt_at <= ?)",
      whereArgs: force ? [owner, operation] : [owner, operation, now],
      orderBy: 'created_at ASC, rowid ASC',
    );
  }

  static Future<void> _syncItem(Map<String, Object?> row) async {
    final db = await database;
    final queueId = row['queue_id'] as String;
    final owner = row['owner_id'] as String;
    final operation = row['operation'] as String;
    final clientId = row['client_id'] as String;
    final payload =
        jsonDecode(row['payload'] as String) as Map<String, dynamic>;

    await db.update(
      'sync_queue',
      {'status': 'syncing', 'last_error': null},
      where: 'queue_id = ? AND owner_id = ?',
      whereArgs: [queueId, owner],
    );
    if (operation == 'task_status') {
      await _refreshCachedTasks(owner, db);
    }
    _queueChanged();

    try {
      final endpoint = switch (operation) {
        'leave' => '/employee/leaves',
        'attendance' =>
          payload.containsKey('action_type')
              ? '/employee/attendance-actions'
              : '/employee/attendance',
        'location' => '/employee/location-events',
        'feedback' => '/employee/feedback',
        'task_status' => '/employee/tasks/${payload['assignment_id']}/progress',
        _ => throw StateError('Unsupported queued operation'),
      };
      final body = operation == 'leave'
          ? {...payload, 'sync_id': clientId}
          : operation == 'attendance'
          ? payload.containsKey('action_type')
                ? {...payload, 'client_event_id': clientId}
                : {...payload, 'sync_id': clientId}
          : operation == 'task_status'
          ? {
              ...payload,
              'client_event_id': clientId,
              'client_updated_at': payload['original_updated_at'],
            }
          : payload;
      final response = operation == 'task_status'
          ? await ApiService.patch(endpoint, body)
          : await ApiService.post(endpoint, body);
      final status = response['status'];
      final data = response['data'];

      if (ApiService.isSuccess(status)) {
        if (operation == 'attendance' &&
            payload.containsKey('action_type') &&
            !_isAttendanceActionConfirmed(data, clientId)) {
          await _markRetry(
            row,
            'The server response did not confirm the saved attendance location. The event remains queued.',
          );
          return;
        }
        if (operation == 'task_status') {
          final assignment = data is Map ? data['assignment'] : null;
          if (assignment is! Map ||
              assignment['id']?.toString() !=
                  payload['assignment_id']?.toString() ||
              data['client_event_id']?.toString() != clientId ||
              assignment['progress_version'] == null) {
            await _markRetry(
              row,
              'The server did not confirm this task update. It remains queued.',
            );
            return;
          }

          final serverAssignment = Map<String, dynamic>.from(assignment);
          final assignmentVersion = int.tryParse(
            serverAssignment['progress_version'].toString(),
          );
          if (assignmentVersion == null) {
            await _markRetry(
              row,
              'The server response did not include a task version. The update remains queued.',
            );
            return;
          }
          await db.transaction((txn) async {
            await _storeTaskAssignmentInCache(txn, owner, serverAssignment);
            final eventRows = await txn.query(
              'sync_queue',
              columns: ['rowid'],
              where: 'queue_id = ? AND owner_id = ?',
              whereArgs: [queueId, owner],
              limit: 1,
            );
            if (eventRows.isNotEmpty) {
              await _rebaseFollowingTaskUpdates(
                txn,
                owner,
                payload['assignment_id'].toString(),
                eventRows.first['rowid'] as int,
                assignmentVersion,
              );
            }
            await txn.update(
              'sync_queue',
              {
                'status': 'synced',
                'server_record_id': int.tryParse(
                  serverAssignment['id'].toString(),
                ),
                'synced_at': DateTime.now().toUtc().toIso8601String(),
                'last_error': null,
                'next_attempt_at': null,
              },
              where: 'queue_id = ? AND owner_id = ?',
              whereArgs: [queueId, owner],
            );
          });
          await _refreshCachedTasks(owner, db);
          _queueChanged();
          return;
        }
        final record = data is Map
            ? data[switch (operation) {
                'location' => 'event',
                'feedback' => 'feedback',
                _ => operation,
              }]
            : null;
        final serverId = record is Map ? record['id'] : null;
        final locationEvent =
            operation == 'attendance' &&
                payload.containsKey('action_type') &&
                data is Map
            ? data['event']
            : null;
        final updatedPayload = Map<String, dynamic>.from(payload);
        final addressStatus = locationEvent is Map
            ? _validAddressStatus(locationEvent['address_status'])
            : 'none';
        if (locationEvent is Map) {
          updatedPayload['address'] = locationEvent['address'];
          updatedPayload['address_status'] = addressStatus;
          updatedPayload['address_resolved_at'] =
              locationEvent['address_resolved_at'];
        }
        final addressRetryAt = addressStatus == 'pending'
            ? DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 1))
                  .toIso8601String()
            : null;
        await db.update(
          'sync_queue',
          {
            'payload': jsonEncode(updatedPayload),
            'status': 'synced',
            'server_record_id': serverId is int
                ? serverId
                : int.tryParse('$serverId'),
            'synced_at': data is Map
                ? data['server_confirmed_at']?.toString() ??
                      (record is Map
                          ? record['synced_at']?.toString()
                          : null) ??
                      DateTime.now().toUtc().toIso8601String()
                : DateTime.now().toUtc().toIso8601String(),
            'last_error': null,
            'next_attempt_at': null,
            if (operation == 'attendance' &&
                payload.containsKey('action_type')) ...{
              'address_status': addressStatus,
              'address_retry_count': 0,
              'address_next_attempt_at': addressRetryAt,
            },
          },
          where: 'queue_id = ? AND owner_id = ?',
          whereArgs: [queueId, owner],
        );
        _queueChanged();
        return;
      }

      if (status == 401) {
        await _markRetry(
          row,
          'Sign in again to continue syncing this request.',
          immediate: true,
        );
        return;
      }

      final message = _safeServerMessage(data, status);
      if (status == 422 || status == 403 || status == 404 || status == 409) {
        if (operation == 'task_status' &&
            status == 409 &&
            data is Map &&
            data['assignment'] is Map) {
          await _storeTaskAssignmentInCache(
            db,
            owner,
            Map<String, dynamic>.from(data['assignment'] as Map),
          );
        }
        await db.update(
          'sync_queue',
          {'status': 'failed', 'last_error': message, 'next_attempt_at': null},
          where: 'queue_id = ? AND owner_id = ?',
          whereArgs: [queueId, owner],
        );
        if (operation == 'task_status') {
          await _refreshCachedTasks(owner, db);
        }
        _queueChanged();
        return;
      }

      await _markRetry(row, message);
    } catch (error) {
      await _markRetry(
        row,
        'Network or server error. The request is scheduled to retry.',
      );
      debugPrint('Queued $operation sync failed: ${error.runtimeType}');
    }
  }

  static bool _isAttendanceActionConfirmed(dynamic data, String clientId) {
    if (data is! Map) return false;
    final attendance = data['attendance'];
    final event = data['event'];
    return attendance is Map &&
        attendance['id'] != null &&
        event is Map &&
        event['id'] != null &&
        event['client_event_id']?.toString() == clientId &&
        event['synced_at'] != null &&
        data['server_confirmed_at'] != null;
  }

  static String _validAddressStatus(dynamic value) =>
      switch (value?.toString()) {
        'resolved' => 'resolved',
        'unavailable' => 'unavailable',
        'pending' => 'pending',
        _ => 'pending',
      };

  static Future<void> _syncPendingAddresses(
    String owner, {
    required bool force,
  }) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await db.query(
      'sync_queue',
      where: force
          ? "owner_id = ? AND operation = 'attendance' AND status = 'synced' AND address_status = 'pending'"
          : "owner_id = ? AND operation = 'attendance' AND status = 'synced' AND address_status = 'pending' AND (address_next_attempt_at IS NULL OR address_next_attempt_at <= ?)",
      whereArgs: force ? [owner] : [owner, now],
      orderBy: 'created_at ASC',
    );

    for (final row in rows) {
      final currentOwner = await ApiService.getCurrentUserId();
      if (currentOwner == null || currentOwner.toString() != owner) return;
      final token = await ApiService.getStoredToken();
      if (token == null || token.isEmpty) return;

      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      final clientId = row['client_id'] as String;
      try {
        final response = await ApiService.post(
          '/employee/attendance-actions/$clientId/resolve-address',
          const <String, dynamic>{},
        );
        final data = response['data'];
        final event = data is Map ? data['event'] : null;
        if (ApiService.isSuccess(response['status']) &&
            event is Map &&
            event['client_event_id']?.toString() == clientId) {
          final status = _validAddressStatus(event['address_status']);
          final updatedPayload = Map<String, dynamic>.from(payload)
            ..['address'] = event['address']
            ..['address_status'] = status
            ..['address_resolved_at'] = event['address_resolved_at'];
          final retryCount = status == 'pending'
              ? (row['address_retry_count'] as int? ?? 0) + 1
              : 0;
          final retryAt = status == 'pending'
              ? _nextAddressAttempt(retryCount)
              : null;
          await db.update(
            'sync_queue',
            {
              'payload': jsonEncode(updatedPayload),
              'address_status': status,
              'address_retry_count': retryCount,
              'address_next_attempt_at': retryAt,
            },
            where: 'queue_id = ? AND owner_id = ?',
            whereArgs: [row['queue_id'], owner],
          );
          _queueChanged();
        } else if (response['status'] == 404) {
          final updatedPayload = Map<String, dynamic>.from(payload)
            ..['address'] = null
            ..['address_status'] = 'unavailable';
          await db.update(
            'sync_queue',
            {
              'payload': jsonEncode(updatedPayload),
              'address_status': 'unavailable',
              'address_next_attempt_at': null,
            },
            where: 'queue_id = ? AND owner_id = ?',
            whereArgs: [row['queue_id'], owner],
          );
          _queueChanged();
        } else {
          await _scheduleAddressRetry(row, owner);
        }
      } catch (_) {
        await _scheduleAddressRetry(row, owner);
      }
    }
  }

  static Future<void> _scheduleAddressRetry(
    Map<String, Object?> row,
    String owner,
  ) async {
    final retries = (row['address_retry_count'] as int? ?? 0) + 1;
    await database.then(
      (db) => db.update(
        'sync_queue',
        {
          'address_retry_count': retries,
          'address_next_attempt_at': _nextAddressAttempt(retries),
        },
        where: 'queue_id = ? AND owner_id = ?',
        whereArgs: [row['queue_id'], owner],
      ),
    );
    _queueChanged();
  }

  static String _nextAddressAttempt(int retries) {
    final delayMinutes = (1 << (retries.clamp(1, 8).toInt() - 1))
        .clamp(1, 360)
        .toInt();
    return DateTime.now()
        .toUtc()
        .add(Duration(minutes: delayMinutes))
        .toIso8601String();
  }

  static String _safeServerMessage(dynamic data, dynamic status) {
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.length <= 300) return message;
      final errors = data['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            final text = value.first.toString();
            return text.substring(0, text.length.clamp(0, 300).toInt());
          }
        }
      }
    }
    return ApiService.messageForStatus(status);
  }

  static Future<void> _markRetry(
    Map<String, Object?> row,
    String message, {
    bool immediate = false,
  }) async {
    final retries = (row['retry_count'] as int? ?? 0) + 1;
    final delayMinutes = immediate
        ? 0
        : (1 << (retries.clamp(1, 8).toInt() - 1)).clamp(1, 360).toInt();
    final next = immediate
        ? null
        : DateTime.now()
              .toUtc()
              .add(Duration(minutes: delayMinutes))
              .toIso8601String();
    final db = await database;
    await db.update(
      'sync_queue',
      {
        'status': 'retry',
        'retry_count': retries,
        'next_attempt_at': next,
        'last_error': message.substring(
          0,
          message.length.clamp(0, 300).toInt(),
        ),
      },
      where: 'queue_id = ? AND owner_id = ?',
      whereArgs: [row['queue_id'], row['owner_id']],
    );
    if (row['operation'] == 'task_status') {
      await _refreshCachedTasks(row['owner_id'] as String, db);
    }
    _queueChanged();
  }

  static Future<void> _scheduleRetry() async {
    _retryTimer?.cancel();
    _retryTimer = null;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.isEmpty ||
          connectivity.every((result) => result == ConnectivityResult.none)) {
        return;
      }

      final owner = await ApiService.getCurrentUserId();
      if (owner == null) return;
      final db = await database;
      final rows = await db.query(
        'sync_queue',
        columns: ['next_attempt_at', 'address_next_attempt_at'],
        where:
            "owner_id = ? AND ((status = 'retry' AND next_attempt_at IS NOT NULL) OR (address_status = 'pending' AND address_next_attempt_at IS NOT NULL))",
        whereArgs: [owner.toString()],
      );
      DateTime? nextAttempt;
      for (final row in rows) {
        for (final field in ['next_attempt_at', 'address_next_attempt_at']) {
          final parsed = DateTime.tryParse(row[field] as String? ?? '');
          if (parsed != null &&
              (nextAttempt == null || parsed.isBefore(nextAttempt))) {
            nextAttempt = parsed;
          }
        }
      }
      if (nextAttempt == null) return;

      final delay = nextAttempt.difference(DateTime.now().toUtc());
      _retryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
        unawaited(syncPendingLeaves());
      });
    } catch (_) {
      // Connectivity, app resume, or the next app start will retry queue setup.
    }
  }

  static void startConnectivityListener() {
    _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        syncPendingLeaves();
      }
    });
    unawaited(syncPendingLeaves());
  }
}
