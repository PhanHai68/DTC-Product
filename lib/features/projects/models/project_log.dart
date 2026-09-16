import 'project_stage.dart';

class ProjectLog {
  final String id;
  final String projectId;
  final ProjectStage stage;
  final DateTime createdAt;
  final String createdBy;
  final String notes;
  final List<String> photos; // local paths or URLs
  final Map<String, dynamic> technicalData;

  ProjectLog({
    required this.id,
    required this.projectId,
    required this.stage,
    required this.createdAt,
    required this.createdBy,
    this.notes = '',
    this.photos = const [],
    this.technicalData = const {},
  });

  factory ProjectLog.fromJson(Map<String, dynamic> json) {
    return ProjectLog(
      id: json['id'] as String,
      projectId: json['projectId'] as String,
      stage: ProjectStage.values.firstWhere(
        (e) => e.name == json['stage'],
        orElse: () => ProjectStage.delivery,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdBy: json['createdBy'] as String,
      notes: json['notes'] as String? ?? '',
      photos: List<String>.from(json['photos'] ?? []),
      technicalData: json['technicalData'] != null 
          ? Map<String, dynamic>.from(json['technicalData'])
          : const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'stage': stage.name,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'notes': notes,
      'photos': photos,
      'technicalData': technicalData,
    };
  }
}
