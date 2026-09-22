import 'project.dart';

enum ProjectStageStatus {
  notStarted('Chưa bắt đầu'),
  inProgress('Đang thực hiện'),
  completed('Hoàn thành'),
  blocked('Bị chặn');

  const ProjectStageStatus(this.label);
  final String label;
}

class ProjectStage {
  final String id;
  final String projectId;
  final String stageName;
  final int stageOrder;
  final ProjectStageStatus status;
  final DateTime? startDate;
  final DateTime? completedDate;
  // Ngày kế hoạch (dự kiến) — khác với startDate/completedDate là ngày thực
  // tế. Dùng cho chức năng Lịch trình dự án (Schedule) và nhắc hạn.
  final DateTime? plannedStartDate;
  final DateTime? plannedEndDate;
  final String assignedUser;
  final String notes;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectStage({
    required this.id,
    required this.projectId,
    required this.stageName,
    required this.stageOrder,
    this.status = ProjectStageStatus.notStarted,
    this.startDate,
    this.completedDate,
    this.plannedStartDate,
    this.plannedEndDate,
    this.assignedUser = '',
    this.notes = '',
    this.syncStatus = SyncStatus.local,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Đã trễ hạn kế hoạch: có `plannedEndDate`, chưa hoàn thành, và hôm nay
  /// đã qua ngày kế hoạch đó.
  bool get isOverdue =>
      plannedEndDate != null &&
      status != ProjectStageStatus.completed &&
      DateTime.now().isAfter(plannedEndDate!);

  factory ProjectStage.fromJson(Map<String, dynamic> json) => ProjectStage(
    id: json['id'] as String,
    projectId: json['projectId'] as String,
    stageName: json['stageName'] as String? ?? '',
    stageOrder: json['stageOrder'] as int? ?? 0,
    status: ProjectStageStatus.values.firstWhere(
      (item) => item.name == json['status'],
      orElse: () => ProjectStageStatus.notStarted,
    ),
    startDate: json['startDate'] == null
        ? null
        : DateTime.parse(json['startDate'] as String),
    completedDate: json['completedDate'] == null
        ? null
        : DateTime.parse(json['completedDate'] as String),
    plannedStartDate: json['plannedStartDate'] == null
        ? null
        : DateTime.parse(json['plannedStartDate'] as String),
    plannedEndDate: json['plannedEndDate'] == null
        ? null
        : DateTime.parse(json['plannedEndDate'] as String),
    assignedUser: json['assignedUser'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
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
    'stageName': stageName,
    'stageOrder': stageOrder,
    'status': status.name,
    'startDate': startDate?.toIso8601String(),
    'completedDate': completedDate?.toIso8601String(),
    'plannedStartDate': plannedStartDate?.toIso8601String(),
    'plannedEndDate': plannedEndDate?.toIso8601String(),
    'assignedUser': assignedUser,
    'notes': notes,
    'syncStatus': syncStatus.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  ProjectStage copyWith({
    String? id,
    String? projectId,
    String? stageName,
    int? stageOrder,
    ProjectStageStatus? status,
    DateTime? startDate,
    DateTime? completedDate,
    DateTime? plannedStartDate,
    DateTime? plannedEndDate,
    String? assignedUser,
    String? notes,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ProjectStage(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    stageName: stageName ?? this.stageName,
    stageOrder: stageOrder ?? this.stageOrder,
    status: status ?? this.status,
    startDate: startDate ?? this.startDate,
    completedDate: completedDate ?? this.completedDate,
    plannedStartDate: plannedStartDate ?? this.plannedStartDate,
    plannedEndDate: plannedEndDate ?? this.plannedEndDate,
    assignedUser: assignedUser ?? this.assignedUser,
    notes: notes ?? this.notes,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

const defaultProjectStageNames = <String>[
  'Giao hàng',
  'Khui thùng',
  'Lắp đặt',
  'Chạy thử',
  'Đào tạo',
  'Nghiệm thu',
];
