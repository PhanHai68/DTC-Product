// Repository cho Cân Đóng Gói.
// Truy vấn trên danh sách máy đọc từ assets/database/packing_scale/machines.json
// (nạp sẵn bởi ProductData). Giữ API async như thời còn dùng SQLite để màn
// hình và provider không phải đổi.

import '../data/product_data.dart';
import '../models/packing_machine.dart';

class PackingMachineRepository {
  /// [machines] chỉ dùng cho test; mặc định lấy toàn bộ máy trong JSON.
  PackingMachineRepository({List<PackingMachine>? machines})
    : _machinesOverride = machines;

  final List<PackingMachine>? _machinesOverride;

  /// Danh sách máy đã sắp theo stt.
  List<PackingMachine> get _machines => _machinesOverride ?? packingMachines;

  // ─── Read All ──────────────────────────────────────────────────────────────

  /// Lấy tất cả máy, sắp xếp theo stt
  Future<List<PackingMachine>> getAllMachines() async => List.of(_machines);

  // ─── Search ────────────────────────────────────────────────────────────────

  /// Tìm kiếm máy theo model name hoặc các trường text, không phân biệt hoa
  /// thường. Hỗ trợ tìm partial: "LZB-600" tìm được "LZB-600-R10".
  /// Máy khớp theo model được xếp lên trước.
  Future<List<PackingMachine>> searchMachines(String query) async {
    if (query.trim().isEmpty) return getAllMachines();

    final keyword = query.trim().toUpperCase();
    bool contains(String? value) =>
        value != null && value.toUpperCase().contains(keyword);

    final matches = _machines.where(
      (m) =>
          contains(m.model) ||
          contains(m.productGroup) ||
          contains(m.machineLine) ||
          contains(m.materials) ||
          contains(m.notes),
    );
    return [
      ...matches.where((m) => contains(m.model)),
      ...matches.where((m) => !contains(m.model)),
    ];
  }

  // ─── Filter ────────────────────────────────────────────────────────────────

  /// Lấy máy theo nhóm sản phẩm (product_group)
  Future<List<PackingMachine>> getMachinesByGroup(String group) async =>
      _machines.where((m) => m.productGroup == group).toList();

  /// Lấy máy theo dòng máy (machine_line)
  Future<List<PackingMachine>> getMachinesByLine(String line) async =>
      _machines.where((m) => m.machineLine == line).toList();

  /// Lấy máy theo vật liệu túi (bag_material: PE / PP)
  Future<List<PackingMachine>> getMachinesByBagMaterial(
    String material,
  ) async => _machines.where((m) => m.bagMaterial == material).toList();

  // ─── Get Single ────────────────────────────────────────────────────────────

  /// Lấy một máy theo model name (exact match, case-insensitive)
  Future<PackingMachine?> getMachineByModel(String model) async {
    final key = model.toUpperCase();
    for (final machine in _machines) {
      if (machine.model.toUpperCase() == key) return machine;
    }
    return null;
  }

  /// Lấy nhiều máy theo danh sách model names, giữ đúng thứ tự đầu vào
  Future<List<PackingMachine>> getMachinesByModels(List<String> models) async {
    if (models.isEmpty) return [];
    final machineMap = {for (final m in _machines) m.model.toUpperCase(): m};
    return models
        .map((m) => machineMap[m.toUpperCase()])
        .whereType<PackingMachine>()
        .toList();
  }

  // ─── Distinct Values (cho Filters & Catalog) ───────────────────────────────

  /// Lấy danh sách các nhóm sản phẩm duy nhất, theo thứ tự stt
  Future<List<String>> getDistinctProductGroups() async =>
      _distinctInOrder(_machines.map((m) => m.productGroup));

  /// Lấy danh sách dòng máy duy nhất trong một nhóm, theo thứ tự stt
  Future<List<String>> getDistinctMachineLines(String productGroup) async =>
      _distinctInOrder(
        _machines
            .where((m) => m.productGroup == productGroup)
            .map((m) => m.machineLine),
      );

  /// Lấy danh sách vật liệu túi duy nhất (PE, PP), theo bảng chữ cái
  Future<List<String>> getDistinctBagMaterials() async =>
      _distinctSorted(_machines.map((m) => m.bagMaterial));

  /// Lấy danh sách kiểu túi (bag_edges) duy nhất, theo bảng chữ cái
  Future<List<String>> getDistinctBagEdges() async =>
      _distinctSorted(_machines.map((m) => m.bagEdges));

  /// Lấy danh sách mức độ tự động hóa duy nhất, theo bảng chữ cái
  Future<List<String>> getDistinctAutomationLevels() async =>
      _distinctSorted(_machines.map((m) => m.automationLevel));

  // ─── Advanced Filter (cho Machine Selector) ────────────────────────────────

  /// Lọc máy theo nhiều tiêu chí cơ bản (weight range)
  /// Trả về tất cả máy có khả năng phù hợp (để ranking service xử lý tiếp)
  Future<List<PackingMachine>> getMachinesForSelector({
    String? bagMaterial,
    double? weightKg,
  }) async {
    return _machines.where((m) {
      // Máy không ghi vật liệu túi được coi là dùng được cho mọi loại túi.
      if (bagMaterial != null && bagMaterial.isNotEmpty) {
        final material = m.bagMaterial;
        if (material != null &&
            material.isNotEmpty &&
            material != bagMaterial) {
          return false;
        }
      }
      if (weightKg != null) {
        if (m.weightMinKg != null && m.weightMinKg! > weightKg) return false;
        if (m.weightMaxKg != null && m.weightMaxKg! < weightKg) return false;
      }
      return true;
    }).toList();
  }

  // ─── Helper ────────────────────────────────────────────────────────────────

  static List<String> _distinctInOrder(Iterable<String?> values) =>
      values.whereType<String>().where((s) => s.isNotEmpty).toSet().toList();

  static List<String> _distinctSorted(Iterable<String?> values) =>
      _distinctInOrder(values)..sort();
}
