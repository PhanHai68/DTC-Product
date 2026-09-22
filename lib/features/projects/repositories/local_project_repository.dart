import 'dart:convert';

import '../data/project_local_data_source.dart';
import '../models/project.dart';
import '../models/project_acceptance.dart';
import '../models/project_activity.dart';
import '../models/project_attachment.dart';
import '../models/project_checklist.dart';
import '../models/project_machine.dart';
import '../models/project_stage.dart';
import '../models/project_stage_submission.dart';
import 'project_repository.dart';

class LocalProjectRepository implements ProjectRepository {
  LocalProjectRepository({ProjectLocalDataSource? localDataSource})
    : _local = localDataSource ?? const ProjectLocalDataSource();

  final ProjectLocalDataSource _local;

  Map<String, dynamic> _map(Map<String, Object?> value) =>
      Map<String, dynamic>.from(value);
  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  Map<String, Object?> _projectRow(Project item) => {
    'id': item.id,
    'projectName': item.projectName,
    'customerName': item.customerName,
    'projectCode': item.projectCode,
    'location': item.location,
    'startDate': item.startDate.toIso8601String(),
    'expectedCompletionDate': item.expectedCompletionDate?.toIso8601String(),
    'projectManager': item.projectManager,
    'technicalEngineer': item.technicalEngineer,
    'salesPerson': item.salesPerson,
    'description': item.description,
    'status': item.status.name,
    'syncStatus': item.syncStatus.name,
    'createdAt': item.createdAt.toIso8601String(),
    'updatedAt': item.updatedAt.toIso8601String(),
  };

  Map<String, Object?> _machineRow(ProjectMachine item) => {...item.toJson()};

  Map<String, Object?> _stageRow(ProjectStage item) => {...item.toJson()};

  Map<String, Object?> _checklistRow(ProjectChecklist item) => {
    ...item.toJson(),
    'isCompleted': item.isCompleted ? 1 : 0,
  };

  Map<String, Object?> _activityRow(ProjectActivity item) => {
    ...item.toJson(),
    'attachmentIds': jsonEncode(item.attachmentIds),
  };

  Map<String, Object?> _attachmentRow(ProjectAttachment item) => {
    ...item.toJson(),
  };

  Map<String, Object?> _submissionRow(ProjectStageSubmission item) => {
    ...item.toJson(),
    'dataJson': jsonEncode(item.data),
    'isFinalConfirmation': item.isFinalConfirmation ? 1 : 0,
  }..remove('data');

  Map<String, Object?> _acceptanceRow(ProjectAcceptance item) => {
    ...item.toJson(),
    'installationCompleted': item.installationCompleted ? 1 : 0,
    'testingCompleted': item.testingCompleted ? 1 : 0,
    'trainingCompleted': item.trainingCompleted ? 1 : 0,
  };

  @override
  Future<List<Project>> getProjects() async {
    final rows = await _local.query('projects', orderBy: 'updatedAt DESC');
    final result = <Project>[];
    for (final row in rows) {
      result.add(await _hydrate(Project.fromJson(_map(row))));
    }
    return result;
  }

  @override
  Future<Project?> getProjectById(String id) async {
    final rows = await _local.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _hydrate(Project.fromJson(_map(rows.first)));
  }

  Future<Project> _hydrate(Project project) async {
    final machines = await getMachines(project.id);
    final stages = await getStages(project.id);
    return project.copyWith(
      machines: machines,
      completedStages: stages
          .where((item) => item.status == ProjectStageStatus.completed)
          .length,
      totalStages: stages.length,
    );
  }

  @override
  Future<void> createProject(Project project) async {
    await _local.insert('projects', _projectRow(project));
    for (var index = 0; index < defaultProjectStageNames.length; index++) {
      final now = DateTime.now();
      await _local.insert(
        'project_stages',
        _stageRow(
          ProjectStage(
            id: _id('stage_$index'),
            projectId: project.id,
            stageName: defaultProjectStageNames[index],
            stageOrder: index,
            assignedUser: project.technicalEngineer,
            createdAt: now,
            updatedAt: now,
          ),
        ),
      );
    }
    await addActivity(
      ProjectActivity(
        id: _id('activity'),
        projectId: project.id,
        activityType: ProjectActivityType.projectCreated,
        title: 'Đã tạo dự án',
        description: project.projectName,
        userId: project.projectManager,
        createdAt: project.createdAt,
      ),
    );
  }

  @override
  Future<void> updateProject(Project project) =>
      _local.update('projects', _projectRow(project), project.id);

  @override
  Future<void> deleteProject(String projectId) =>
      _local.deleteProject(projectId);

  @override
  Future<List<ProjectMachine>> getMachines(String projectId) async {
    final rows = await _local.query(
      'project_machines',
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: 'createdAt ASC',
    );
    return rows.map((row) => ProjectMachine.fromJson(_map(row))).toList();
  }

  @override
  Future<void> saveMachine(ProjectMachine machine) async {
    await _local.insert('project_machines', _machineRow(machine));
    await addActivity(
      ProjectActivity(
        id: _id('activity'),
        projectId: machine.projectId,
        machineId: machine.id,
        activityType: ProjectActivityType.machineAdded,
        title: 'Đã thêm máy ${machine.machineName}',
        description: '${machine.model} • S/N ${machine.serialNumber}',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> deleteMachine(String machineId) =>
      _local.deleteById('project_machines', machineId);

  @override
  Future<List<ProjectStage>> getStages(String projectId) async {
    final rows = await _local.query(
      'project_stages',
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: 'stageOrder ASC',
    );
    return rows.map((row) => ProjectStage.fromJson(_map(row))).toList();
  }

  @override
  Future<List<ProjectStage>> getAllStages() async {
    final rows = await _local.query(
      'project_stages',
      orderBy: 'projectId ASC, stageOrder ASC',
    );
    return rows.map((row) => ProjectStage.fromJson(_map(row))).toList();
  }

  @override
  Future<void> saveStage(ProjectStage stage) async {
    await _local.insert('project_stages', _stageRow(stage));
    await addActivity(
      ProjectActivity(
        id: _id('activity'),
        projectId: stage.projectId,
        stageId: stage.id,
        activityType: ProjectActivityType.stageUpdated,
        title: '${stage.stageName}: ${stage.status.label}',
        description: stage.notes,
        userId: stage.assignedUser,
        createdAt: DateTime.now(),
      ),
    );
    final stages = await getStages(stage.projectId);
    final project = await getProjectById(stage.projectId);
    if (project != null) {
      final completed = stages
          .where((item) => item.status == ProjectStageStatus.completed)
          .length;
      // Giai đoạn cuối cùng theo stageOrder (getStages đã sắp xếp tăng dần)
      // đóng vai trò "nghiệm thu" — không so tên chuỗi cố định, để không vỡ
      // khi đổi/thêm giai đoạn (VD: Schedule Project mở rộng 4 -> 6 bước).
      final lastIndex = stages.length - 1;
      final waitingAcceptance =
          lastIndex > 0 &&
          stages
              .take(lastIndex)
              .every((item) => item.status == ProjectStageStatus.completed) &&
          stages[lastIndex].status != ProjectStageStatus.completed;
      final status = completed == stages.length
          ? ProjectStatus.completed
          : waitingAcceptance
          ? ProjectStatus.waitingAcceptance
          : completed > 0 ||
                stages.any(
                  (item) => item.status == ProjectStageStatus.inProgress,
                )
          ? ProjectStatus.active
          : project.status;
      await updateProject(
        project.copyWith(
          status: status,
          syncStatus: SyncStatus.pending,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> addCustomStage(ProjectStage stage) => saveStage(stage);

  @override
  Future<List<ProjectStageSubmission>> getStageSubmissions(
    String projectId,
  ) async {
    final rows = await _local.query(
      'project_stage_submissions',
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: 'workDate DESC, confirmedAt DESC',
    );
    return rows.map((row) {
      final map = _map(row);
      map['data'] = Map<String, dynamic>.from(
        jsonDecode(map.remove('dataJson') as String) as Map,
      );
      return ProjectStageSubmission.fromJson(map);
    }).toList();
  }

  @override
  Future<void> saveStageSubmission(ProjectStageSubmission submission) async {
    await _local.insert(
      'project_stage_submissions',
      _submissionRow(submission),
    );
    await addActivity(
      ProjectActivity(
        id: _id('activity'),
        projectId: submission.projectId,
        machineId: submission.machineId,
        stageId: submission.stageId,
        activityType: ProjectActivityType.stageUpdated,
        title: submission.isFinalConfirmation
            ? 'Đã xác nhận hoàn thành ${_submissionLabel(submission.submissionType)}'
            : 'Đã cập nhật ${_submissionLabel(submission.submissionType)}',
        description: submission.isFinalConfirmation
            ? 'Thời điểm hoàn thành được ghi tự động.'
            : submission.result,
        userId: submission.confirmedBy,
        createdAt: submission.confirmedAt,
      ),
    );
  }

  String _submissionLabel(ProjectSubmissionType type) => switch (type) {
    ProjectSubmissionType.delivery => 'giao máy',
    ProjectSubmissionType.unpacking => 'khui thùng',
    ProjectSubmissionType.installation => 'lắp đặt',
    ProjectSubmissionType.acceptanceColorSorter => 'nghiệm thu máy tách màu',
    ProjectSubmissionType.acceptanceCompressor => 'nghiệm thu máy nén khí',
  };

  @override
  Future<List<ProjectChecklist>> getChecklists(String stageId) async {
    final rows = await _local.query(
      'project_checklists',
      where: 'stageId = ?',
      whereArgs: [stageId],
      orderBy: 'createdAt ASC',
    );
    return rows.map((row) => ProjectChecklist.fromJson(_map(row))).toList();
  }

  @override
  Future<void> saveChecklist(ProjectChecklist checklist) async {
    await _local.insert('project_checklists', _checklistRow(checklist));
    await addActivity(
      ProjectActivity(
        id: _id('activity'),
        projectId: checklist.projectId,
        machineId: checklist.machineId,
        stageId: checklist.stageId,
        activityType: ProjectActivityType.checklistUpdated,
        title: checklist.isCompleted
            ? 'Hoàn thành: ${checklist.title}'
            : 'Cập nhật checklist: ${checklist.title}',
        userId: checklist.completedBy,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> deleteChecklist(String checklistId) =>
      _local.deleteById('project_checklists', checklistId);

  @override
  Future<List<ProjectActivity>> getActivities(String projectId) async {
    final rows = await _local.query(
      'project_activities',
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: 'createdAt DESC',
    );
    return rows.map((row) {
      final map = _map(row);
      final raw = map['attachmentIds'] as String? ?? '';
      map['attachmentIds'] = raw.isEmpty
          ? <String>[]
          : List<String>.from(jsonDecode(raw) as List<dynamic>);
      return ProjectActivity.fromJson(map);
    }).toList();
  }

  @override
  Future<void> addActivity(ProjectActivity activity) =>
      _local.insert('project_activities', _activityRow(activity));

  @override
  Future<List<ProjectAttachment>> getAttachments(String projectId) async {
    final rows = await _local.query(
      'project_attachments',
      where: 'projectId = ?',
      whereArgs: [projectId],
      orderBy: 'createdAt DESC',
    );
    return rows.map((row) => ProjectAttachment.fromJson(_map(row))).toList();
  }

  @override
  Future<void> saveAttachment(ProjectAttachment attachment) async {
    final existing = await _local.query(
      'project_attachments',
      where: 'id = ?',
      whereArgs: [attachment.id],
    );
    await _local.insert('project_attachments', _attachmentRow(attachment));
    await addActivity(
      ProjectActivity(
        id: _id('activity'),
        projectId: attachment.projectId,
        machineId: attachment.machineId,
        stageId: attachment.stageId,
        activityType: ProjectActivityType.attachmentAdded,
        title: existing.isNotEmpty
            ? 'Đã cập nhật ảnh hiện trường'
            : attachment.fileType == ProjectFileType.photo
            ? 'Đã thêm ảnh hiện trường'
            : 'Đã thêm tài liệu',
        description: attachment.description,
        userId: attachment.createdBy,
        createdAt: attachment.createdAt,
        attachmentIds: [attachment.id],
      ),
    );
  }

  @override
  Future<void> deleteAttachment(String attachmentId) =>
      _local.deleteById('project_attachments', attachmentId);

  @override
  Future<ProjectAcceptance?> getAcceptance(String projectId) async {
    final rows = await _local.query(
      'project_acceptances',
      where: 'projectId = ?',
      whereArgs: [projectId],
    );
    return rows.isEmpty ? null : ProjectAcceptance.fromJson(_map(rows.first));
  }

  @override
  Future<void> saveAcceptance(ProjectAcceptance acceptance) async {
    await _local.insert('project_acceptances', _acceptanceRow(acceptance));
    await addActivity(
      ProjectActivity(
        id: _id('activity'),
        projectId: acceptance.projectId,
        machineId: acceptance.machineId,
        activityType: ProjectActivityType.acceptanceUpdated,
        title: 'Nghiệm thu: ${acceptance.status.label}',
        description: acceptance.notes,
        userId: acceptance.dtcRepresentative,
        createdAt: DateTime.now(),
      ),
    );
  }
}
