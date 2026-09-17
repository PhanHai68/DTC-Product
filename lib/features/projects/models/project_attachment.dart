import 'project.dart';

enum ProjectFileType { photo, video, pdf, document, other }

class ProjectAttachment {
  final String id;
  final String projectId;
  final String? machineId;
  final String? stageId;
  final String? activityId;
  final String category;
  final ProjectFileType fileType;
  final String fileName;
  final String localPath;
  final String cloudUrl;
  final String thumbnailPath;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String description;
  final String location;
  final SyncStatus syncStatus;

  const ProjectAttachment({
    required this.id,
    required this.projectId,
    this.machineId,
    this.stageId,
    this.activityId,
    this.category = 'general',
    required this.fileType,
    required this.fileName,
    this.localPath = '',
    this.cloudUrl = '',
    this.thumbnailPath = '',
    this.createdBy = '',
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.location = '',
    this.syncStatus = SyncStatus.local,
  });

  String get displayPath => cloudUrl.isNotEmpty ? cloudUrl : localPath;

  factory ProjectAttachment.fromJson(Map<String, dynamic> json) =>
      ProjectAttachment(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        machineId: json['machineId'] as String?,
        stageId: json['stageId'] as String?,
        activityId: json['activityId'] as String?,
        category: json['category'] as String? ?? 'general',
        fileType: ProjectFileType.values.firstWhere(
          (item) => item.name == json['fileType'],
          orElse: () => ProjectFileType.other,
        ),
        fileName: json['fileName'] as String? ?? '',
        localPath: json['localPath'] as String? ?? '',
        cloudUrl: json['cloudUrl'] as String? ?? '',
        thumbnailPath: json['thumbnailPath'] as String? ?? '',
        createdBy: json['createdBy'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        description: json['description'] as String? ?? '',
        location: json['location'] as String? ?? '',
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
    'activityId': activityId,
    'category': category,
    'fileType': fileType.name,
    'fileName': fileName,
    'localPath': localPath,
    'cloudUrl': cloudUrl,
    'thumbnailPath': thumbnailPath,
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'description': description,
    'location': location,
    'syncStatus': syncStatus.name,
  };

  ProjectAttachment copyWith({
    String? fileName,
    String? localPath,
    String? cloudUrl,
    String? description,
    String? category,
    SyncStatus? syncStatus,
    DateTime? updatedAt,
  }) => ProjectAttachment(
    id: id,
    projectId: projectId,
    machineId: machineId,
    stageId: stageId,
    activityId: activityId,
    category: category ?? this.category,
    fileType: fileType,
    fileName: fileName ?? this.fileName,
    localPath: localPath ?? this.localPath,
    cloudUrl: cloudUrl ?? this.cloudUrl,
    thumbnailPath: thumbnailPath,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    description: description ?? this.description,
    location: location,
    syncStatus: syncStatus ?? this.syncStatus,
  );
}
