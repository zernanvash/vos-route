import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'tables/cached_settings_table.dart';
import 'tables/outbox_table.dart';
import '../services/secure_storage_service.dart';

part 'app_database.g.dart';

typedef LegacyQueueReader = Future<List<Map<String, Object?>>> Function();

@DriftDatabase(tables: [CachedSettings, OutboxActions])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;

  final LegacyQueueReader _legacyQueueReader;

  AppDatabase._internal()
    : _legacyQueueReader = _readLegacyQueue,
      super(_openConnection());

  AppDatabase.forTesting(super.executor, {LegacyQueueReader? legacyQueueReader})
    : _legacyQueueReader = legacyQueueReader ?? (() async => const []);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedFromLegacyQueue();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(outboxActions);
      }
      if (from < 3) await seedFromLegacyQueue();
    },
  );

  Future<void> seedFromLegacyQueue() async {
    try {
      final pending = await _legacyQueueReader();
      for (final row in pending) {
        final action = row['action_type'] as String;
        final argsJson = row['action_payload'] as String;
        final createdAt =
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now().toUtc();
        final duplicate =
            await (select(outboxActions)..where(
                  (t) =>
                      t.action.equals(action) &
                      t.argsJson.equals(argsJson) &
                      t.createdAt.equals(createdAt),
                ))
                .getSingleOrNull();
        if (duplicate != null) continue;
        await into(outboxActions).insert(
          OutboxActionsCompanion.insert(
            action: action,
            priority: row['batch_priority'] as int? ?? 3,
            argsJson: argsJson,
            schemaVersion: 1,
            status: row['status'] as String? ?? 'pending',
            retryCount: Value(row['retry_count'] as int? ?? 0),
            maxRetries: Value(row['max_retries'] as int? ?? 5),
            createdAt: createdAt,
            lastAttempt: Value(
              DateTime.tryParse(row['last_attempt'] as String? ?? ''),
            ),
            lastError: Value(row['last_error'] as String?),
          ),
        );
      }
    } catch (e) {
      await into(outboxActions).insert(
        OutboxActionsCompanion.insert(
          action: 'update_stop_status',
          priority: 1,
          argsJson: '{}',
          schemaVersion: 3,
          status: 'failed',
          createdAt: DateTime.now().toUtc(),
          lastError: Value('Legacy queue migration failed: $e'),
        ),
      );
      debugPrint('[Drift v3] action_queue seed failed (non-fatal): $e');
    }
  }
}

Future<List<Map<String, Object?>>> _readLegacyQueue() async {
  final dbPath = await sqflite.getDatabasesPath();
  final oldDbPath = p.join(dbPath, 'vosroute.db');
  final oldDb = await sqflite.openDatabase(oldDbPath);
  final pending = await oldDb.query(
    'action_queue',
    where: "status = 'pending' OR status = 'failed'",
  );
  await oldDb.close();
  return pending;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'vosroute_drift.db'));
    final secureStorage = SecureStorageService();
    final passphrase = await secureStorage.getDatabasePassphrase();

    final prefs = await SharedPreferences.getInstance();
    final isEncrypted = prefs.getBool('drift_encrypted') ?? false;

    if (!isEncrypted) {
      if (file.existsSync()) {
        await file.delete();
      }
      await prefs.setBool('drift_encrypted', true);
    }

    return NativeDatabase(
      file,
      setup: (db) {
        db.execute('PRAGMA key = "$passphrase"');
      },
    );
  });
}
