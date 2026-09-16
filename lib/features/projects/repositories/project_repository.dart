import '../models/project.dart';
import '../models/project_log.dart';

abstract class ProjectRepository {
  Future<List<Project>> getProjects();
  Future<Project?> getProjectById(String id);
  Future<List<ProjectLog>> getProjectLogs(String projectId);
  
  // Future methods for Phase 2+
  Future<void> addProjectLog(ProjectLog log);
}
