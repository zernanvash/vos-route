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

@DriftDatabase(tables: [CachedSettings, OutboxActions])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;

  AppDatabase._internal() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedFromActionQueue(m);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(outboxActions);
        await _seedFromActionQueue(m);
      }
    },
  );
}

Future<void> _seedFromActionQueue(Migrator m) async {
  try {
    final dbPath = await sqflite.getDatabasesPath();
    final oldDbPath = p.join(dbPath, 'vosroute.db');
    final oldDb = await sqflite.openDatabase(oldDbPath);
    final pending = await oldDb.query(
      'action_queue',
      where: "status = 'pending' OR status = 'failed'",
    );
    if (pending.isNotEmpty) {
      for (final row in pending) {
        final createdAtMs =
            DateTime.tryParse(
              row['created_at'] as String? ?? '',
            )?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch;
        final lastAttemptMs = row['last_attempt'] != null
            ? DateTime.tryParse(
                row['last_attempt'] as String,
              )?.millisecondsSinceEpoch
            : null;
        await m.database.customStatement(
          'INSERT INTO outbox (action, priority, args_json, schema_version, status, retry_count, max_retries, created_at, last_attempt, last_error) '
          'VALUES (?, ?, ?, 1, ?, ?, ?, ?, ?, ?)',
          [
            row['action_type'],
            row['batch_priority'] ?? 3,
            row['action_payload'],
            row['status'],
            row['retry_count'] ?? 0,
            row['max_retries'] ?? 5,
            createdAtMs,
            lastAttemptMs,
            row['last_error'],
          ],
        );
      }
    }
    await oldDb.close();
  } catch (e) {
    debugPrint('[Drift v2] action_queue seed failed (non-fatal): $e');
  }
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
