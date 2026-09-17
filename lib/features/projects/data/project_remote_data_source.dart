import '../models/project.dart';
import '../models/project_acceptance.dart';
import '../models/project_activity.dart';
import '../models/project_attachment.dart';
import '../models/project_checklist.dart';
import '../models/project_machine.dart';
import '../models/project_stage.dart';
import '../models/project_stage_submission.dart';

/// Contract reserved for a future Firebase/Supabase implementation.
/// Presentation code depends on [ProjectRepository], never on a cloud SDK.
abstract class ProjectRemoteDataSource {
  Future<List<Project>> pullProjects({DateTime? updatedAfter});
  Future<void> pushProject(Project project);
  Future<void> pushMachine(ProjectMachine machine);
  Future<void> pushStage(ProjectStage stage);
  Future<void> pushChecklist(ProjectChecklist checklist);
  Future<void> pushActivity(ProjectActivity activity);
  Future<void> pushAttachment(ProjectAttachment attachment);
  Future<void> pushAcceptance(ProjectAcceptance acceptance);
  Future<void> pushStageSubmission(ProjectStageSubmission submission);
}
