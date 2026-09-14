/// Provider cho màn hình Machine Selector.
/// Quản lý form input, dropdown options, và kết quả ranking.

import 'package:flutter/foundation.dart';

import '../models/machine_match_result.dart';
import '../models/machine_selector_request.dart';
import '../repositories/packing_machine_repository.dart';
import '../services/machine_selector_service.dart';

class MachineSelectorProvider extends ChangeNotifier {
  final MachineSelectorService _selectorService;
  final PackingMachineRepository _repository;

  MachineSelectorProvider({
    MachineSelectorService? selectorService,
    PackingMachineRepository? repository,
  }) : _selectorService = selectorService ?? MachineSelectorService(),
       _repository = repository ?? PackingMachineRepository();

  // ─── State ────────────────────────────────────────────────────────────────

  // Form values
  String? _selectedBagMaterial;
  String? _selectedBagEdges;
  String? _selectedAutomationLevel;
  double? _requestedWeightKg;
  double? _requestedCapacity;
  String? _selectedCapacityUnit;

  // Options for dropdowns (loaded from DB)
  List<String> _bagMaterials = [];
  List<String> _bagEdges = [];
  List<String> _automationLevels = [];

  // Results
  List<MachineMatchResult> _results = [];
  bool _hasSearched = false;
  bool _isSearching = false;
  String? _errorMessage;

  // ─── Getters ──────────────────────────────────────────────────────────────

  String? get selectedBagMaterial => _selectedBagMaterial;
  String? get selectedBagEdges => _selectedBagEdges;
  String? get selectedAutomationLevel => _selectedAutomationLevel;
  double? get requestedWeightKg => _requestedWeightKg;
  double? get requestedCapacity => _requestedCapacity;
  String? get selectedCapacityUnit => _selectedCapacityUnit;

  List<String> get bagMaterials => _bagMaterials;
  List<String> get bagEdges => _bagEdges;
  List<String> get automationLevels => _automationLevels;

  List<MachineMatchResult> get results => _results;
  bool get hasSearched => _hasSearched;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;

  // Chỉ hiển thị kết quả phù hợp (không phải NOT SUITABLE) trừ khi tất cả đều không phù hợp
  List<MachineMatchResult> get suitableResults =>
      _results.where((r) => r.matchLevel != MatchLevel.notSuitable).toList();

  List<MachineMatchResult> get notSuitableResults =>
      _results.where((r) => r.matchLevel == MatchLevel.notSuitable).toList();

  // ─── Actions ──────────────────────────────────────────────────────────────

  /// Tải options cho dropdown từ database
  Future<void> loadOptions() async {
    try {
      final results = await Future.wait([
        _repository.getDistinctBagMaterials(),
        _repository.getDistinctBagEdges(),
        _repository.getDistinctAutomationLevels(),
      ]);
      _bagMaterials = results[0];
      _bagEdges = results[1];
      _automationLevels = results[2];
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi tải dữ liệu: $e';
      notifyListeners();
    }
  }

  // ── Setters ───────────────────────────────────────────────────────────────

  void setBagMaterial(String? value) {
    _selectedBagMaterial = value;
    // Giữ tiêu chí kiểu túi người dùng đã chọn. Hai tiêu chí được đánh giá
    // độc lập để ứng dụng có thể giải thích rõ tổ hợp nào chưa có dữ liệu.
    notifyListeners();
  }

  void setBagEdges(String? value) {
    _selectedBagEdges = value;
    notifyListeners();
  }

  void setAutomationLevel(String? value) {
    _selectedAutomationLevel = value;
    notifyListeners();
  }

  void setWeightKg(double? value) {
    _requestedWeightKg = value;
    notifyListeners();
  }

  void setCapacity(double? value) {
    _requestedCapacity = value;
    notifyListeners();
  }

  void setCapacityUnit(String? value) {
    _selectedCapacityUnit = value;
    notifyListeners();
  }

  void resetForm() {
    _selectedBagMaterial = null;
    _selectedBagEdges = null;
    _selectedAutomationLevel = null;
    _requestedWeightKg = null;
    _requestedCapacity = null;
    _selectedCapacityUnit = null;
    _results = [];
    _hasSearched = false;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  /// Thực hiện tìm máy phù hợp
  Future<void> findMachines() async {
    _isSearching = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = MachineSelectorRequest(
        bagMaterial: _selectedBagMaterial,
        bagEdges: _selectedBagEdges,
        automationLevel: _selectedAutomationLevel,
        requestedWeightKg: _requestedWeightKg,
        requestedCapacity: _requestedCapacity,
        capacityUnit: _selectedCapacityUnit,
      );

      _results = await _selectorService.findSuitableMachines(request);
      _hasSearched = true;
    } catch (e) {
      _errorMessage = 'Lỗi tìm kiếm: $e';
      _results = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }
}
