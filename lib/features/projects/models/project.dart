import 'project_machine.dart';

enum ProjectStatus {
  preparing('Chuẩn bị'),
  active('Đang triển khai'),
  waitingAcceptance('Chờ nghiệm thu'),
  completed('Hoàn thành'),
  paused('Tạm dừng');

  const ProjectStatus(this.label);
  final String label;

  static ProjectStatus parse(String? value) => ProjectStatus.values.firstWhere(
    (item) => item.name == value || item.label == value,
    orElse: () => ProjectStatus.preparing,
  );
}

enum SyncStatus { local, pending, synced, failed }

class Project {
  final String id;
  final String projectName;
  final String customerName;
  final String projectCode;
  final String location;
  final DateTime startDate;
  final DateTime? expectedCompletionDate;
  final String projectManager;
  final String technicalEngineer;
  final String salesPerson;
  final String description;
  final ProjectStatus status;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProjectMachine> machines;
  final int completedStages;
  final int totalStages;

  const Project({
    required this.id,
    required this.projectName,
    required this.customerName,
    required this.projectCode,
    required this.location,
    required this.startDate,
    this.expectedCompletionDate,
    this.projectManager = '',
    this.technicalEngineer = '',
    this.salesPerson = '',
    this.description = '',
    this.status = ProjectStatus.preparing,
    this.syncStatus = SyncStatus.local,
    required this.createdAt,
    required this.updatedAt,
    this.machines = const [],
    this.completedStages = 0,
    this.totalStages = 0,
  });

  double get progress => totalStages == 0 ? 0 : completedStages / totalStages;
  int get machineCount => machines.fold(0, (sum, item) => sum + item.quantity);
  String get trackingTitle {
    final model = machines.isEmpty || machines.first.model.trim().isEmpty
        ? 'Chưa có model'
        : machines.first.model.trim();
    return 'DTC-Theo dõi dự án $model ${projectName.trim()}';
  }

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String,
    projectName: json['projectName'] as String? ?? '',
    customerName: json['customerName'] as String? ?? '',
    projectCode: json['projectCode'] as String? ?? '',
    location: json['location'] as String? ?? '',
    startDate: DateTime.parse(json['startDate'] as String),
    expectedCompletionDate: json['expectedCompletionDate'] == null
        ? null
        : DateTime.parse(json['expectedCompletionDate'] as String),
    projectManager: json['projectManager'] as String? ?? '',
    technicalEngineer: json['technicalEngineer'] as String? ?? '',
    salesPerson: json['salesPerson'] as String? ?? '',
    description: json['description'] as String? ?? '',
    status: ProjectStatus.parse(json['status'] as String?),
    syncStatus: SyncStatus.values.firstWhere(
      (item) => item.name == json['syncStatus'],
      orElse: () => SyncStatus.local,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    machines: (json['machines'] as List<dynamic>? ?? const [])
        .map((item) => ProjectMachine.fromJson(item as Map<String, dynamic>))
        .toList(),
    completedStages: json['completedStages'] as int? ?? 0,
    totalStages: json['totalStages'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectName': projectName,
    'customerName': customerName,
    'projectCode': projectCode,
    'location': location,
    'startDate': startDate.toIso8601String(),
    'expectedCompletionDate': expectedCompletionDate?.toIso8601String(),
    'projectManager': projectManager,
    'technicalEngineer': technicalEngineer,
    'salesPerson': salesPerson,
    'description': description,
    'status': status.name,
    'syncStatus': syncStatus.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'machines': machines.map((item) => item.toJson()).toList(),
    'completedStages': completedStages,
    'totalStages': totalStages,
  };

  Project copyWith({
    String? id,
    String? projectName,
    String? customerName,
    String? projectCode,
    String? location,
    DateTime? startDate,
    DateTime? expectedCompletionDate,
    String? projectManager,
    String? technicalEngineer,
    String? salesPerson,
    String? description,
    ProjectStatus? status,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ProjectMachine>? machines,
    int? completedStages,
    int? totalStages,
  }) => Project(
    id: id ?? this.id,
    projectName: projectName ?? this.projectName,
    customerName: customerName ?? this.customerName,
    projectCode: projectCode ?? this.projectCode,
    location: location ?? this.location,
    startDate: startDate ?? this.startDate,
    expectedCompletionDate:
        expectedCompletionDate ?? this.expectedCompletionDate,
    projectManager: projectManager ?? this.projectManager,
    technicalEngineer: technicalEngineer ?? this.technicalEngineer,
    salesPerson: salesPerson ?? this.salesPerson,
    description: description ?? this.description,
    status: status ?? this.status,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    machines: machines ?? this.machines,
    completedStages: completedStages ?? this.completedStages,
    totalStages: totalStages ?? this.totalStages,
  );
}
