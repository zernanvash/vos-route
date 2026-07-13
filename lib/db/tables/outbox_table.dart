import 'package:drift/drift.dart';

@DataClassName('OutboxAction')
class OutboxActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get action => text()();
  IntColumn get priority => integer()();
  IntColumn get dependsOn => integer().nullable()();
  TextColumn get argsJson => text()();
  IntColumn get schemaVersion => integer()();
  TextColumn get status => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get maxRetries => integer().withDefault(const Constant(5))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAttempt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
}
