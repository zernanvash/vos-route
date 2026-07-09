import 'package:drift/drift.dart';

@DataClassName('CachedSetting')
class CachedSettings extends Table {
  TextColumn get settingKey => text().withLength(min: 1, max: 255)();
  TextColumn get settingValue => text().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {settingKey};
}
