import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/engineer_profile.dart';
import '../models/fault_machine_model.dart';
import '../models/fault_record.dart';
import '../repositories/fault_bank_repository.dart';
import '../services/fault_photo_service.dart';
import '../utils/fault_groups.dart';

/// State của Ngân hàng lỗi — chỉ sống trong nhóm route `/fault-bank` (xem
/// app_routes.dart), không đăng ký toàn app.
class FaultBankProvider extends ChangeNotifier {
  FaultBankProvider({
    FaultBankRepository? repository,
    FaultPhotoService? photoService,
    this.searchDebounce = const Duration(milliseconds: 250),
  }) : _repository = repository ?? FaultBankRepository(),
       photoService = photoService ?? FaultPhotoService();

  final FaultBankRepository _repository;
  final FaultPhotoService photoService;
  final Duration searchDebounce;

  bool _isLoading = true;
  String? _error;
  EngineerProfile? _profile;
  List<FaultMachineModel> _machineModels = const [];
  List<String> _customGroups = const [];
  FaultSearchFilter _filter = const FaultSearchFilter();
  List<FaultRecordSummary> _results = const [];
  bool _isSearching = false;
  Timer? _debounce;
  int _searchToken = 0;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  EngineerProfile? get profile => _profile;
  bool get needsProfile => !_isLoading && _profile == null;
  List<FaultMachineModel> get machineModels => _machineModels;
  FaultSearchFilter get filter => _filter;
  List<FaultRecordSummary> get results => _results;
  bool get isSearching => _isSearching;

  /// Danh sách nhóm lỗi để chọn/lọc: cố định + tự thêm + "KHÁC".
  List<String> get groupOptions => FaultGroups.options(_customGroups);

  FaultMachineModel? machineModelById(String? id) {
    if (id == null) return null;
    for (final model in _machineModels) {
      if (model.id == id) return model;
    }
    return null;
  }

  Future<void> init() async {
    _isLoading = true;
    _error = null;
    _notify();
    try {
      _profile = await _repository.getProfile();
      await _reloadCatalogs();
      await _runSearch();
    } catch (error) {
      _error = 'Không mở được dữ liệu Ngân hàng lỗi: $error';
    }
    _isLoading = false;
    _notify();
  }

  // ---------------------------------------------------------------- Hồ sơ

  Future<void> saveProfile({
    required String engineerName,
    String? engineerCode,
  }) async {
    _profile = await _repository.saveProfile(
      engineerName: engineerName,
      engineerCode: engineerCode,
    );
    _notify();
  }

  // ------------------------------------------------------------ Dòng máy

  Future<FaultMachineModel?> findSimilarMachineModel(
    String name, {
    String? excludeId,
  }) => _repository.findSimilarMachineModel(name, excludeId: excludeId);

  Future<FaultMachineModel> addMachineModel({
    required String name,
    String? manufacturer,
    String? equipmentGroup,
  }) async {
    final model = await _repository.addMachineModel(
      name: name,
      manufacturer: manufacturer,
      equipmentGroup: equipmentGroup,
      engineerCode: _requireProfile().engineerCode,
    );
    await _reloadCatalogs();
    _notify();
    return model;
  }

  Future<void> updateMachineModel(FaultMachineModel model) async {
    await _repository.updateMachineModel(model);
    await _reloadCatalogs();
    await _runSearch();
  }

  Future<int> countRecordsOfModel(String id) =>
      _repository.countRecordsOfModel(id);

  Future<void> deleteMachineModel(String id) async {
    await _repository.deleteMachineModel(id);
    if (_filter.machineModelId == id) {
      _filter = _filter.copyWith(clearMachine: true);
    }
    await _reloadCatalogs();
    await _runSearch();
  }

  // ------------------------------------------------------------- Tra cứu

  void setQuery(String query) {
    _filter = _filter.copyWith(query: query);
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, _runSearch);
    _notify();
  }

  Future<void> setMachineFilter(String? id) {
    _filter = id == null
        ? _filter.copyWith(clearMachine: true)
        : _filter.copyWith(machineModelId: id);
    return _runSearch();
  }

  Future<void> setGroupFilter(String? group) {
    _filter = group == null
        ? _filter.copyWith(clearGroup: true)
        : _filter.copyWith(faultGroup: group);
    return _runSearch();
  }

  Future<void> setErrorCodeFilter(String? code) {
    _filter = (code == null || code.trim().isEmpty)
        ? _filter.copyWith(clearErrorCode: true)
        : _filter.copyWith(errorCode: code.trim());
    return _runSearch();
  }

  Future<void> clearFilters() {
    _filter = FaultSearchFilter(query: _filter.query);
    return _runSearch();
  }

  Future<List<FaultRecordSummary>> findSimilar(
    String symptom, {
    String? machineModelId,
    String? excludeId,
  }) => _repository.findSimilar(
    symptom,
    machineModelId: machineModelId,
    excludeId: excludeId,
  );

  // ------------------------------------------------------------- Bản ghi

  Future<FaultRecord?> getRecord(String id) => _repository.getRecord(id);

  /// Toàn bộ bản ghi khớp bộ lọc/từ khóa đang dùng ở Tra cứu.
  Future<List<FaultRecord>> recordsForExport() =>
      _repository.recordsForExport(_filter);

  Future<String> createRecord(
    FaultRecordDraft draft, {
    String? recordId,
  }) async {
    final id = await _repository.createRecord(
      draft,
      author: _requireProfile(),
      recordId: recordId,
    );
    await _afterWrite();
    return id;
  }

  Future<void> updateRecord(String id, FaultRecordDraft draft) async {
    final removedFiles = await _repository.updateRecord(id, draft);
    for (final fileName in removedFiles) {
      await photoService.storage.deletePhoto(fileName);
    }
    await _afterWrite();
  }

  /// Xóa bằng cờ. Ảnh giữ nguyên trên máy (bản ghi vẫn còn trong bảng).
  Future<void> deleteRecord(String id) async {
    await _repository.softDeleteRecord(id);
    await _afterWrite();
  }

  // ------------------------------------------------------------- Nội bộ

  EngineerProfile _requireProfile() {
    final profile = _profile;
    if (profile == null) throw StateError('Chưa có hồ sơ kỹ sư');
    return profile;
  }

  Future<void> _afterWrite() async {
    _customGroups = await _repository.customFaultGroups();
    await _runSearch();
  }

  Future<void> _reloadCatalogs() async {
    _machineModels = await _repository.listMachineModels();
    _customGroups = await _repository.customFaultGroups();
  }

  Future<void> _runSearch() async {
    final token = ++_searchToken;
    _isSearching = true;
    _notify();
    try {
      final results = await _repository.search(_filter);
      // Bỏ kết quả của lần tìm cũ nếu người dùng đã gõ tiếp.
      if (token != _searchToken) return;
      _results = results;
      _error = null;
    } catch (error) {
      if (token != _searchToken) return;
      _error = 'Không tìm kiếm được: $error';
    }
    _isSearching = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
