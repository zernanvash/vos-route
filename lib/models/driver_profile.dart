class DriverProfile {
  final int userId;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? contact;
  final int? vehicleId;
  final String? vehiclePlate;
  final int? branchId;
  final String? branchName;

  DriverProfile({
    required this.userId,
    this.firstName,
    this.lastName,
    this.email,
    this.contact,
    this.vehicleId,
    this.vehiclePlate,
    this.branchId,
    this.branchName,
  });

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();

  factory DriverProfile.fromJson(Map<String, dynamic> json) => DriverProfile(
    userId: (json['id'] as int?) ?? (json['user_id'] as int?) ?? 0,
    firstName:
        json['firstName'] as String? ??
        json['first_name'] as String? ??
        json['user_fname'] as String?,
    lastName:
        json['lastName'] as String? ??
        json['last_name'] as String? ??
        json['user_lname'] as String?,
    email: json['email'] as String? ?? json['user_email'] as String?,
    contact: json['contact'] as String? ?? json['user_contact'] as String?,
    vehicleId: (json['vehicle_id'] as num?)?.toInt(),
    vehiclePlate: json['vehicle_plate'] as String?,
    branchId: (json['branch_id'] as num?)?.toInt(),
    branchName: json['branch_name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'contact': contact,
    'vehicle_id': vehicleId,
    'vehicle_plate': vehiclePlate,
    'branch_id': branchId,
    'branch_name': branchName,
  };
}
