class MaintenanceRecord {
  final int? id;
  final String customerName;
  final String machineModel;
  final DateTime installDate;
  final int maintenanceCycleMonths;
  final DateTime nextMaintenanceDate;
  final String serviceType;
  final String notes;

  MaintenanceRecord({
    this.id,
    required this.customerName,
    required this.machineModel,
    required this.installDate,
    required this.maintenanceCycleMonths,
    required this.nextMaintenanceDate,
    this.serviceType = 'Bảo hành',
    this.notes = '',
  });

  MaintenanceRecord copyWith({
    int? id,
    String? customerName,
    String? machineModel,
    DateTime? installDate,
    int? maintenanceCycleMonths,
    DateTime? nextMaintenanceDate,
    String? serviceType,
    String? notes,
  }) {
    return MaintenanceRecord(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      machineModel: machineModel ?? this.machineModel,
      installDate: installDate ?? this.installDate,
      maintenanceCycleMonths: maintenanceCycleMonths ?? this.maintenanceCycleMonths,
      nextMaintenanceDate: nextMaintenanceDate ?? this.nextMaintenanceDate,
      serviceType: serviceType ?? this.serviceType,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerName': customerName,
      'machineModel': machineModel,
      'installDate': installDate.toIso8601String(),
      'maintenanceCycleMonths': maintenanceCycleMonths,
      'nextMaintenanceDate': nextMaintenanceDate.toIso8601String(),
      'serviceType': serviceType,
      'notes': notes,
    };
  }

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) {
    return MaintenanceRecord(
      id: map['id'] as int?,
      customerName: map['customerName'] ?? '',
      machineModel: map['machineModel'] ?? '',
      installDate: DateTime.tryParse(map['installDate'] ?? '') ?? DateTime.now(),
      maintenanceCycleMonths: map['maintenanceCycleMonths'] ?? 3,
      nextMaintenanceDate: DateTime.tryParse(map['nextMaintenanceDate'] ?? '') ?? DateTime.now(),
      serviceType: map['serviceType'] ?? 'Bảo hành',
      notes: map['notes'] ?? '',
    );
  }

  /// 0 = Quá hạn (Đỏ), 1 = Sắp đến hạn trong vòng 15 ngày (Vàng), 2 = Tốt (Xanh)
  int get status {
    final now = DateTime.now();
    final difference = nextMaintenanceDate.difference(now).inDays;
    
    if (difference < 0) return 0;
    if (difference <= 15) return 1;
    return 2;
  }
}
