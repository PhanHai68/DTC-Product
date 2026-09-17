import 'project.dart';

enum ProjectSubmissionType {
  delivery,
  unpacking,
  installation,
  acceptanceColorSorter,
  acceptanceCompressor,
}

class ProjectStageSubmission {
  final String id;
  final String projectId;
  final String stageId;
  final String? machineId;
  final ProjectSubmissionType submissionType;
  final Map<String, dynamic> data;
  final DateTime workDate;
  final String result;
  final bool isFinalConfirmation;
  final String confirmedBy;
  final DateTime confirmedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;

  const ProjectStageSubmission({
    required this.id,
    required this.projectId,
    required this.stageId,
    this.machineId,
    required this.submissionType,
    this.data = const {},
    required this.workDate,
    this.result = '',
    this.isFinalConfirmation = false,
    this.confirmedBy = '',
    required this.confirmedAt,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = SyncStatus.local,
  });

  factory ProjectStageSubmission.fromJson(Map<String, dynamic> json) =>
      ProjectStageSubmission(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        stageId: json['stageId'] as String,
        machineId: json['machineId'] as String?,
        submissionType: ProjectSubmissionType.values.firstWhere(
          (item) => item.name == json['submissionType'],
          orElse: () => ProjectSubmissionType.delivery,
        ),
        data: Map<String, dynamic>.from(
          json['data'] as Map<String, dynamic>? ?? const {},
        ),
        workDate: DateTime.parse(
          (json['workDate'] ?? json['confirmedAt']) as String,
        ),
        result: json['result'] as String? ?? '',
        isFinalConfirmation:
            json['isFinalConfirmation'] == true ||
            json['isFinalConfirmation'] == 1,
        confirmedBy: json['confirmedBy'] as String? ?? '',
        confirmedAt: DateTime.parse(json['confirmedAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        syncStatus: SyncStatus.values.firstWhere(
          (item) => item.name == json['syncStatus'],
          orElse: () => SyncStatus.local,
        ),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'stageId': stageId,
    'machineId': machineId,
    'submissionType': submissionType.name,
    'data': data,
    'workDate': workDate.toIso8601String(),
    'result': result,
    'isFinalConfirmation': isFinalConfirmation,
    'confirmedBy': confirmedBy,
    'confirmedAt': confirmedAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'syncStatus': syncStatus.name,
  };

  ProjectStageSubmission copyWith({
    String? machineId,
    ProjectSubmissionType? submissionType,
    Map<String, dynamic>? data,
    DateTime? workDate,
    String? result,
    bool? isFinalConfirmation,
    String? confirmedBy,
    DateTime? confirmedAt,
    DateTime? updatedAt,
    SyncStatus? syncStatus,
  }) => ProjectStageSubmission(
    id: id,
    projectId: projectId,
    stageId: stageId,
    machineId: machineId ?? this.machineId,
    submissionType: submissionType ?? this.submissionType,
    data: data ?? this.data,
    workDate: workDate ?? this.workDate,
    result: result ?? this.result,
    isFinalConfirmation: isFinalConfirmation ?? this.isFinalConfirmation,
    confirmedBy: confirmedBy ?? this.confirmedBy,
    confirmedAt: confirmedAt ?? this.confirmedAt,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
  );
}
