import 'package:flutter_test/flutter_test.dart';
import 'package:vosroute/sync/request_builders/update_stop_status_builder.dart';

void main() {
  test('keeps invoice timestamp separate from driver user id', () {
    final request = UpdateStopStatusBuilder.build(
      invoiceId: 42,
      status: 'Fulfilled',
      remarks: 'Received',
      driverUserId: 7,
      invoiceAt: '2026-07-14T03:04:05.000Z',
    );

    expect(request['path'], '/items/post_dispatch_invoices/42');
    expect(request['method'], 'PATCH');
    expect(request['body'], {
      'status': 'Fulfilled',
      'invoiceAt': '2026-07-14T03:04:05.000Z',
      'invoiced_by': 7,
      'remarks': 'Received',
    });
  });
}
