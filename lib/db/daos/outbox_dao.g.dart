// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outbox_dao.dart';

// ignore_for_file: type=lint
mixin _$OutboxDaoMixin on DatabaseAccessor<AppDatabase> {
  $OutboxActionsTable get outboxActions => attachedDatabase.outboxActions;
  OutboxDaoManager get managers => OutboxDaoManager(this);
}

class OutboxDaoManager {
  final _$OutboxDaoMixin _db;
  OutboxDaoManager(this._db);
  $$OutboxActionsTableTableManager get outboxActions =>
      $$OutboxActionsTableTableManager(_db.attachedDatabase, _db.outboxActions);
}
