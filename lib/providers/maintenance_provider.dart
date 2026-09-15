import 'package:flutter/foundation.dart';

import '../core/database/local_database.dart';
import '../models/maintenance_record.dart';

class MaintenanceProvider extends ChangeNotifier {
  final LocalDatabase _db = LocalDatabase.instance;

  List<MaintenanceRecord> _records = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _errorMessage;

  List<MaintenanceRecord> get records => _records;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get errorMessage => _errorMessage;

  List<MaintenanceRecord> get filteredRecords {
    if (_searchQuery.isEmpty) return _records;
    final lowerQuery = _searchQuery.toLowerCase();
    return _records.where((record) {
      return record.customerName.toLowerCase().contains(lowerQuery) ||
          record.machineModel.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadRecords() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _records = await _db.getAllMaintenanceRecords();
    } catch (e) {
      _errorMessage = 'Không thể đọc dữ liệu bảo trì trên thiết bị.';
      debugPrint('Error loading maintenance records: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addRecord(MaintenanceRecord record) async {
    await _db.insertMaintenanceRecord(record);
    await _refreshRecords();
  }

  Future<void> updateRecord(MaintenanceRecord record) async {
    await _db.updateMaintenanceRecord(record);
    await _refreshRecords();
  }

  Future<void> deleteRecord(int id) async {
    await _db.deleteMaintenanceRecord(id);
    await _refreshRecords();
  }

  /// Khách hàng bảo trì xong, thiết lập lại chu kỳ bảo trì
  Future<void> completeMaintenance(MaintenanceRecord record) async {
    final now = DateTime.now();
    final nextDate = addCalendarMonths(now, record.maintenanceCycleMonths);
    final updated = record.copyWith(nextMaintenanceDate: nextDate);
    await updateRecord(updated);
  }

  Future<void> _refreshRecords() async {
    _errorMessage = null;
    _records = await _db.getAllMaintenanceRecords();
    notifyListeners();
  }
}
