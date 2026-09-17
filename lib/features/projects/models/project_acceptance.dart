import 'project.dart';

enum AcceptanceStatus {
  pending('Chờ nghiệm thu'),
  accepted('Đã nghiệm thu'),
  acceptedWithConditions('Nghiệm thu có điều kiện'),
  rejected('Từ chối');

  const AcceptanceStatus(this.label);
  final String label;
}

class ProjectAcceptance {
  final String id;
  final String projectId;
  final String? machineId;
  final bool installationCompleted;
  final bool testingCompleted;
  final bool trainingCompleted;
  final DateTime? acceptanceDate;
  final String customerRepresentative;
  final String dtcRepresentative;
  final String notes;
  final AcceptanceStatus status;
  final String customerSignature;
  final String dtcSignature;
  final String customerName;
  final String dtcEngineer;
  final DateTime? acceptedAt;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectAcceptance({
    required this.id,
    required this.projectId,
    this.machineId,
    this.installationCompleted = false,
    this.testingCompleted = false,
    this.trainingCompleted = false,
    this.acceptanceDate,
    this.customerRepresentative = '',
    this.dtcRepresentative = '',
    this.notes = '',
    this.status = AcceptanceStatus.pending,
    this.customerSignature = '',
    this.dtcSignature = '',
    this.customerName = '',
    this.dtcEngineer = '',
    this.acceptedAt,
    this.syncStatus = SyncStatus.local,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectAcceptance.fromJson(Map<String, dynamic> json) =>
      ProjectAcceptance(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        machineId: json['machineId'] as String?,
        installationCompleted:
            json['installationCompleted'] == true ||
            json['installationCompleted'] == 1,
        testingCompleted:
            json['testingCompleted'] == true || json['testingCompleted'] == 1,
        trainingCompleted:
            json['trainingCompleted'] == true || json['trainingCompleted'] == 1,
        acceptanceDate: json['acceptanceDate'] == null
            ? null
            : DateTime.parse(json['acceptanceDate'] as String),
        customerRepresentative: json['customerRepresentative'] as String? ?? '',
        dtcRepresentative: json['dtcRepresentative'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        status: AcceptanceStatus.values.firstWhere(
          (item) => item.name == json['status'],
          orElse: () => AcceptanceStatus.pending,
        ),
        customerSignature: json['customerSignature'] as String? ?? '',
        dtcSignature: json['dtcSignature'] as String? ?? '',
        customerName: json['customerName'] as String? ?? '',
        dtcEngineer: json['dtcEngineer'] as String? ?? '',
        acceptedAt: json['acceptedAt'] == null
            ? null
            : DateTime.parse(json['acceptedAt'] as String),
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
    'machineId': machineId,
    'installationCompleted': installationCompleted,
    'testingCompleted': testingCompleted,
    'trainingCompleted': trainingCompleted,
    'acceptanceDate': acceptanceDate?.toIso8601String(),
    'customerRepresentative': customerRepresentative,
    'dtcRepresentative': dtcRepresentative,
    'notes': notes,
    'status': status.name,
    'customerSignature': customerSignature,
    'dtcSignature': dtcSignature,
    'customerName': customerName,
    'dtcEngineer': dtcEngineer,
    'acceptedAt': acceptedAt?.toIso8601String(),
    'syncStatus': syncStatus.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  ProjectAcceptance copyWith({
    String? machineId,
    bool? installationCompleted,
    bool? testingCompleted,
    bool? trainingCompleted,
    DateTime? acceptanceDate,
    String? customerRepresentative,
    String? dtcRepresentative,
    String? notes,
    AcceptanceStatus? status,
    String? customerSignature,
    String? dtcSignature,
    String? customerName,
    String? dtcEngineer,
    DateTime? acceptedAt,
    DateTime? updatedAt,
  }) => ProjectAcceptance(
    id: id,
    projectId: projectId,
    machineId: machineId ?? this.machineId,
    installationCompleted: installationCompleted ?? this.installationCompleted,
    testingCompleted: testingCompleted ?? this.testingCompleted,
    trainingCompleted: trainingCompleted ?? this.trainingCompleted,
    acceptanceDate: acceptanceDate ?? this.acceptanceDate,
    customerRepresentative:
        customerRepresentative ?? this.customerRepresentative,
    dtcRepresentative: dtcRepresentative ?? this.dtcRepresentative,
    notes: notes ?? this.notes,
    status: status ?? this.status,
    customerSignature: customerSignature ?? this.customerSignature,
    dtcSignature: dtcSignature ?? this.dtcSignature,
    customerName: customerName ?? this.customerName,
    dtcEngineer: dtcEngineer ?? this.dtcEngineer,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    syncStatus: SyncStatus.pending,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
