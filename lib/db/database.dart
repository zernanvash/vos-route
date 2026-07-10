import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._();
  static Database? _database;

  AppDatabase._();

  factory AppDatabase() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'vosroute.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          'ALTER TABLE emergency_queue ADD COLUMN driver_user_id INTEGER',
        );
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) {
          rethrow;
        }
      }
    }

    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
  }

  Future<void> _migrateToV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS action_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        action_payload TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        http_method TEXT NOT NULL,
        batch_group TEXT,
        batch_priority INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0,
        max_retries INTEGER DEFAULT 5,
        created_at TEXT,
        last_attempt TEXT,
        last_error TEXT
      )
    ''');

    try {
      final hasCachedTrips = await _tableExists(db, 'cached_trips');
      final hasGpsQueue = await _tableExists(db, 'gps_queue');
      final hasPodQueue = await _tableExists(db, 'pod_queue');
      final hasTripPhotoQueue = await _tableExists(db, 'trip_photo_queue');
      final hasEmergencyQueue = await _tableExists(db, 'emergency_queue');
      final hasAdHocStopQueue = await _tableExists(db, 'ad_hoc_stop_queue');

      if (hasGpsQueue) {
        final unsyncedGps = await db.query(
          'gps_queue',
          where: 'synced = 0',
          limit: 500,
        );
        for (final row in unsyncedGps) {
          final tripId = row['trip_id'] as int? ?? 0;
          final points = [
            {
              'trip_id': tripId,
              'latitude': row['latitude'],
              'longitude': row['longitude'],
              'accuracy': row['accuracy'],
              'speed': row['speed'],
              'heading': row['heading'],
              'recorded_at': row['recorded_at'],
            },
          ];
          await db.insert('action_queue', {
            'action_type': 'gps_batch',
            'action_payload': jsonEncode(points),
            'endpoint': '/items/post_dispatch_gps_logs',
            'http_method': 'POST',
            'batch_group': 'gps:$tripId',
            'batch_priority': 3,
            'status': 'pending',
            'retry_count': 0,
            'max_retries': 5,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      if (hasPodQueue) {
        final unsyncedPods = await db.query('pod_queue', where: 'synced = 0');
        for (final row in unsyncedPods) {
          if (row['directus_uuid'] != null) {
            await db.insert('action_queue', {
              'action_type': 'link_pod_photo',
              'action_payload': jsonEncode({
                'post_dispatch_invoice_id': row['invoice_id'],
                'file': row['directus_uuid'],
                'doc_no': row['doc_no'],
              }),
              'endpoint': '/items/post_dispatch_nte',
              'http_method': 'POST',
              'batch_priority': 2,
              'status': 'pending',
              'retry_count': 0,
              'max_retries': 5,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }
      }

      if (hasTripPhotoQueue) {
        final unsyncedPhotos = await db.query(
          'trip_photo_queue',
          where: 'synced = 0',
        );
        for (final row in unsyncedPhotos) {
          if (row['directus_uuid'] != null) {
            await db.insert('action_queue', {
              'action_type': 'link_trip_photo',
              'action_payload': jsonEncode({
                'post_dispatch_plan_id': row['trip_id'],
                'file': row['directus_uuid'],
                'type': row['type'],
              }),
              'endpoint': '/items/post_dispatch_trip_photos',
              'http_method': 'POST',
              'batch_priority': 2,
              'status': 'pending',
              'retry_count': 0,
              'max_retries': 5,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }
      }

      if (hasEmergencyQueue) {
        final unsyncedEmergencies = await db.query(
          'emergency_queue',
          where: 'synced = 0',
        );
        for (final row in unsyncedEmergencies) {
          await db.insert('action_queue', {
            'action_type': 'submit_sos',
            'action_payload': jsonEncode({
              'report_no': row['report_no'],
              'incident_type': row['incident_type'],
              'severity': row['severity'],
              'description': row['description'],
              'latitude': row['latitude'],
              'longitude': row['longitude'],
              'location_name': row['location_name'],
              'vehicle_id': row['vehicle_id'],
              'dispatch_plan_id': row['dispatch_plan_id'],
              'driver_user_id': row['driver_user_id'],
              'contact_name': row['contact_name'],
              'contact_phone': row['contact_phone'],
              'status': row['status'] ?? 'reported',
              'occurred_at': DateTime.now().toUtc().toIso8601String(),
              'reported_at': DateTime.now().toUtc().toIso8601String(),
            }),
            'endpoint': '/items/fleet_emergency_reports',
            'http_method': 'POST',
            'batch_priority': 1,
            'status': 'pending',
            'retry_count': 0,
            'max_retries': 5,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      if (hasAdHocStopQueue) {
        final unsyncedStops = await db.query(
          'ad_hoc_stop_queue',
          where: 'synced = 0',
        );
        for (final row in unsyncedStops) {
          await db.insert('action_queue', {
            'action_type': 'add_ad_hoc_stop',
            'action_payload': jsonEncode({
              'post_dispatch_plan_id': row['trip_id'],
              'remarks': row['remarks'],
              'distance': row['distance'],
              'sequence': row['sequence'],
            }),
            'endpoint': '/items/post_dispatch_plan_others',
            'http_method': 'POST',
            'batch_priority': 2,
            'status': 'pending',
            'retry_count': 0,
            'max_retries': 5,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      final tablesToDrop = <String>[];
      if (hasGpsQueue) tablesToDrop.add('gps_queue');
      if (hasPodQueue) tablesToDrop.add('pod_queue');
      if (hasTripPhotoQueue) tablesToDrop.add('trip_photo_queue');
      if (hasEmergencyQueue) tablesToDrop.add('emergency_queue');
      if (hasAdHocStopQueue) tablesToDrop.add('ad_hoc_stop_queue');
      if (hasCachedTrips) tablesToDrop.add('cached_trips');

      for (final table in tablesToDrop) {
        try {
          await db.execute('DROP TABLE IF EXISTS $table');
        } catch (_) {}
      }
    } catch (e) {
      print('[AppDatabase] Migration v3 warning (non-fatal): $e');
    }
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    try {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE action_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        action_payload TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        http_method TEXT NOT NULL,
        batch_group TEXT,
        batch_priority INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0,
        max_retries INTEGER DEFAULT 5,
        created_at TEXT,
        last_attempt TEXT,
        last_error TEXT
      )
    ''');
  }
}
