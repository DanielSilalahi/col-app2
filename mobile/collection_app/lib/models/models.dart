class UserModel {
  final int id;
  final String name;
  final String username;
  final String role;
  final String? phone;
  final bool isActive;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.phone,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      username: json['username'],
      role: json['role'],
      phone: json['phone'],
      isActive: json['is_active'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'role': role,
        'phone': phone,
        'is_active': isActive,
      };
}

class CustomerModel {
  final int id;
  final String name;
  final String? address;
  final String? phone;
  final double? lat;
  final double? lng;
  final String status;
  final String? notes;
  final int? assignedAgentId;
  final double? outstandingAmount;
  final int? overdueDays;

  CustomerModel({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.lat,
    this.lng,
    required this.status,
    this.notes,
    this.assignedAgentId,
    this.outstandingAmount,
    this.overdueDays,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      phone: json['phone'],
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      status: json['status'],
      notes: json['notes'],
      assignedAgentId: json['assigned_agent_id'],
      outstandingAmount: (json['outstanding_amount'] as num?)?.toDouble(),
      overdueDays: json['overdue_days'],
    );
  }
}

class CollectionModel {
  final int id;
  final int customerId;
  final int agentId;
  final String status;
  final String? notes;
  final String? photoUrl;
  final double? gpsLat;
  final double? gpsLng;
  final DateTime timestamp;

  CollectionModel({
    required this.id,
    required this.customerId,
    required this.agentId,
    required this.status,
    this.notes,
    this.photoUrl,
    this.gpsLat,
    this.gpsLng,
    required this.timestamp,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    return CollectionModel(
      id: json['id'],
      customerId: json['customer_id'],
      agentId: json['agent_id'],
      status: json['status'],
      notes: json['notes'],
      photoUrl: json['photo_url'],
      gpsLat: (json['gps_lat'] as num?)?.toDouble(),
      gpsLng: (json['gps_lng'] as num?)?.toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class VaRequestModel {
  final int id;
  final int customerId;
  final int agentId;
  final String? notes;
  final String status;
  final String? vaNumber;
  final String? vaBank;
  final int? vaAmount;
  final DateTime? createdAt;

  VaRequestModel({
    required this.id,
    required this.customerId,
    required this.agentId,
    this.notes,
    required this.status,
    this.vaNumber,
    this.vaBank,
    this.vaAmount,
    this.createdAt,
  });

  factory VaRequestModel.fromJson(Map<String, dynamic> json) {
    return VaRequestModel(
      id: json['id'],
      customerId: json['customer_id'],
      agentId: json['agent_id'],
      notes: json['notes'],
      status: json['status'],
      vaNumber: json['va_number'],
      vaBank: json['va_bank'],
      vaAmount: json['va_amount'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}
