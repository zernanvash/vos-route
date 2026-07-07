class InvoiceStop {
  final int id;
  final int postDispatchPlanId;
  final int invoiceId;
  final String? invoiceNo;
  final String? customerCode;
  final String? customerName;
  final double? amount;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? distance;
  final String status;
  final int sequence;
  final String? remarks;

  InvoiceStop({
    required this.id,
    required this.postDispatchPlanId,
    required this.invoiceId,
    this.invoiceNo,
    this.customerCode,
    this.customerName,
    this.amount,
    this.address,
    this.latitude,
    this.longitude,
    this.distance,
    this.status = 'Pending',
    required this.sequence,
    this.remarks,
  });

  bool get isCompleted => status == 'Fulfilled';
  bool get isTerminal =>
      status == 'Fulfilled' ||
      status == 'Not Fulfilled' ||
      status == 'Fulfilled with Returns' ||
      status == 'Fulfilled with Concerns';

  factory InvoiceStop.fromJson(Map<String, dynamic> json) => InvoiceStop(
    id: json['id'] as int,
    postDispatchPlanId: json['post_dispatch_plan_id'] as int? ?? 0,
    invoiceId: json['invoice_id'] as int? ?? 0,
    invoiceNo: json['invoice_no'] as String?,
    customerCode:
        json['customer_code'] as String? ?? json['customerCode'] as String?,
    customerName: json['customer_name'] as String?,
    amount: (json['amount'] as num?)?.toDouble(),
    address: json['address'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    distance: (json['distance'] as num?)?.toDouble(),
    status: json['status'] as String? ?? 'Pending',
    sequence: json['sequence'] as int? ?? 0,
    remarks: json['remarks'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'post_dispatch_plan_id': postDispatchPlanId,
    'invoice_id': invoiceId,
    'invoice_no': invoiceNo,
    'customer_code': customerCode,
    'customer_name': customerName,
    'amount': amount,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'distance': distance,
    'status': status,
    'sequence': sequence,
    'remarks': remarks,
  };
}

class PurchaseStop {
  final int id;
  final int postDispatchPlanId;
  final int poId;
  final String? poNo;
  final String? supplierName;
  final double? distance;
  final int sequence;
  final String status;

  PurchaseStop({
    required this.id,
    required this.postDispatchPlanId,
    required this.poId,
    this.poNo,
    this.supplierName,
    this.distance,
    required this.sequence,
    this.status = 'Pending',
  });

  factory PurchaseStop.fromJson(Map<String, dynamic> json) => PurchaseStop(
    id: json['id'] as int,
    postDispatchPlanId: json['post_dispatch_plan_id'] as int? ?? 0,
    poId: json['po_id'] as int? ?? 0,
    poNo: json['po_no'] as String?,
    supplierName: json['supplier_name'] as String?,
    distance: (json['distance'] as num?)?.toDouble(),
    sequence: json['sequence'] as int? ?? 0,
    status: json['status'] as String? ?? 'Pending',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'post_dispatch_plan_id': postDispatchPlanId,
    'po_id': poId,
    'po_no': poNo,
    'supplier_name': supplierName,
    'distance': distance,
    'sequence': sequence,
    'status': status,
  };
}

class OtherStop {
  final int id;
  final int postDispatchPlanId;
  final String? remarks;
  final double? distance;
  final double? latitude;
  final double? longitude;
  final int sequence;
  final String status;

  OtherStop({
    required this.id,
    required this.postDispatchPlanId,
    this.remarks,
    this.distance,
    this.latitude,
    this.longitude,
    required this.sequence,
    this.status = 'Pending',
  });

  bool get isTerminal => status == 'Fulfilled' || status == 'Not Fulfilled';

  factory OtherStop.fromJson(Map<String, dynamic> json) => OtherStop(
    id: json['id'] as int,
    postDispatchPlanId: json['post_dispatch_plan_id'] as int? ?? 0,
    remarks: json['remarks'] as String?,
    distance: (json['distance'] as num?)?.toDouble(),
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    sequence: json['sequence'] as int? ?? 0,
    status: json['status'] as String? ?? 'Pending',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'post_dispatch_plan_id': postDispatchPlanId,
    'remarks': remarks,
    'distance': distance,
    'latitude': latitude,
    'longitude': longitude,
    'sequence': sequence,
    'status': status,
  };
}

class StopGroup {
  final String customerCode;
  final String? customerName;
  final double? latitude;
  final double? longitude;
  final List<InvoiceStop> stops;

  StopGroup({
    required this.customerCode,
    this.customerName,
    this.latitude,
    this.longitude,
    required this.stops,
  });

  int get totalStops => stops.length;
  int get fulfilledCount => stops.where((s) => s.status == 'Fulfilled').length;
  int get notFulfilledCount =>
      stops.where((s) => s.status == 'Not Fulfilled').length;
  int get terminalCount => stops.where((s) => s.isTerminal).length;

  bool get allFulfilled => stops.every((s) => s.status == 'Fulfilled');
  bool get allNotFulfilled => stops.every((s) => s.status == 'Not Fulfilled');
  bool get allTerminal => stops.every((s) => s.isTerminal);
  bool get hasMixed => !allFulfilled && !allNotFulfilled && terminalCount > 0;
}
