class Customer {
  final String id;
  final String projectCode;
  final String companyName;
  final String address;
  final String contactInfo;

  Customer({
    required this.id,
    required this.projectCode,
    required this.companyName,
    required this.address,
    required this.contactInfo,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id']?.toString() ?? '',
      projectCode: map['projectCode']?.toString() ?? '',
      companyName: map['companyName']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      contactInfo: map['contactInfo']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectCode': projectCode,
      'companyName': companyName,
      'address': address,
      'contactInfo': contactInfo,
    };
  }
}

class Machine {
  final String id;
  final String customerId;
  final String tagname;
  final String? warrantyStatus;

  Machine({
    required this.id,
    required this.customerId,
    required this.tagname,
    this.warrantyStatus,
  });

  factory Machine.fromMap(Map<String, dynamic> map) {
    return Machine(
      id: map['id']?.toString() ?? '',
      customerId: map['customerId']?.toString() ?? '',
      tagname: map['tagname']?.toString() ?? '',
      warrantyStatus: map['warrantyStatus']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'tagname': tagname,
      'warrantyStatus': warrantyStatus,
    };
  }
}

class MaintenanceHistory {
  final String id;
  final String customerId;
  final String machineId;
  final String serviceType; // "Bảo hành" or "Sửa chữa dịch vụ"
  final DateTime date;
  final String content;
  final String performer;
  final DateTime updatedAt;

  MaintenanceHistory({
    required this.id,
    required this.customerId,
    required this.machineId,
    required this.serviceType,
    required this.date,
    required this.content,
    required this.performer,
    required this.updatedAt,
  });

  factory MaintenanceHistory.fromMap(Map<String, dynamic> map) {
    return MaintenanceHistory(
      id: map['id']?.toString() ?? '',
      customerId: map['customerId']?.toString() ?? '',
      machineId: map['machineId']?.toString() ?? '',
      serviceType: map['serviceType']?.toString() ?? 'Sửa chữa dịch vụ',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      content: map['content']?.toString() ?? '',
      performer: map['performer']?.toString() ?? '',
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'machineId': machineId,
      'serviceType': serviceType,
      'date': date.toIso8601String(),
      'content': content,
      'performer': performer,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
