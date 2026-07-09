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
