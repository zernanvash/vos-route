# VOSRoute & SCM Implementation Plan — Data Integrity & Timezone Fixes

This implementation plan details the specifications required to resolve the **timezone shift bug** (+8 hours shift) and the **shared invoice double-assignment bug** (mismatch between plans and invoices) across the VOSRoute mobile app and the SCM web backend.

---

## 1. Goal Description

1. **Fix Timezone Shift Bug dynamically:** Ensure all timestamp fields created or updated by the client app are formatted in UTC and carry an explicit `Z` suffix. Instead of relying on device local clock time offsets (which are prone to driver phone configuration errors), the client app will cache the business timezone (`Asia/Manila` by default) from the `general_setting` collection and translate all local clock coordinates to UTC based on that zone.
2. **Fix Double-Assignment Mismatch:** Prevent the same `sales_invoice` from being assigned to multiple active/pending dispatch plans, and ensure invoice statuses and dispatch dates are reset correctly on plan cancellation.
3. **Robust Bit/Boolean Field Unpacking:** Ensure any BFF or backend services reading `isDispatched`, `isPosted`, etc., unpack Node `Buffer` type bits safely.

---

## 2. Proposed Changes (VOSRoute Mobile App)

### 2.1. Drift Table & DAO (Settings Cache)

#### [NEW] [cached_settings_table.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/db/tables/cached_settings_table.dart)
Define the cache table structure inside the Drift schema directory:
```dart
import 'package:drift/drift.dart';

@DataClassName('CachedSetting')
class CachedSettings extends Table {
  TextColumn get settingKey => text().withLength(min: 1, max: 255)();
  TextColumn get settingValue => text().nullable()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {settingKey};
}
```

#### [NEW] [cached_settings_dao.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/db/daos/cached_settings_dao.dart)
Define the DAO accessor:
```dart
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/cached_settings_table.dart';

part 'cached_settings_dao.g.dart';

@DriftAccessor(tables: [CachedSettings])
class CachedSettingsDao extends DatabaseAccessor<AppDatabase> with _$CachedSettingsDaoMixin {
  CachedSettingsDao(AppDatabase db) : super(db);

  Future<CachedSetting?> getSetting(String key) {
    return (select(cachedSettings)..where((t) => t.settingKey.equals(key))).getSingleOrNull();
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
```

---

### 2.2. Timezone Date Formatter

#### [NEW] [utc_date_formatter.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/network/utc_date_formatter.dart)
Create a centralized date formatter using the `timezone` package to map device local clock hours into the business timezone before converting to UTC:
```dart
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class UtcDateFormatter {
  UtcDateFormatter._();

  /// Converts a local device timestamp to UTC by treating the calendar and 
  /// clock values as if they occurred in the business's timezone, returning an ISO 8601 string.
  static String format(DateTime dateTime, String businessTimeZone) {
    try {
      final location = tz.getLocation(businessTimeZone);
      return _formatInLocation(dateTime, location);
    } catch (e) {
      try {
        // Fallback 1: Attempt to use hardcoded business timezone (Asia/Manila)
        final fallbackLocation = tz.getLocation('Asia/Manila');
        return _formatInLocation(dateTime, fallbackLocation);
      } catch (e2) {
        // Fallback 2: Local conversion with warning log
        debugPrint(
          '[UtcDateFormatter] Warning: Failed to load timezone "$businessTimeZone" '
          'and fallback "Asia/Manila". Error: $e2. Using local UTC conversion.',
        );
        final utcDateTime = dateTime.toUtc();
        return '${utcDateTime.toIso8601String().split('.').first}Z';
      }
    }
  }

  static String _formatInLocation(DateTime dateTime, tz.Location location) {
    final tzDateTime = tz.TZDateTime(
      location,
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
    );
    final utcDateTime = tzDateTime.toUtc();
    return '${utcDateTime.toIso8601String().split('.').first}Z';
  }
}
```

---

### 2.3. Timezone Reconciliation Service

#### [MODIFY] [timezone_service.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/services/timezone_service.dart)
Rewrite the service to use the new typed network client `ApiService.get`, handle typed exceptions, and read/write values via `CachedSettingsDao` on the singleton `AppDatabase`:
```dart
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import '../db/app_database.dart';
import '../db/daos/cached_settings_dao.dart';
import '../network/app_exception.dart';
import 'api_service.dart';

class TimezoneService {
  TimezoneService._();
  static final TimezoneService _instance = TimezoneService._();
  factory TimezoneService() => _instance;

  final ApiService _api = ApiService();
  
  // Utilizes the shared singleton AppDatabase instance
  final CachedSettingsDao _settingsDao = CachedSettingsDao(AppDatabase());

  String? _cachedTimezone;
  static const String _defaultTimezone = 'Asia/Manila';
  bool _loaded = false;

  String get timezone => _cachedTimezone ?? _defaultTimezone;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    
    // 1. Initialize timezone database
    tz.initializeTimeZones();

    // 2. Reconcile timezone from server using the typed network primitive
    try {
      final responseMap = await _api.get<Map<String, dynamic>>(
        '/items/general_setting',
        query: {
          'filter[setting_key][_eq]': 'time_zone',
          'limit': '1',
        },
      );
      
      final dataList = responseMap['data'] as List<dynamic>;
      if (dataList.isNotEmpty) {
        final val = dataList.first['setting_value'] as String?;
        if (val != null && val.isNotEmpty) {
          await _settingsDao.saveSetting('time_zone', val);
          _cachedTimezone = val;
        }
      }
    } on NetworkException catch (e) {
      debugPrint('[TimezoneService] Network exception fetching timezone: ${e.message}. Using cache.');
      await _loadFromLocalCache();
    } on ServerException catch (e) {
      debugPrint('[TimezoneService] Server exception fetching timezone (HTTP ${e.statusCode}): ${e.message}. Using cache.');
      await _loadFromLocalCache();
    } on ClientException catch (e) {
      debugPrint('[TimezoneService] Client exception fetching timezone (HTTP ${e.statusCode}): ${e.message}. Using cache.');
      await _loadFromLocalCache();
    } catch (e) {
      debugPrint('[TimezoneService] Unexpected exception fetching timezone: $e. Using cache.');
      await _loadFromLocalCache();
    }
    _loaded = true;
  }

  Future<void> _loadFromLocalCache() async {
    try {
      final localSetting = await _settingsDao.getSetting('time_zone');
      if (localSetting != null && localSetting.settingValue != null) {
        _cachedTimezone = localSetting.settingValue;
      }
    } catch (e) {
      debugPrint('[TimezoneService] Failed to read from local settings cache: $e');
    }
  }
}
```

---

### 2.4. Centralized Request Builder Example

#### [NEW] [update_stop_status_builder.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/sync/request_builders/update_stop_status_builder.dart)
All builders that format date payloads call `UtcDateFormatter.format`. The stop status update builder maps both camelCase and snake_case date field name variants:
```dart
import '../../network/utc_date_formatter.dart';

class UpdateStopStatusBuilder {
  static Map<String, dynamic> build({
    required int invoiceId,
    required String status,
    required String? remarks,
    required DateTime eventTime,
    required String businessTimeZone,
    required int? driverUserId,
  }) {
    final nowFormatted = UtcDateFormatter.format(eventTime, businessTimeZone);
    
    return {
      'path': '/items/post_dispatch_invoices/$invoiceId',
      'method': 'PATCH',
      'body': {
        'status': status,
        'invoiceAt': nowFormatted,      // Main field (camelCase)
        'invoice_at': nowFormatted,     // Duplicate variant (snake_case)
        'invoiced_by': driverUserId,    // Map driver user ID separately
        'remarks': remarks,
      }
    };
  }
}
```

---

### 2.5. Bootstrap Setup

#### [MODIFY] [main.dart](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/lib/main.dart)
Wait on `AppDatabase` initialization, `ApiService` configurations, and `TimezoneService.load()` in order, prior to executing `runApp`:
```diff
 void main() async {
   WidgetsFlutterBinding.ensureInitialized();
   SystemChrome.setPreferredOrientations([
     DeviceOrientation.portraitUp,
     DeviceOrientation.portraitDown,
   ]);
   try {
     await Firebase.initializeApp();
   } catch (e) {
     debugPrint('Firebase initialization failed: $e');
   }
+  
+  // 1. Initialize DB singleton and run migrations
+  final db = AppDatabase();
+  await db.executor.ensureOpen(db);
+
+  // 2. Initialize api client primitives
   await ApiService().init();
+
+  // 3. Load business settings cache (reconciles or falls back safely)
   await TimezoneService().load();
+
   runApp(const VOSRouteApp());
 }
```

---

### 2.6. Package Dependencies

#### [MODIFY] [pubspec.yaml](file:///c:/Users/HP/Desktop/Code/vertextech/ResearchDEPT/VOSRoute/pubspec.yaml)
Add `timezone` under the dependencies section:
```yaml
dependencies:
  flutter:
    sdk: flutter
  timezone: ^0.10.1
```

---

## 3. Proposed Changes (SCM Web BFF)

### 3.1. Shared Invoices & Double-Assignment Fix

#### [MODIFY] Invoice Query Filters in SCM Web BFF
To prevent unassigned invoices from listing invoices that are already associated with another active/pending plan, update the SCM dispatch plan creation logic (typically located in the SCM pre-dispatch plan module):
1. **Fetch Assigned Invoice IDs:** Query `post_dispatch_invoices` for all records where the plan's status is `For Dispatch`, `For Inbound`, or `For Clearance`.
2. **Filter Out Assigned Invoices:** When querying unassigned invoices for new plan creation, add a filter to exclude these retrieved `invoice_id`s:
   ```typescript
   // Example SCM BFF query filter logic
   const activePlansRes = await fetchDirectus('/items/post_dispatch_plan', {
     filter: { status: { _in: ['For Dispatch', 'For Inbound', 'For Clearance'] } },
     fields: 'id'
   });
   const activePlanIds = activePlansRes.data.map(p => p.id);
   
   const assignedInvoicesRes = await fetchDirectus('/items/post_dispatch_invoices', {
     filter: { post_dispatch_plan_id: { _in: activePlanIds } },
     fields: 'invoice_id'
   });
   const assignedInvoiceIds = assignedInvoicesRes.data.map(pdi => pdi.invoice_id);
   
   // Apply exclusion filter to unassigned invoice lists:
   const unassignedFilter = {
     invoice_id: { _nin: assignedInvoiceIds }
   };
   ```

#### [MODIFY] Plan Cancellation Reset Logic
Update the dispatch plan cancellation hook/service inside the SCM backend:
* When a dispatch plan's status transitions to `Cancelled`, query all linked invoices in `post_dispatch_invoices`.
* Reset `transaction_status` to `Prepared` (or their pre-dispatch state), set `isDispatched` to `0`, and set `dispatch_date` to `null` on the `sales_invoice` records to free them up.

### 3.2. MySQL/Directus Buffer Field Handler

#### [ADD] Helper inside SCM Web Backend
Ensure boolean properties from Directus (which MySQL returns as binary bits and Node translates to `Buffer` objects) are safely unpacked:
```typescript
/**
 * Unpacks bit/tinyint columns (like isDispatched, isPosted) that Node/Directus return as Buffer objects.
 */
export function unpackBitField(value: any): boolean {
  if (value && typeof value === 'object' && value.type === 'Buffer' && Array.isArray(value.data)) {
    return value.data[0] === 1;
  }
  return value === 1 || value === true;
}
```
* Integrate this utility whenever reading `isDispatched`, `isPosted`, `isReceipt`, or `isRemitted` from `sales_invoice` query results.

---

## 4. Verification Plan

### Automated Verification
- Run `flutter analyze` inside `VOSRoute` to verify compile safety of modified providers/services.

### Manual Database Audit
1. Dispatch a plan in VOSRoute and verify that `time_of_dispatch`, `dispatch_date`, and `invoiceAt` are stored with the `Z` suffix.
2. In SCM Web, verify that already-dispatched or en-route invoices no longer appear as selectable options in the unassigned invoices selector for new plans.
3. Cancel a dispatch plan and assert that its invoices are reset to `isDispatched = 0` and `dispatch_date = null`.

---

## 5. Post-Merge Verification / Follow-Up Tickets

> [!IMPORTANT]
> The following verification items are deferred as follow-up tickets to be resolved post-merge:
> 1. **Confirm `AppDatabase` Singleton Pattern:** Verify that the `AppDatabase` constructor inside `lib/db/app_database.dart` is a true singleton (e.g. factory constructor returning a cached instance), avoiding multiple connections to the same database file.
> 2. **Verify `ApiService.get<T>()` Primitive Return Type:** Ensure the generic getter primitive in the network layer returns the raw Directus JSON envelope (`{data: [...]}`) as expected by `TimezoneService`.
> 3. **Log Unexpected Setting Load Failures:** Route the catch-all `catch (e)` block inside `TimezoneService.load()` to the central `Sync Log` database table or crash reporter rather than `debugPrint` only, preventing silent auth/network failure modes.
