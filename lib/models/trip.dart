class PostDispatchPlan {
  final int id;
  final String docNo;
  final int driverId;
  final int vehicleId;
  final String status;
  final String? startingPoint;
  final double? totalDistance;
  final double? amount;
  final DateTime? estimatedTimeOfDispatch;
  final DateTime? estimatedTimeOfArrival;
  final DateTime? timeOfDispatch;
  final DateTime? timeOfArrival;
  final DateTime dateEncoded;
  final String? remarks;
  final Vehicle? vehicle;
  final List<CrewMember> crew;
  final List<BudgetLine> budget;

  PostDispatchPlan({
    required this.id,
    required this.docNo,
    required this.driverId,
    required this.vehicleId,
    required this.status,
    this.startingPoint,
    this.totalDistance,
    this.amount,
    this.estimatedTimeOfDispatch,
    this.estimatedTimeOfArrival,
    this.timeOfDispatch,
    this.timeOfArrival,
    required this.dateEncoded,
    this.remarks,
    this.vehicle,
    this.crew = const [],
    this.budget = const [],
  });

  bool get isForDispatch => status == 'For Dispatch';
  bool get isForInbound => status == 'For Inbound';
  bool get isActive => status == 'For Dispatch' || status == 'For Inbound';

  factory PostDispatchPlan.fromJson(Map<String, dynamic> json) {
    final vehicleIdRaw = json['vehicle_id'];
    final int parsedVehicleId;
    final Vehicle? parsedVehicle;
    if (vehicleIdRaw is Map<String, dynamic>) {
      parsedVehicle = Vehicle.fromJson(vehicleIdRaw);
      parsedVehicleId = parsedVehicle.vehicleId;
    } else {
      parsedVehicleId = (vehicleIdRaw as num?)?.toInt() ?? 0;
      parsedVehicle = json['vehicle'] != null
          ? Vehicle.fromJson(json['vehicle'] as Map<String, dynamic>)
          : null;
    }

    return PostDispatchPlan(
      id: json['id'] as int,
      docNo: json['doc_no'] as String? ?? '',
      driverId: json['driver_id'] as int? ?? 0,
      vehicleId: parsedVehicleId,
      status: json['status'] as String? ?? '',
      startingPoint: json['starting_point']?.toString(),
      totalDistance: (json['total_distance'] as num?)?.toDouble(),
      amount: (json['amount'] as num?)?.toDouble(),
      estimatedTimeOfDispatch: json['estimated_time_of_dispatch'] != null
          ? DateTime.tryParse(json['estimated_time_of_dispatch'] as String)
          : null,
      estimatedTimeOfArrival: json['estimated_time_of_arrival'] != null
          ? DateTime.tryParse(json['estimated_time_of_arrival'] as String)
          : null,
      timeOfDispatch: json['time_of_dispatch'] != null
          ? DateTime.tryParse(json['time_of_dispatch'] as String)
          : null,
      timeOfArrival: json['time_of_arrival'] != null
          ? DateTime.tryParse(json['time_of_arrival'] as String)
          : null,
      dateEncoded:
          DateTime.tryParse(json['date_encoded'] as String? ?? '') ??
          DateTime.now(),
      remarks: json['remarks'] as String?,
      vehicle: parsedVehicle,
      crew:
          (json['crew'] as List<dynamic>?)
              ?.map((e) => CrewMember.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      budget:
          (json['budget'] as List<dynamic>?)
              ?.map((e) => BudgetLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'doc_no': docNo,
    'driver_id': driverId,
    'vehicle_id': vehicleId,
    'status': status,
    'starting_point': startingPoint,
    'total_distance': totalDistance,
    'amount': amount,
    'estimated_time_of_dispatch': estimatedTimeOfDispatch?.toIso8601String(),
    'estimated_time_of_arrival': estimatedTimeOfArrival?.toIso8601String(),
    'time_of_dispatch': timeOfDispatch?.toIso8601String(),
    'time_of_arrival': timeOfArrival?.toIso8601String(),
    'date_encoded': dateEncoded.toIso8601String(),
    'remarks': remarks,
  };
}

class Vehicle {
  final int vehicleId;
  final String vehiclePlate;
  final String? name;

  Vehicle({required this.vehicleId, required this.vehiclePlate, this.name});

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    vehicleId: json['vehicle_id'] as int,
    vehiclePlate: json['vehicle_plate'] as String? ?? '',
    name: json['name'] as String?,
  );
}

class CrewMember {
  final int userId;
  final String? name;
  final String role;

  CrewMember({required this.userId, this.name, required this.role});

  factory CrewMember.fromJson(Map<String, dynamic> json) => CrewMember(
    userId: (json['user_id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String?,
    role: json['role'] as String? ?? 'helper',
  );
}

class BudgetLine {
  final int id;
  final String? coaName;
  final double amount;
  final String? remarks;

  BudgetLine({
    required this.id,
    this.coaName,
    required this.amount,
    this.remarks,
  });

  factory BudgetLine.fromJson(Map<String, dynamic> json) => BudgetLine(
    id: json['id'] as int,
    coaName: json['coa_name'] as String?,
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    remarks: json['remarks'] as String?,
  );
}
