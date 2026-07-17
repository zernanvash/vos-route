import 'package:flutter_test/flutter_test.dart';
import 'package:vosroute/models/stop.dart';
import 'package:vosroute/services/notification_stop_resolver.dart';

InvoiceStop invoice(int id, int invoiceId) => InvoiceStop(
  id: id,
  invoiceId: invoiceId,
  postDispatchPlanId: 1,
  sequence: 1,
);

void main() {
  test('resolves a unique numeric or string identifier', () {
    final stop = invoice(10, 99);
    expect(resolveNotificationStop('10', [stop]), same(stop));
    expect(resolveNotificationStop(99, [stop]), same(stop));
  });

  test('returns null for missing and malformed identifiers', () {
    expect(resolveNotificationStop(null, [invoice(1, 2)]), isNull);
    expect(resolveNotificationStop('bad', [invoice(1, 2)]), isNull);
    expect(resolveNotificationStop(404, [invoice(1, 2)]), isNull);
  });

  test('returns null when identifier is ambiguous', () {
    expect(
      resolveNotificationStop(7, [invoice(7, 20), invoice(30, 7)]),
      isNull,
    );
  });
}
