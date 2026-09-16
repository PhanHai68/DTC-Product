import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/project_log.dart';
import '../repositories/project_repository.dart';

class ProjectProvider extends ChangeNotifier {
  final ProjectRepository _repository;

  ProjectProvider(this._repository);

  List<Project> _projects = [];
  List<Project> get projects => _projects;

  bool _isLoadingProjects = false;
  bool get isLoadingProjects => _isLoadingProjects;

  String? _error;
  String? get error => _error;

  Project? _currentProject;
  Project? get currentProject => _currentProject;

  List<ProjectLog> _currentLogs = [];
  List<ProjectLog> get currentLogs => _currentLogs;

  bool _isLoadingDetail = false;
  bool get isLoadingDetail => _isLoadingDetail;

  Future<void> loadProjects() async {
    _isLoadingProjects = true;
    _error = null;
    notifyListeners();

    try {
      _projects = await _repository.getProjects();
    } catch (e) {
      _error = 'Failed to load projects: \$e';
    } finally {
      _isLoadingProjects = false;
      notifyListeners();
    }
  }

  Future<void> loadProjectDetail(String id) async {
    _isLoadingDetail = true;
    _currentProject = null;
    _currentLogs = [];
    _error = null;
    notifyListeners();

    try {
      _currentProject = await _repository.getProjectById(id);
      if (_currentProject != null) {
        _currentLogs = await _repository.getProjectLogs(id);
      } else {
        _error = 'Project not found';
      }
    } catch (e) {
      _error = 'Failed to load project details: \$e';
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }
}
