import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/cached_settings_table.dart';

part 'cached_settings_dao.g.dart';

@DriftAccessor(tables: [CachedSettings])
class CachedSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$CachedSettingsDaoMixin {
  CachedSettingsDao(super.db);

  Future<CachedSetting?> getSetting(String key) {
    return (select(
      cachedSettings,
    )..where((t) => t.settingKey.equals(key))).getSingleOrNull();
  }

  Future<void> saveSetting(String key, String value) {
    return into(cachedSettings).insertOnConflictUpdate(
      CachedSetting(
        settingKey: key,
        settingValue: value,
        lastSyncedAt: DateTime.now().toUtc(),
      ),
    );
  }
}
