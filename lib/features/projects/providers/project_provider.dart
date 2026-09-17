import 'package:flutter/foundation.dart';

import '../models/project.dart';
import '../models/project_acceptance.dart';
import '../models/project_activity.dart';
import '../models/project_attachment.dart';
import '../models/project_checklist.dart';
import '../models/project_machine.dart';
import '../models/project_stage.dart';
import '../models/project_stage_submission.dart';
import '../repositories/project_repository.dart';

class ProjectProvider extends ChangeNotifier {
  ProjectProvider(this._repository);
  final ProjectRepository _repository;

  List<Project> _projects = const [];
  Project? _currentProject;
  List<ProjectStage> _stages = const [];
  List<ProjectActivity> _activities = const [];
  List<ProjectAttachment> _attachments = const [];
  List<ProjectStageSubmission> _submissions = const [];
  ProjectAcceptance? _acceptance;
  final Map<String, List<ProjectChecklist>> _checklists = {};
  bool _isLoadingProjects = false;
  bool _isLoadingDetail = false;
  bool _isSaving = false;
  String? _error;

  List<Project> get projects => _projects;
  Project? get currentProject => _currentProject;
  List<ProjectStage> get stages => _stages;
  List<ProjectActivity> get activities => _activities;
  List<ProjectAttachment> get attachments => _attachments;
  List<ProjectStageSubmission> get submissions => _submissions;
  ProjectAcceptance? get acceptance => _acceptance;
  bool get isLoadingProjects => _isLoadingProjects;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get isSaving => _isSaving;
  String? get error => _error;
  List<ProjectChecklist> checklistsFor(String stageId) =>
      _checklists[stageId] ?? const [];

  Future<void> loadProjects() async {
    _isLoadingProjects = true;
    _error = null;
    notifyListeners();
    try {
      _projects = await _repository.getProjects();
    } catch (error) {
      _error = 'Không thể tải danh sách dự án: $error';
    } finally {
      _isLoadingProjects = false;
      notifyListeners();
    }
  }

  Future<void> loadProjectDetail(String id) async {
    _isLoadingDetail = true;
    _error = null;
    notifyListeners();
    try {
      await _reloadDetail(id);
    } catch (error) {
      _error = 'Không thể tải dự án: $error';
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  Future<void> _reloadDetail(String id) async {
    final projectChanged = _currentProject?.id != id;
    _currentProject = await _repository.getProjectById(id);
    if (_currentProject == null) throw StateError('Không tìm thấy dự án');
    final values = await Future.wait([
      _repository.getStages(id),
      _repository.getActivities(id),
      _repository.getAttachments(id),
      _repository.getAcceptance(id),
      _repository.getStageSubmissions(id),
    ]);
    _stages = values[0] as List<ProjectStage>;
    _activities = values[1] as List<ProjectActivity>;
    _attachments = values[2] as List<ProjectAttachment>;
    _acceptance = values[3] as ProjectAcceptance?;
    _submissions = values[4] as List<ProjectStageSubmission>;
    if (projectChanged) {
      _checklists.clear();
    }
  }

  Future<String?> createProject({
    required String projectName,
    required String machineModel,
    required String location,
    required String technicalEngineer,
  }) async {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final projectId = 'project_${now.microsecondsSinceEpoch}';
    final project = Project(
      id: projectId,
      projectName: projectName.trim(),
      customerName: '',
      projectCode:
          'DA-${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}',
      location: location.trim(),
      startDate: now,
      technicalEngineer: technicalEngineer.trim(),
      createdAt: now,
      updatedAt: now,
    );
    return _saving(() async {
      await _repository.createProject(project);
      await _repository.saveMachine(
        ProjectMachine(
          id: 'machine_${now.microsecondsSinceEpoch}',
          projectId: projectId,
          machineName: machineModel.trim(),
          model: machineModel.trim(),
          serialNumber: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await loadProjects();
      return project.id;
    });
  }

  Future<bool> deleteProject(String id) async =>
      (await _saving(() async {
        await _repository.deleteProject(id);
        _currentProject = null;
        await loadProjects();
        return true;
      })) ??
      false;

  Future<bool> saveMachine(ProjectMachine machine) async =>
      (await _saving(() async {
        await _repository.saveMachine(machine);
        await _reloadDetail(machine.projectId);
        return true;
      })) ??
      false;

  Future<bool> deleteMachine(ProjectMachine machine) async =>
      (await _saving(() async {
        await _repository.deleteMachine(machine.id);
        await _reloadDetail(machine.projectId);
        return true;
      })) ??
      false;

  Future<bool> saveStage(ProjectStage stage) async =>
      (await _saving(() async {
        await _repository.saveStage(stage);
        await _reloadDetail(stage.projectId);
        return true;
      })) ??
      false;

  Future<bool> addCustomStage(
    String projectId,
    String name,
    String assignedUser,
  ) async =>
      (await _saving(() async {
        final now = DateTime.now();
        await _repository.addCustomStage(
          ProjectStage(
            id: 'stage_${now.microsecondsSinceEpoch}',
            projectId: projectId,
            stageName: name.trim(),
            stageOrder: _stages.length,
            assignedUser: assignedUser.trim(),
            createdAt: now,
            updatedAt: now,
          ),
        );
        await _reloadDetail(projectId);
        return true;
      })) ??
      false;

  Future<void> loadChecklists(String stageId) async {
    _checklists[stageId] = await _repository.getChecklists(stageId);
    notifyListeners();
  }

  Future<bool> saveChecklist(ProjectChecklist checklist) async =>
      (await _saving(() async {
        await _repository.saveChecklist(checklist);
        _checklists[checklist.stageId] = await _repository.getChecklists(
          checklist.stageId,
        );
        _activities = await _repository.getActivities(checklist.projectId);
        return true;
      })) ??
      false;

  Future<bool> deleteChecklist(ProjectChecklist checklist) async =>
      (await _saving(() async {
        await _repository.deleteChecklist(checklist.id);
        _checklists[checklist.stageId] = await _repository.getChecklists(
          checklist.stageId,
        );
        return true;
      })) ??
      false;

  Future<bool> saveAttachment(ProjectAttachment attachment) async =>
      (await _saving(() async {
        await _repository.saveAttachment(attachment);
        await _reloadDetail(attachment.projectId);
        return true;
      })) ??
      false;

  List<ProjectAttachment> stagePhotos(String stageId, {String? category}) =>
      _attachments
          .where(
            (item) =>
                item.stageId == stageId &&
                item.fileType == ProjectFileType.photo &&
                (category == null || item.category == category),
          )
          .toList();

  List<ProjectStageSubmission> submissionsFor(String stageId) =>
      _submissions.where((item) => item.stageId == stageId).toList();

  Future<bool> setStageStart(ProjectStage stage, DateTime startDate) async =>
      (await _saving(() async {
        final now = DateTime.now();
        await _repository.saveStage(
          stage.copyWith(
            status: stage.status == ProjectStageStatus.completed
                ? ProjectStageStatus.completed
                : ProjectStageStatus.inProgress,
            startDate: startDate,
            syncStatus: SyncStatus.pending,
            updatedAt: now,
          ),
        );
        await _reloadDetail(stage.projectId);
        return true;
      })) ??
      false;

  Future<bool> saveDailyUpdate({
    required ProjectStage stage,
    required ProjectSubmissionType type,
    required DateTime workDate,
    required String result,
    required Map<String, dynamic> data,
    String? machineId,
    String confirmedBy = '',
  }) async =>
      (await _saving(() async {
        final now = DateTime.now();
        await _repository.saveStageSubmission(
          ProjectStageSubmission(
            id: 'submission_${now.microsecondsSinceEpoch}',
            projectId: stage.projectId,
            stageId: stage.id,
            machineId: machineId,
            submissionType: type,
            data: data,
            workDate: workDate,
            result: result.trim(),
            confirmedBy: confirmedBy.trim(),
            confirmedAt: now,
            createdAt: now,
            updatedAt: now,
            syncStatus: SyncStatus.pending,
          ),
        );
        await _reloadDetail(stage.projectId);
        return true;
      })) ??
      false;

  Future<bool> completeStage({
    required ProjectStage stage,
    required ProjectSubmissionType type,
    String? machineId,
    String confirmedBy = '',
  }) async =>
      (await _saving(() async {
        final now = DateTime.now();
        await _repository.saveStageSubmission(
          ProjectStageSubmission(
            id: 'submission_${now.microsecondsSinceEpoch}',
            projectId: stage.projectId,
            stageId: stage.id,
            machineId: machineId,
            submissionType: type,
            workDate: now,
            result: 'Hoàn thành giai đoạn',
            isFinalConfirmation: true,
            confirmedBy: confirmedBy.trim(),
            confirmedAt: now,
            createdAt: now,
            updatedAt: now,
            syncStatus: SyncStatus.pending,
          ),
        );
        await _repository.saveStage(
          stage.copyWith(
            status: ProjectStageStatus.completed,
            completedDate: now,
            assignedUser: confirmedBy.trim().isEmpty
                ? stage.assignedUser
                : confirmedBy.trim(),
            syncStatus: SyncStatus.pending,
            updatedAt: now,
          ),
        );
        await _reloadDetail(stage.projectId);
        return true;
      })) ??
      false;

  Future<bool> deleteAttachment(ProjectAttachment attachment) async =>
      (await _saving(() async {
        await _repository.deleteAttachment(attachment.id);
        await _reloadDetail(attachment.projectId);
        return true;
      })) ??
      false;

  Future<bool> saveAcceptance(ProjectAcceptance value) async =>
      (await _saving(() async {
        await _repository.saveAcceptance(value);
        await _reloadDetail(value.projectId);
        return true;
      })) ??
      false;

  Future<T?> _saving<T>(Future<T> Function() action) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      _error = 'Không thể lưu dữ liệu: $error';
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
