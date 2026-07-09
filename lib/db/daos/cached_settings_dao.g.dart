// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_settings_dao.dart';

// ignore_for_file: type=lint
mixin _$CachedSettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CachedSettingsTable get cachedSettings => attachedDatabase.cachedSettings;
  CachedSettingsDaoManager get managers => CachedSettingsDaoManager(this);
}

class CachedSettingsDaoManager {
  final _$CachedSettingsDaoMixin _db;
  CachedSettingsDaoManager(this._db);
  $$CachedSettingsTableTableManager get cachedSettings =>
      $$CachedSettingsTableTableManager(
        _db.attachedDatabase,
        _db.cachedSettings,
      );
}
