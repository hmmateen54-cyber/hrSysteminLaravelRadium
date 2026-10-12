import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'api_service.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class OfflineSyncService {
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
  static StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;
  static const _uuid = Uuid();

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
      version: 3,
      onCreate: (db, _) => _createQueueTable(db),
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 3) await _migrateLegacyQueues(db);
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
    return id;
  }

  static Future<String> queueAttendance({
    required String attendanceDate,
    required String checkIn,
    double? latitude,
    double? longitude,
  }) async {
    final owner = await _currentOwnerId();
    final clientId = _uuid.v4();
    final id = 'attendance-$owner-$clientId';
    final payload = {
      'attendance_date': attendanceDate,
      'check_in': checkIn,
      'latitude': latitude,
      'longitude': longitude,
    };
    final db = await database;
    await db.insert('sync_queue', {
      'queue_id': id,
      'owner_id': owner,
      'operation': 'attendance',
      'client_id': clientId,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'waiting',
    });
    return id;
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
    await syncPendingLeaves(force: true);
  }

  static Future<void> syncPendingLeaves({bool force = false}) async {
    if (_syncing) return;
    _syncing = true;
    try {
      final owner = await ApiService.getCurrentUserId();
      final token = await ApiService.getStoredToken();
      if (owner == null || token == null || token.isEmpty) return;

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.length == 1 &&
          connectivity.first == ConnectivityResult.none) {
        return;
      }

      for (final operation in ['leave', 'attendance', 'location']) {
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
    } catch (error) {
      // Do not log payloads, tokens, or exact coordinates.
      // debugPrint('Offline sync could not run: ${error.runtimeType}');

      debugPrint('Offline sync error: $error');
      debugPrintStack(label: 'Offline sync stack trace');

    } finally {
      _syncing = false;
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
      orderBy: 'created_at ASC',
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

    try {
      final endpoint = switch (operation) {
        'leave' => '/employee/leaves',
        'attendance' => '/employee/attendance',
        'location' => '/employee/location-events',
        _ => throw StateError('Unsupported queued operation'),
      };
      final body = operation == 'leave'
          ? {...payload, 'sync_id': clientId}
          : operation == 'attendance'
          ? {...payload, 'sync_id': clientId}
          : payload;
      final response = await ApiService.post(endpoint, body);
      final status = response['status'];
      final data = response['data'];

      if (ApiService.isSuccess(status)) {
        final record = data is Map
            ? data[operation == 'location' ? 'event' : operation]
            : null;
        final serverId = record is Map ? record['id'] : null;
        await db.update(
          'sync_queue',
          {
            'status': 'synced',
            'server_record_id': serverId is int
                ? serverId
                : int.tryParse('$serverId'),
            'last_error': null,
            'next_attempt_at': null,
          },
          where: 'queue_id = ? AND owner_id = ?',
          whereArgs: [queueId, owner],
        );
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
        await db.update(
          'sync_queue',
          {'status': 'failed', 'last_error': message, 'next_attempt_at': null},
          where: 'queue_id = ? AND owner_id = ?',
          whereArgs: [queueId, owner],
        );
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
  }

  static void startConnectivityListener() {
    _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        syncPendingLeaves();
      }
    });
  }
}
