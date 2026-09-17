import 'project.dart';

class ProjectMachine {
  final String id;
  final String projectId;
  final String? productId;
  final String machineName;
  final String model;
  final String serialNumber;
  final int quantity;
  final String installationPosition;
  final String status;
  final String notes;
  final String qrCode;
  final String assetCode;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectMachine({
    required this.id,
    required this.projectId,
    this.productId,
    required this.machineName,
    required this.model,
    required this.serialNumber,
    this.quantity = 1,
    this.installationPosition = '',
    this.status = 'Chuẩn bị',
    this.notes = '',
    this.qrCode = '',
    this.assetCode = '',
    this.syncStatus = SyncStatus.local,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectMachine.fromJson(Map<String, dynamic> json) => ProjectMachine(
    id: json['id'] as String,
    projectId: json['projectId'] as String,
    productId: json['productId'] as String?,
    machineName: json['machineName'] as String? ?? '',
    model: json['model'] as String? ?? '',
    serialNumber: json['serialNumber'] as String? ?? '',
    quantity: json['quantity'] as int? ?? 1,
    installationPosition: json['installationPosition'] as String? ?? '',
    status: json['status'] as String? ?? 'Chuẩn bị',
    notes: json['notes'] as String? ?? '',
    qrCode: json['qrCode'] as String? ?? '',
    assetCode: json['assetCode'] as String? ?? '',
    syncStatus: SyncStatus.values.firstWhere(
      (item) => item.name == json['syncStatus'],
      orElse: () => SyncStatus.local,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'productId': productId,
    'machineName': machineName,
    'model': model,
    'serialNumber': serialNumber,
    'quantity': quantity,
    'installationPosition': installationPosition,
    'status': status,
    'notes': notes,
    'qrCode': qrCode,
    'assetCode': assetCode,
    'syncStatus': syncStatus.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  ProjectMachine copyWith({
    String? id,
    String? projectId,
    String? productId,
    String? machineName,
    String? model,
    String? serialNumber,
    int? quantity,
    String? installationPosition,
    String? status,
    String? notes,
    String? qrCode,
    String? assetCode,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProjectMachine(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    productId: productId ?? this.productId,
    machineName: machineName ?? this.machineName,
    model: model ?? this.model,
    serialNumber: serialNumber ?? this.serialNumber,
    quantity: quantity ?? this.quantity,
    installationPosition: installationPosition ?? this.installationPosition,
    status: status ?? this.status,
    notes: notes ?? this.notes,
    qrCode: qrCode ?? this.qrCode,
    assetCode: assetCode ?? this.assetCode,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
