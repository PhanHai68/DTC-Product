import '../models/project.dart';
import '../models/project_acceptance.dart';
import '../models/project_activity.dart';
import '../models/project_attachment.dart';
import '../models/project_checklist.dart';
import '../models/project_machine.dart';
import '../models/project_stage.dart';
import '../models/project_stage_submission.dart';

abstract class ProjectRepository {
  Future<List<Project>> getProjects();
  Future<Project?> getProjectById(String id);
  Future<void> createProject(Project project);
  Future<void> updateProject(Project project);
  Future<void> deleteProject(String projectId);

  Future<List<ProjectMachine>> getMachines(String projectId);
  Future<void> saveMachine(ProjectMachine machine);
  Future<void> deleteMachine(String machineId);

  Future<List<ProjectStage>> getStages(String projectId);
  /// Toàn bộ giai đoạn của mọi dự án (dùng cho màn Lịch trình/Gantt) —
  /// nhóm theo projectId ở tầng gọi, tránh phải query từng dự án một.
  Future<List<ProjectStage>> getAllStages();
  Future<void> saveStage(ProjectStage stage);
  Future<void> addCustomStage(ProjectStage stage);
  Future<List<ProjectStageSubmission>> getStageSubmissions(String projectId);
  Future<void> saveStageSubmission(ProjectStageSubmission submission);

  Future<List<ProjectChecklist>> getChecklists(String stageId);
  Future<void> saveChecklist(ProjectChecklist checklist);
  Future<void> deleteChecklist(String checklistId);

  Future<List<ProjectActivity>> getActivities(String projectId);
  Future<void> addActivity(ProjectActivity activity);

  Future<List<ProjectAttachment>> getAttachments(String projectId);
  Future<void> saveAttachment(ProjectAttachment attachment);
  Future<void> deleteAttachment(String attachmentId);

  Future<ProjectAcceptance?> getAcceptance(String projectId);
  Future<void> saveAcceptance(ProjectAcceptance acceptance);
}
