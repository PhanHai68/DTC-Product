/// Provider quản lý state cho màn hình So Sánh Model.
/// Cho phép chọn 2-3 model để so sánh.
library;

import 'package:flutter/foundation.dart';

import '../models/packing_machine.dart';
import '../repositories/packing_machine_repository.dart';

class CompareProvider extends ChangeNotifier {
  final PackingMachineRepository _repository;

  CompareProvider({PackingMachineRepository? repository})
    : _repository = repository ?? PackingMachineRepository();

  static const int maxModels = 3;
  static const int minModels = 2;

  // ─── State ────────────────────────────────────────────────────────────────

  final List<PackingMachine> _selectedMachines = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ─── Getters ──────────────────────────────────────────────────────────────

  List<PackingMachine> get selectedMachines =>
      List.unmodifiable(_selectedMachines);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get canCompare => _selectedMachines.length >= minModels;
  bool get isFull => _selectedMachines.length >= maxModels;
  int get count => _selectedMachines.length;

  bool isSelected(String model) =>
      _selectedMachines.any((m) => m.model == model);

  // ─── Actions ──────────────────────────────────────────────────────────────

  /// Thêm máy vào danh sách so sánh
  Future<void> addMachine(String model) async {
    if (isSelected(model)) return;
    if (isFull) return;

    _isLoading = true;
    notifyListeners();

    try {
      final machine = await _repository.getMachineByModel(model);
      if (machine != null) {
        _selectedMachines.add(machine);
      }
    } catch (e) {
      _errorMessage = 'Lỗi thêm máy: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Thêm trực tiếp một PackingMachine object (khi đã có sẵn)
  void addMachineObject(PackingMachine machine) {
    if (isSelected(machine.model)) return;
    if (isFull) return;
    _selectedMachines.add(machine);
    notifyListeners();
  }

  /// Xóa máy khỏi danh sách so sánh
  void removeMachine(String model) {
    _selectedMachines.removeWhere((m) => m.model == model);
    notifyListeners();
  }

  /// Xóa tất cả
  void clearAll() {
    _selectedMachines.clear();
    _errorMessage = null;
    notifyListeners();
  }
}
