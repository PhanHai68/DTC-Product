import 'package:flutter/foundation.dart';

import '../models/grinding_selection_project.dart';
import '../repositories/grinding_selection_project_repository.dart';

/// Quản lý danh sách hồ sơ "chọn máy phù hợp" (Phase 7) — provider RIÊNG
/// với [GrindingMachineProvider] (domain project khác domain catalog máy).
/// Giữ tối giản: chỉ cache list + CRUD qua Repository, không có logic chấm
/// điểm/import (đã có ở GrindingMachineProvider/GrindingMachineSelectionService).
class GrindingSelectionProjectProvider extends ChangeNotifier {
  GrindingSelectionProjectProvider({GrindingSelectionProjectRepository? repository})
    : _repository = repository ?? GrindingSelectionProjectRepository();

  final GrindingSelectionProjectRepository _repository;

  List<GrindingSelectionProject> _projects = const [];
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  List<GrindingSelectionProject> get projects => _projects;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    _notify();
    try {
      _projects = await _repository.getAllProjects();
    } catch (error) {
      _error = 'Không thể tải danh sách dự án: $error';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<int> createProject(
    GrindingSelectionProject project, {
    String? primaryMachineId,
    List<String> shortlistMachineIds = const [],
  }) async {
    final id = await _repository.createProject(
      project,
      primaryMachineId: primaryMachineId,
      shortlistMachineIds: shortlistMachineIds,
    );
    await loadAll();
    return id;
  }

  Future<void> updateProject(
    GrindingSelectionProject project, {
    String? primaryMachineId,
    bool clearPrimaryMachine = false,
    List<String>? shortlistMachineIds,
  }) async {
    await _repository.updateProject(
      project,
      primaryMachineId: primaryMachineId,
      clearPrimaryMachine: clearPrimaryMachine,
      shortlistMachineIds: shortlistMachineIds,
    );
    await loadAll();
  }

  Future<void> deleteProject(int id) async {
    await _repository.deleteProject(id);
    await loadAll();
  }

  Future<GrindingSelectionProject?> getProject(int id) =>
      _repository.getProject(id);

  Future<GrindingProjectMachines> getProjectMachines(int id) =>
      _repository.getProjectMachines(id);
}
