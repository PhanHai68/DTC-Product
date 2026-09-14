/// Provider quản lý state cho module Cân Đóng Gói.
/// Xử lý: load tất cả máy, search với debounce, load theo nhóm.
library;

import 'package:flutter/foundation.dart';

import '../models/packing_machine.dart';
import '../repositories/packing_machine_repository.dart';

class PackingProvider extends ChangeNotifier {
  final PackingMachineRepository _repository;

  PackingProvider({PackingMachineRepository? repository})
    : _repository = repository ?? PackingMachineRepository();

  // ─── State ────────────────────────────────────────────────────────────────

  List<PackingMachine> _machines = [];
  List<PackingMachine> _searchResults = [];
  List<String> _productGroups = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;
  String _searchQuery = '';

  // ─── Getters ──────────────────────────────────────────────────────────────

  List<PackingMachine> get machines => _machines;
  List<PackingMachine> get searchResults => _searchResults;
  List<String> get productGroups => _productGroups;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  bool get hasError => _errorMessage != null;
  bool get isEmpty => !_isLoading && _machines.isEmpty;

  // ─── Actions ──────────────────────────────────────────────────────────────

  /// Tải tất cả máy và danh mục (gọi khi vào màn hình packing menu)
  Future<void> loadAll() async {
    if (_isLoading) return;
    _setLoading(true);
    _clearError();

    try {
      final results = await Future.wait([
        _repository.getAllMachines(),
        _repository.getDistinctProductGroups(),
      ]);

      _machines = results[0] as List<PackingMachine>;
      _productGroups = results[1] as List<String>;
      _searchResults = List.from(_machines);
    } catch (e) {
      _errorMessage = 'Lỗi tải dữ liệu: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Tìm kiếm máy (được gọi sau debounce)
  Future<void> search(String query) async {
    _searchQuery = query;

    if (query.trim().isEmpty) {
      _searchResults = List.from(_machines);
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await _repository.searchMachines(query);
    } catch (e) {
      _errorMessage = 'Lỗi tìm kiếm: $e';
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Xóa search và reset về tất cả
  void clearSearch() {
    _searchQuery = '';
    _searchResults = List.from(_machines);
    notifyListeners();
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}
