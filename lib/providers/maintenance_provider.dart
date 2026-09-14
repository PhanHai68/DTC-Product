import 'package:flutter/foundation.dart';
import '../core/database/local_database.dart';
import '../models/maintenance_record.dart';

class MaintenanceProvider extends ChangeNotifier {
  final LocalDatabase _db = LocalDatabase.instance;
  
  List<MaintenanceRecord> _records = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<MaintenanceRecord> get records => _records;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

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
    notifyListeners();

    try {
      _records = await _db.getAllMaintenanceRecords();
    } catch (e) {
      debugPrint('Error loading maintenance records: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addRecord(MaintenanceRecord record) async {
    await _db.insertMaintenanceRecord(record);
    await loadRecords();
  }

  Future<void> updateRecord(MaintenanceRecord record) async {
    await _db.updateMaintenanceRecord(record);
    await loadRecords();
  }

  Future<void> deleteRecord(int id) async {
    await _db.deleteMaintenanceRecord(id);
    await loadRecords();
  }

  /// Khách hàng bảo trì xong, thiết lập lại chu kỳ bảo trì
  Future<void> completeMaintenance(MaintenanceRecord record) async {
    final now = DateTime.now();
    final nextDate = DateTime(
      now.year,
      now.month + record.maintenanceCycleMonths,
      now.day,
    );
    final updated = record.copyWith(nextMaintenanceDate: nextDate);
    await updateRecord(updated);
  }
}
