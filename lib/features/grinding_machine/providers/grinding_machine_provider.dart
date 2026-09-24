import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/grinding_extra_spec.dart';
import '../models/grinding_machine.dart';
import '../models/grinding_series.dart';
import '../repositories/grinding_machine_repository.dart';
import '../services/grinding_machine_importer.dart';

/// Đường dẫn asset chứa dữ liệu seed (convert 1 lần từ file Excel
/// DTC_Grinding_Machine_Database_AI_Ready.xlsx) — xem README trong
/// assets/database/.
const _seedAssetPath = 'assets/database/grinding_machine_seed.json';

/// Quản lý dữ liệu module "Máy nghiền": tự seed database lần đầu mở màn
/// hình (hoặc khi file seed đóng gói có `databaseVersion` mới hơn bản đã
/// import), sau đó giữ danh sách series/model cho Home/Search/Series list.
class GrindingMachineProvider extends ChangeNotifier {
  GrindingMachineProvider({GrindingMachineRepository? repository})
    : _repository = repository ?? GrindingMachineRepository();

  final GrindingMachineRepository _repository;

  List<GrindingSeries> _series = const [];
  List<GrindingMachine> _machines = const [];
  bool _isLoading = false;
  String? _error;

  List<GrindingSeries> get series => _series;
  List<GrindingMachine> get machines => _machines;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<GrindingMachine> machinesOf(String seriesCode) =>
      _machines.where((m) => m.seriesCode == seriesCode).toList();

  int machineCountOf(String seriesCode) =>
      _machines.where((m) => m.seriesCode == seriesCode).length;

  /// Nạp dữ liệu cho Home: seed database nếu chưa có hoặc file seed đóng gói
  /// đã cập nhật phiên bản mới, sau đó đọc series + machines.
  Future<void> loadHome() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final seedJson = await rootBundle.loadString(_seedAssetPath);
      final snapshot = GrindingMachineImporter.parse(seedJson);
      final importedVersion = await _repository.getImportedDatabaseVersion();
      if (importedVersion != snapshot.databaseVersion) {
        await _repository.importSnapshot(snapshot);
      }
      _series = await _repository.getAllSeries();
      _machines = await _repository.getAllMachines();
    } catch (error) {
      _error = 'Không thể tải dữ liệu Máy nghiền: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<GrindingMachine>> search(String query) =>
      _repository.searchMachines(query);

  Future<GrindingMachine?> getMachine(String machineId) =>
      _repository.getMachineById(machineId);

  Future<GrindingSeries?> getSeries(String seriesCode) =>
      _repository.getSeriesByCode(seriesCode);

  Future<List<GrindingExtraSpec>> getExtraSpecs(String machineId) =>
      _repository.getExtraSpecs(machineId);
}
