import 'project.dart';

class ProjectChecklist {
  final String id;
  final String projectId;
  final String stageId;
  final String? machineId;
  final String title;
  final bool isCompleted;
  final String completedBy;
  final DateTime? completedAt;
  final String notes;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectChecklist({
    required this.id,
    required this.projectId,
    required this.stageId,
    this.machineId,
    required this.title,
    this.isCompleted = false,
    this.completedBy = '',
    this.completedAt,
    this.notes = '',
    this.syncStatus = SyncStatus.local,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectChecklist.fromJson(Map<String, dynamic> json) =>
      ProjectChecklist(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        stageId: json['stageId'] as String,
        machineId: json['machineId'] as String?,
        title: json['title'] as String? ?? '',
        isCompleted: json['isCompleted'] == true || json['isCompleted'] == 1,
        completedBy: json['completedBy'] as String? ?? '',
        completedAt: json['completedAt'] == null
            ? null
            : DateTime.parse(json['completedAt'] as String),
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
    'stageId': stageId,
    'machineId': machineId,
    'title': title,
    'isCompleted': isCompleted,
    'completedBy': completedBy,
    'completedAt': completedAt?.toIso8601String(),
    'notes': notes,
    'syncStatus': syncStatus.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  ProjectChecklist copyWith({
    bool? isCompleted,
    String? completedBy,
    DateTime? completedAt,
    String? notes,
    DateTime? updatedAt,
  }) => ProjectChecklist(
    id: id,
    projectId: projectId,
    stageId: stageId,
    machineId: machineId,
    title: title,
    isCompleted: isCompleted ?? this.isCompleted,
    completedBy: completedBy ?? this.completedBy,
    completedAt: completedAt ?? this.completedAt,
    notes: notes ?? this.notes,
    syncStatus: SyncStatus.pending,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
