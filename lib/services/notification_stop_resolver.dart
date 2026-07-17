import '../models/stop.dart';

Object? resolveNotificationStop(Object? rawId, Iterable<Object> stops) {
  final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
  if (id == null) return null;
  final matches = stops.where((stop) {
    return switch (stop) {
      InvoiceStop value => value.id == id || value.invoiceId == id,
      PurchaseStop value => value.id == id || value.poId == id,
      OtherStop value => value.id == id,
      _ => false,
    };
  }).toList();
  return matches.length == 1 ? matches.single : null;
}
