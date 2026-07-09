import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import '../db/app_database.dart';
import '../db/daos/cached_settings_dao.dart';
import '../network/app_exception.dart';
import '../network/utc_date_formatter.dart';
import 'api_service.dart';

class TimezoneService {
  TimezoneService._();
  static final TimezoneService _instance = TimezoneService._();
  factory TimezoneService() => _instance;

  final ApiService _api = ApiService();
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
      final responseMap = await _api.getDirectusGeneric<Map<String, dynamic>>(
        '/items/general_setting',
        queryParams: {
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

  String formatNow() {
    return formatIso8601(DateTime.now());
  }

  static String formatIso8601(DateTime dateTime) {
    return UtcDateFormatter.format(dateTime, TimezoneService().timezone);
  }
}
