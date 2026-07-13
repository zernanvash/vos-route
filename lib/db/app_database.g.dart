// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedSettingsTable extends CachedSettings
    with TableInfo<$CachedSettingsTable, CachedSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _settingKeyMeta = const VerificationMeta(
    'settingKey',
  );
  @override
  late final GeneratedColumn<String> settingKey = GeneratedColumn<String>(
    'setting_key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 255,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _settingValueMeta = const VerificationMeta(
    'settingValue',
  );
  @override
  late final GeneratedColumn<String> settingValue = GeneratedColumn<String>(
    'setting_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    settingKey,
    settingValue,
    lastSyncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('setting_key')) {
      context.handle(
        _settingKeyMeta,
        settingKey.isAcceptableOrUnknown(data['setting_key']!, _settingKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_settingKeyMeta);
    }
    if (data.containsKey('setting_value')) {
      context.handle(
        _settingValueMeta,
        settingValue.isAcceptableOrUnknown(
          data['setting_value']!,
          _settingValueMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {settingKey};
  @override
  CachedSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedSetting(
      settingKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setting_key'],
      )!,
      settingValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setting_value'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
    );
  }

  @override
  $CachedSettingsTable createAlias(String alias) {
    return $CachedSettingsTable(attachedDatabase, alias);
  }
}

class CachedSetting extends DataClass implements Insertable<CachedSetting> {
  final String settingKey;
  final String? settingValue;
  final DateTime? lastSyncedAt;
  const CachedSetting({
    required this.settingKey,
    this.settingValue,
    this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['setting_key'] = Variable<String>(settingKey);
    if (!nullToAbsent || settingValue != null) {
      map['setting_value'] = Variable<String>(settingValue);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  CachedSettingsCompanion toCompanion(bool nullToAbsent) {
    return CachedSettingsCompanion(
      settingKey: Value(settingKey),
      settingValue: settingValue == null && nullToAbsent
          ? const Value.absent()
          : Value(settingValue),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory CachedSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedSetting(
      settingKey: serializer.fromJson<String>(json['settingKey']),
      settingValue: serializer.fromJson<String?>(json['settingValue']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'settingKey': serializer.toJson<String>(settingKey),
      'settingValue': serializer.toJson<String?>(settingValue),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  CachedSetting copyWith({
    String? settingKey,
    Value<String?> settingValue = const Value.absent(),
    Value<DateTime?> lastSyncedAt = const Value.absent(),
  }) => CachedSetting(
    settingKey: settingKey ?? this.settingKey,
    settingValue: settingValue.present ? settingValue.value : this.settingValue,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
  );
  CachedSetting copyWithCompanion(CachedSettingsCompanion data) {
    return CachedSetting(
      settingKey: data.settingKey.present
          ? data.settingKey.value
          : this.settingKey,
      settingValue: data.settingValue.present
          ? data.settingValue.value
          : this.settingValue,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedSetting(')
          ..write('settingKey: $settingKey, ')
          ..write('settingValue: $settingValue, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(settingKey, settingValue, lastSyncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedSetting &&
          other.settingKey == this.settingKey &&
          other.settingValue == this.settingValue &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class CachedSettingsCompanion extends UpdateCompanion<CachedSetting> {
  final Value<String> settingKey;
  final Value<String?> settingValue;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> rowid;
  const CachedSettingsCompanion({
    this.settingKey = const Value.absent(),
    this.settingValue = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedSettingsCompanion.insert({
    required String settingKey,
    this.settingValue = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : settingKey = Value(settingKey);
  static Insertable<CachedSetting> custom({
    Expression<String>? settingKey,
    Expression<String>? settingValue,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (settingKey != null) 'setting_key': settingKey,
      if (settingValue != null) 'setting_value': settingValue,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedSettingsCompanion copyWith({
    Value<String>? settingKey,
    Value<String?>? settingValue,
    Value<DateTime?>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return CachedSettingsCompanion(
      settingKey: settingKey ?? this.settingKey,
      settingValue: settingValue ?? this.settingValue,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (settingKey.present) {
      map['setting_key'] = Variable<String>(settingKey.value);
    }
    if (settingValue.present) {
      map['setting_value'] = Variable<String>(settingValue.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedSettingsCompanion(')
          ..write('settingKey: $settingKey, ')
          ..write('settingValue: $settingValue, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxActionsTable extends OutboxActions
    with TableInfo<$OutboxActionsTable, OutboxAction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dependsOnMeta = const VerificationMeta(
    'dependsOn',
  );
  @override
  late final GeneratedColumn<int> dependsOn = GeneratedColumn<int>(
    'depends_on',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _argsJsonMeta = const VerificationMeta(
    'argsJson',
  );
  @override
  late final GeneratedColumn<String> argsJson = GeneratedColumn<String>(
    'args_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxRetriesMeta = const VerificationMeta(
    'maxRetries',
  );
  @override
  late final GeneratedColumn<int> maxRetries = GeneratedColumn<int>(
    'max_retries',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAttemptMeta = const VerificationMeta(
    'lastAttempt',
  );
  @override
  late final GeneratedColumn<DateTime> lastAttempt = GeneratedColumn<DateTime>(
    'last_attempt',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    action,
    priority,
    dependsOn,
    argsJson,
    schemaVersion,
    status,
    retryCount,
    maxRetries,
    createdAt,
    lastAttempt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_actions';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxAction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('depends_on')) {
      context.handle(
        _dependsOnMeta,
        dependsOn.isAcceptableOrUnknown(data['depends_on']!, _dependsOnMeta),
      );
    }
    if (data.containsKey('args_json')) {
      context.handle(
        _argsJsonMeta,
        argsJson.isAcceptableOrUnknown(data['args_json']!, _argsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_argsJsonMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('max_retries')) {
      context.handle(
        _maxRetriesMeta,
        maxRetries.isAcceptableOrUnknown(data['max_retries']!, _maxRetriesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_attempt')) {
      context.handle(
        _lastAttemptMeta,
        lastAttempt.isAcceptableOrUnknown(
          data['last_attempt']!,
          _lastAttemptMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxAction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxAction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      dependsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}depends_on'],
      ),
      argsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}args_json'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      maxRetries: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_retries'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastAttempt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_attempt'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $OutboxActionsTable createAlias(String alias) {
    return $OutboxActionsTable(attachedDatabase, alias);
  }
}

class OutboxAction extends DataClass implements Insertable<OutboxAction> {
  final int id;
  final String action;
  final int priority;
  final int? dependsOn;
  final String argsJson;
  final int schemaVersion;
  final String status;
  final int retryCount;
  final int maxRetries;
  final DateTime createdAt;
  final DateTime? lastAttempt;
  final String? lastError;
  const OutboxAction({
    required this.id,
    required this.action,
    required this.priority,
    this.dependsOn,
    required this.argsJson,
    required this.schemaVersion,
    required this.status,
    required this.retryCount,
    required this.maxRetries,
    required this.createdAt,
    this.lastAttempt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['action'] = Variable<String>(action);
    map['priority'] = Variable<int>(priority);
    if (!nullToAbsent || dependsOn != null) {
      map['depends_on'] = Variable<int>(dependsOn);
    }
    map['args_json'] = Variable<String>(argsJson);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    map['max_retries'] = Variable<int>(maxRetries);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastAttempt != null) {
      map['last_attempt'] = Variable<DateTime>(lastAttempt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OutboxActionsCompanion toCompanion(bool nullToAbsent) {
    return OutboxActionsCompanion(
      id: Value(id),
      action: Value(action),
      priority: Value(priority),
      dependsOn: dependsOn == null && nullToAbsent
          ? const Value.absent()
          : Value(dependsOn),
      argsJson: Value(argsJson),
      schemaVersion: Value(schemaVersion),
      status: Value(status),
      retryCount: Value(retryCount),
      maxRetries: Value(maxRetries),
      createdAt: Value(createdAt),
      lastAttempt: lastAttempt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttempt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OutboxAction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxAction(
      id: serializer.fromJson<int>(json['id']),
      action: serializer.fromJson<String>(json['action']),
      priority: serializer.fromJson<int>(json['priority']),
      dependsOn: serializer.fromJson<int?>(json['dependsOn']),
      argsJson: serializer.fromJson<String>(json['argsJson']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      maxRetries: serializer.fromJson<int>(json['maxRetries']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAttempt: serializer.fromJson<DateTime?>(json['lastAttempt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'action': serializer.toJson<String>(action),
      'priority': serializer.toJson<int>(priority),
      'dependsOn': serializer.toJson<int?>(dependsOn),
      'argsJson': serializer.toJson<String>(argsJson),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'maxRetries': serializer.toJson<int>(maxRetries),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAttempt': serializer.toJson<DateTime?>(lastAttempt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OutboxAction copyWith({
    int? id,
    String? action,
    int? priority,
    Value<int?> dependsOn = const Value.absent(),
    String? argsJson,
    int? schemaVersion,
    String? status,
    int? retryCount,
    int? maxRetries,
    DateTime? createdAt,
    Value<DateTime?> lastAttempt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => OutboxAction(
    id: id ?? this.id,
    action: action ?? this.action,
    priority: priority ?? this.priority,
    dependsOn: dependsOn.present ? dependsOn.value : this.dependsOn,
    argsJson: argsJson ?? this.argsJson,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    maxRetries: maxRetries ?? this.maxRetries,
    createdAt: createdAt ?? this.createdAt,
    lastAttempt: lastAttempt.present ? lastAttempt.value : this.lastAttempt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OutboxAction copyWithCompanion(OutboxActionsCompanion data) {
    return OutboxAction(
      id: data.id.present ? data.id.value : this.id,
      action: data.action.present ? data.action.value : this.action,
      priority: data.priority.present ? data.priority.value : this.priority,
      dependsOn: data.dependsOn.present ? data.dependsOn.value : this.dependsOn,
      argsJson: data.argsJson.present ? data.argsJson.value : this.argsJson,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      maxRetries: data.maxRetries.present
          ? data.maxRetries.value
          : this.maxRetries,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAttempt: data.lastAttempt.present
          ? data.lastAttempt.value
          : this.lastAttempt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxAction(')
          ..write('id: $id, ')
          ..write('action: $action, ')
          ..write('priority: $priority, ')
          ..write('dependsOn: $dependsOn, ')
          ..write('argsJson: $argsJson, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('maxRetries: $maxRetries, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttempt: $lastAttempt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    action,
    priority,
    dependsOn,
    argsJson,
    schemaVersion,
    status,
    retryCount,
    maxRetries,
    createdAt,
    lastAttempt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxAction &&
          other.id == this.id &&
          other.action == this.action &&
          other.priority == this.priority &&
          other.dependsOn == this.dependsOn &&
          other.argsJson == this.argsJson &&
          other.schemaVersion == this.schemaVersion &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.maxRetries == this.maxRetries &&
          other.createdAt == this.createdAt &&
          other.lastAttempt == this.lastAttempt &&
          other.lastError == this.lastError);
}

class OutboxActionsCompanion extends UpdateCompanion<OutboxAction> {
  final Value<int> id;
  final Value<String> action;
  final Value<int> priority;
  final Value<int?> dependsOn;
  final Value<String> argsJson;
  final Value<int> schemaVersion;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<int> maxRetries;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastAttempt;
  final Value<String?> lastError;
  const OutboxActionsCompanion({
    this.id = const Value.absent(),
    this.action = const Value.absent(),
    this.priority = const Value.absent(),
    this.dependsOn = const Value.absent(),
    this.argsJson = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.maxRetries = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAttempt = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  OutboxActionsCompanion.insert({
    this.id = const Value.absent(),
    required String action,
    required int priority,
    this.dependsOn = const Value.absent(),
    required String argsJson,
    required int schemaVersion,
    required String status,
    this.retryCount = const Value.absent(),
    this.maxRetries = const Value.absent(),
    required DateTime createdAt,
    this.lastAttempt = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : action = Value(action),
       priority = Value(priority),
       argsJson = Value(argsJson),
       schemaVersion = Value(schemaVersion),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<OutboxAction> custom({
    Expression<int>? id,
    Expression<String>? action,
    Expression<int>? priority,
    Expression<int>? dependsOn,
    Expression<String>? argsJson,
    Expression<int>? schemaVersion,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<int>? maxRetries,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAttempt,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (action != null) 'action': action,
      if (priority != null) 'priority': priority,
      if (dependsOn != null) 'depends_on': dependsOn,
      if (argsJson != null) 'args_json': argsJson,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (maxRetries != null) 'max_retries': maxRetries,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAttempt != null) 'last_attempt': lastAttempt,
      if (lastError != null) 'last_error': lastError,
    });
  }

  OutboxActionsCompanion copyWith({
    Value<int>? id,
    Value<String>? action,
    Value<int>? priority,
    Value<int?>? dependsOn,
    Value<String>? argsJson,
    Value<int>? schemaVersion,
    Value<String>? status,
    Value<int>? retryCount,
    Value<int>? maxRetries,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastAttempt,
    Value<String?>? lastError,
  }) {
    return OutboxActionsCompanion(
      id: id ?? this.id,
      action: action ?? this.action,
      priority: priority ?? this.priority,
      dependsOn: dependsOn ?? this.dependsOn,
      argsJson: argsJson ?? this.argsJson,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      createdAt: createdAt ?? this.createdAt,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (dependsOn.present) {
      map['depends_on'] = Variable<int>(dependsOn.value);
    }
    if (argsJson.present) {
      map['args_json'] = Variable<String>(argsJson.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (maxRetries.present) {
      map['max_retries'] = Variable<int>(maxRetries.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAttempt.present) {
      map['last_attempt'] = Variable<DateTime>(lastAttempt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxActionsCompanion(')
          ..write('id: $id, ')
          ..write('action: $action, ')
          ..write('priority: $priority, ')
          ..write('dependsOn: $dependsOn, ')
          ..write('argsJson: $argsJson, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('maxRetries: $maxRetries, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttempt: $lastAttempt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedSettingsTable cachedSettings = $CachedSettingsTable(this);
  late final $OutboxActionsTable outboxActions = $OutboxActionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedSettings,
    outboxActions,
  ];
}

typedef $$CachedSettingsTableCreateCompanionBuilder =
    CachedSettingsCompanion Function({
      required String settingKey,
      Value<String?> settingValue,
      Value<DateTime?> lastSyncedAt,
      Value<int> rowid,
    });
typedef $$CachedSettingsTableUpdateCompanionBuilder =
    CachedSettingsCompanion Function({
      Value<String> settingKey,
      Value<String?> settingValue,
      Value<DateTime?> lastSyncedAt,
      Value<int> rowid,
    });

class $$CachedSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedSettingsTable> {
  $$CachedSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedSettingsTable> {
  $$CachedSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedSettingsTable> {
  $$CachedSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$CachedSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedSettingsTable,
          CachedSetting,
          $$CachedSettingsTableFilterComposer,
          $$CachedSettingsTableOrderingComposer,
          $$CachedSettingsTableAnnotationComposer,
          $$CachedSettingsTableCreateCompanionBuilder,
          $$CachedSettingsTableUpdateCompanionBuilder,
          (
            CachedSetting,
            BaseReferences<_$AppDatabase, $CachedSettingsTable, CachedSetting>,
          ),
          CachedSetting,
          PrefetchHooks Function()
        > {
  $$CachedSettingsTableTableManager(
    _$AppDatabase db,
    $CachedSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> settingKey = const Value.absent(),
                Value<String?> settingValue = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedSettingsCompanion(
                settingKey: settingKey,
                settingValue: settingValue,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String settingKey,
                Value<String?> settingValue = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedSettingsCompanion.insert(
                settingKey: settingKey,
                settingValue: settingValue,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedSettingsTable,
      CachedSetting,
      $$CachedSettingsTableFilterComposer,
      $$CachedSettingsTableOrderingComposer,
      $$CachedSettingsTableAnnotationComposer,
      $$CachedSettingsTableCreateCompanionBuilder,
      $$CachedSettingsTableUpdateCompanionBuilder,
      (
        CachedSetting,
        BaseReferences<_$AppDatabase, $CachedSettingsTable, CachedSetting>,
      ),
      CachedSetting,
      PrefetchHooks Function()
    >;
typedef $$OutboxActionsTableCreateCompanionBuilder =
    OutboxActionsCompanion Function({
      Value<int> id,
      required String action,
      required int priority,
      Value<int?> dependsOn,
      required String argsJson,
      required int schemaVersion,
      required String status,
      Value<int> retryCount,
      Value<int> maxRetries,
      required DateTime createdAt,
      Value<DateTime?> lastAttempt,
      Value<String?> lastError,
    });
typedef $$OutboxActionsTableUpdateCompanionBuilder =
    OutboxActionsCompanion Function({
      Value<int> id,
      Value<String> action,
      Value<int> priority,
      Value<int?> dependsOn,
      Value<String> argsJson,
      Value<int> schemaVersion,
      Value<String> status,
      Value<int> retryCount,
      Value<int> maxRetries,
      Value<DateTime> createdAt,
      Value<DateTime?> lastAttempt,
      Value<String?> lastError,
    });

class $$OutboxActionsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxActionsTable> {
  $$OutboxActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dependsOn => $composableBuilder(
    column: $table.dependsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get argsJson => $composableBuilder(
    column: $table.argsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxRetries => $composableBuilder(
    column: $table.maxRetries,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAttempt => $composableBuilder(
    column: $table.lastAttempt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxActionsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxActionsTable> {
  $$OutboxActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dependsOn => $composableBuilder(
    column: $table.dependsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get argsJson => $composableBuilder(
    column: $table.argsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxRetries => $composableBuilder(
    column: $table.maxRetries,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAttempt => $composableBuilder(
    column: $table.lastAttempt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxActionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxActionsTable> {
  $$OutboxActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get dependsOn =>
      $composableBuilder(column: $table.dependsOn, builder: (column) => column);

  GeneratedColumn<String> get argsJson =>
      $composableBuilder(column: $table.argsJson, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxRetries => $composableBuilder(
    column: $table.maxRetries,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttempt => $composableBuilder(
    column: $table.lastAttempt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OutboxActionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxActionsTable,
          OutboxAction,
          $$OutboxActionsTableFilterComposer,
          $$OutboxActionsTableOrderingComposer,
          $$OutboxActionsTableAnnotationComposer,
          $$OutboxActionsTableCreateCompanionBuilder,
          $$OutboxActionsTableUpdateCompanionBuilder,
          (
            OutboxAction,
            BaseReferences<_$AppDatabase, $OutboxActionsTable, OutboxAction>,
          ),
          OutboxAction,
          PrefetchHooks Function()
        > {
  $$OutboxActionsTableTableManager(_$AppDatabase db, $OutboxActionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxActionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int?> dependsOn = const Value.absent(),
                Value<String> argsJson = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int> maxRetries = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastAttempt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxActionsCompanion(
                id: id,
                action: action,
                priority: priority,
                dependsOn: dependsOn,
                argsJson: argsJson,
                schemaVersion: schemaVersion,
                status: status,
                retryCount: retryCount,
                maxRetries: maxRetries,
                createdAt: createdAt,
                lastAttempt: lastAttempt,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String action,
                required int priority,
                Value<int?> dependsOn = const Value.absent(),
                required String argsJson,
                required int schemaVersion,
                required String status,
                Value<int> retryCount = const Value.absent(),
                Value<int> maxRetries = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> lastAttempt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => OutboxActionsCompanion.insert(
                id: id,
                action: action,
                priority: priority,
                dependsOn: dependsOn,
                argsJson: argsJson,
                schemaVersion: schemaVersion,
                status: status,
                retryCount: retryCount,
                maxRetries: maxRetries,
                createdAt: createdAt,
                lastAttempt: lastAttempt,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxActionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxActionsTable,
      OutboxAction,
      $$OutboxActionsTableFilterComposer,
      $$OutboxActionsTableOrderingComposer,
      $$OutboxActionsTableAnnotationComposer,
      $$OutboxActionsTableCreateCompanionBuilder,
      $$OutboxActionsTableUpdateCompanionBuilder,
      (
        OutboxAction,
        BaseReferences<_$AppDatabase, $OutboxActionsTable, OutboxAction>,
      ),
      OutboxAction,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedSettingsTableTableManager get cachedSettings =>
      $$CachedSettingsTableTableManager(_db, _db.cachedSettings);
  $$OutboxActionsTableTableManager get outboxActions =>
      $$OutboxActionsTableTableManager(_db, _db.outboxActions);
}
