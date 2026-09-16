import 'project_machine.dart';

class Project {
  final String id;
  final String projectCode;
  final String customerName;
  final String projectName;
  final String location;
  final DateTime startDate;
  final DateTime? endDate;
  final double progress; // 0.0 - 1.0
  final String status; // 'In Progress', 'Completed'
  final List<String> engineers;
  final List<ProjectMachine> machines;

  Project({
    required this.id,
    required this.projectCode,
    required this.customerName,
    required this.projectName,
    required this.location,
    required this.startDate,
    this.endDate,
    this.progress = 0.0,
    this.status = 'In Progress',
    this.engineers = const [],
    this.machines = const [],
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      projectCode: json['projectCode'] as String,
      customerName: json['customerName'] as String,
      projectName: json['projectName'] as String,
      location: json['location'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null 
          ? DateTime.parse(json['endDate'] as String) 
          : null,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'In Progress',
      engineers: List<String>.from(json['engineers'] ?? []),
      machines: (json['machines'] as List<dynamic>?)
              ?.map((e) => ProjectMachine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectCode': projectCode,
      'customerName': customerName,
      'projectName': projectName,
      'location': location,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'progress': progress,
      'status': status,
      'engineers': engineers,
      'machines': machines.map((e) => e.toJson()).toList(),
    };
  }

  Project copyWith({
    String? id,
    String? projectCode,
    String? customerName,
    String? projectName,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    double? progress,
    String? status,
    List<String>? engineers,
    List<ProjectMachine>? machines,
  }) {
    return Project(
      id: id ?? this.id,
      projectCode: projectCode ?? this.projectCode,
      customerName: customerName ?? this.customerName,
      projectName: projectName ?? this.projectName,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      engineers: engineers ?? this.engineers,
      machines: machines ?? this.machines,
    );
  }
}
