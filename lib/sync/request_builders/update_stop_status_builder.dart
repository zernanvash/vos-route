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
