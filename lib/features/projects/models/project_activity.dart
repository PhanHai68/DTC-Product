import 'project.dart';

enum ProjectActivityType {
  projectCreated,
  machineAdded,
  stageUpdated,
  checklistUpdated,
  attachmentAdded,
  acceptanceUpdated,
  note,
}

class ProjectActivity {
  final String id;
  final String projectId;
  final String? machineId;
  final String? stageId;
  final ProjectActivityType activityType;
  final String title;
  final String description;
  final String userId;
  final DateTime createdAt;
  final List<String> attachmentIds;
  final SyncStatus syncStatus;

  const ProjectActivity({
    required this.id,
    required this.projectId,
    this.machineId,
    this.stageId,
    required this.activityType,
    required this.title,
    this.description = '',
    this.userId = '',
    required this.createdAt,
    this.attachmentIds = const [],
    this.syncStatus = SyncStatus.local,
  });

  factory ProjectActivity.fromJson(Map<String, dynamic> json) =>
      ProjectActivity(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        machineId: json['machineId'] as String?,
        stageId: json['stageId'] as String?,
        activityType: ProjectActivityType.values.firstWhere(
          (item) => item.name == json['activityType'],
          orElse: () => ProjectActivityType.note,
        ),
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        attachmentIds: List<String>.from(
          json['attachmentIds'] as List<dynamic>? ?? const [],
        ),
        syncStatus: SyncStatus.values.firstWhere(
          (item) => item.name == json['syncStatus'],
          orElse: () => SyncStatus.local,
        ),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'machineId': machineId,
    'stageId': stageId,
    'activityType': activityType.name,
    'title': title,
    'description': description,
    'userId': userId,
    'createdAt': createdAt.toIso8601String(),
    'attachmentIds': attachmentIds,
    'syncStatus': syncStatus.name,
  };

  ProjectActivity copyWith({
    String? title,
    String? description,
    List<String>? attachmentIds,
    SyncStatus? syncStatus,
  }) => ProjectActivity(
    id: id,
    projectId: projectId,
    machineId: machineId,
    stageId: stageId,
    activityType: activityType,
    title: title ?? this.title,
    description: description ?? this.description,
    userId: userId,
    createdAt: createdAt,
    attachmentIds: attachmentIds ?? this.attachmentIds,
    syncStatus: syncStatus ?? this.syncStatus,
  );
}
