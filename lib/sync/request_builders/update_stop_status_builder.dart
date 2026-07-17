class UpdateStopStatusBuilder {
  static Map<String, dynamic> build({
    required int invoiceId,
    required String status,
    required String? remarks,
    required int? driverUserId,
    required String invoiceAt,
  }) {
    return {
      'path': '/items/post_dispatch_invoices/$invoiceId',
      'method': 'PATCH',
      'body': {
        'status': status,
        'invoiceAt': invoiceAt,
        'invoiced_by': driverUserId,
        'remarks': remarks,
      },
    };
  }
}
