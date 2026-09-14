// Repository cho Cân Đóng Gói.
// Cung cấp các phương thức truy vấn dữ liệu từ SQLite database.
// Tất cả methods đều async và có error handling.

import '../core/database/packing_database.dart';
import '../models/packing_machine.dart';

class PackingMachineRepository {
  final PackingDatabase _dbHelper;

  PackingMachineRepository({PackingDatabase? dbHelper})
    : _dbHelper = dbHelper ?? PackingDatabase.instance;

  static const String _table = 'packing_machines';

  // ─── Read All ──────────────────────────────────────────────────────────────

  /// Lấy tất cả máy, sắp xếp theo stt
  Future<List<PackingMachine>> getAllMachines() async {
    final db = await _dbHelper.database;
    final rows = await db.query(_table, orderBy: 'stt ASC');
    return rows.map(PackingMachine.fromMap).toList();
  }

  // ─── Search ────────────────────────────────────────────────────────────────

  /// Tìm kiếm máy theo model name hoặc các trường text
  /// Hỗ trợ tìm partial: "LZB-600" tìm được "LZB-600-R10"
  Future<List<PackingMachine>> searchMachines(String query) async {
    if (query.trim().isEmpty) return getAllMachines();

    final db = await _dbHelper.database;
    final keyword = '%${query.trim().toUpperCase()}%';

    final rows = await db.rawQuery(
      '''
      SELECT * FROM $_table
      WHERE
        UPPER(model) LIKE ? OR
        UPPER(product_group) LIKE ? OR
        UPPER(machine_line) LIKE ? OR
        UPPER(materials) LIKE ? OR
        UPPER(notes) LIKE ?
      ORDER BY
        CASE WHEN UPPER(model) LIKE ? THEN 0 ELSE 1 END,
        stt ASC
      ''',
      [keyword, keyword, keyword, keyword, keyword, keyword],
    );

    return rows.map(PackingMachine.fromMap).toList();
  }

  // ─── Filter ────────────────────────────────────────────────────────────────

  /// Lấy máy theo nhóm sản phẩm (product_group)
  Future<List<PackingMachine>> getMachinesByGroup(String group) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      _table,
      where: 'product_group = ?',
      whereArgs: [group],
      orderBy: 'stt ASC',
    );
    return rows.map(PackingMachine.fromMap).toList();
  }

  /// Lấy máy theo dòng máy (machine_line)
  Future<List<PackingMachine>> getMachinesByLine(String line) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      _table,
      where: 'machine_line = ?',
      whereArgs: [line],
      orderBy: 'stt ASC',
    );
    return rows.map(PackingMachine.fromMap).toList();
  }

  /// Lấy máy theo vật liệu túi (bag_material: PE / PP)
  Future<List<PackingMachine>> getMachinesByBagMaterial(String material) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      _table,
      where: 'bag_material = ?',
      whereArgs: [material],
      orderBy: 'stt ASC',
    );
    return rows.map(PackingMachine.fromMap).toList();
  }

  // ─── Get Single ────────────────────────────────────────────────────────────

  /// Lấy một máy theo model name (exact match, case-insensitive)
  Future<PackingMachine?> getMachineByModel(String model) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      _table,
      where: 'UPPER(model) = UPPER(?)',
      whereArgs: [model],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PackingMachine.fromMap(rows.first);
  }

  /// Lấy nhiều máy theo danh sách model names
  Future<List<PackingMachine>> getMachinesByModels(List<String> models) async {
    if (models.isEmpty) return [];
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT * FROM $_table WHERE UPPER(model) IN (${models.map((_) => 'UPPER(?)').join(', ')})',
      models,
    );
    // Giữ đúng thứ tự theo danh sách input
    final machineMap = {
      for (final r in rows.map(PackingMachine.fromMap))
        r.model.toUpperCase(): r,
    };
    return models
        .map((m) => machineMap[m.toUpperCase()])
        .whereType<PackingMachine>()
        .toList();
  }

  // ─── Distinct Values (cho Filters & Catalog) ───────────────────────────────

  /// Lấy danh sách các nhóm sản phẩm duy nhất
  Future<List<String>> getDistinctProductGroups() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT product_group FROM $_table '
      'WHERE product_group IS NOT NULL '
      'ORDER BY stt ASC',
    );
    return rows
        .map((r) => r['product_group'] as String)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Lấy danh sách dòng máy duy nhất trong một nhóm
  Future<List<String>> getDistinctMachineLines(String productGroup) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT machine_line FROM $_table '
      'WHERE product_group = ? AND machine_line IS NOT NULL '
      'ORDER BY stt ASC',
      [productGroup],
    );
    return rows
        .map((r) => r['machine_line'] as String)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Lấy danh sách vật liệu túi duy nhất (PE, PP)
  Future<List<String>> getDistinctBagMaterials() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT bag_material FROM $_table '
      "WHERE bag_material IS NOT NULL AND bag_material != '' "
      'ORDER BY bag_material ASC',
    );
    return rows.map((r) => r['bag_material'] as String).toList();
  }

  /// Lấy danh sách kiểu túi (bag_edges) duy nhất
  Future<List<String>> getDistinctBagEdges() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT bag_edges FROM $_table '
      "WHERE bag_edges IS NOT NULL AND bag_edges != '' "
      'ORDER BY bag_edges ASC',
    );
    return rows.map((r) => r['bag_edges'] as String).toList();
  }

  /// Lấy danh sách mức độ tự động hóa duy nhất
  Future<List<String>> getDistinctAutomationLevels() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT automation_level FROM $_table '
      'WHERE automation_level IS NOT NULL '
      'ORDER BY automation_level ASC',
    );
    return rows.map((r) => r['automation_level'] as String).toList();
  }

  // ─── Advanced Filter (cho Machine Selector) ────────────────────────────────

  /// Lọc máy theo nhiều tiêu chí cơ bản (weight range)
  /// Trả về tất cả máy có khả năng phù hợp (để ranking service xử lý tiếp)
  Future<List<PackingMachine>> getMachinesForSelector({
    String? bagMaterial,
    double? weightKg,
  }) async {
    final db = await _dbHelper.database;

    final conditions = <String>[];
    final args = <dynamic>[];

    // Filter by bag material nếu có
    if (bagMaterial != null && bagMaterial.isNotEmpty) {
      conditions.add(
        "(bag_material = ? OR bag_material IS NULL OR bag_material = '')",
      );
      args.add(bagMaterial);
    }

    // Filter by weight range nếu có
    if (weightKg != null) {
      conditions.add(
        '((weight_min_kg IS NULL OR weight_min_kg <= ?) '
        'AND (weight_max_kg IS NULL OR weight_max_kg >= ?))',
      );
      args.addAll([weightKg, weightKg]);
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');

    final rows = await db.query(
      _table,
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'stt ASC',
    );
    return rows.map(PackingMachine.fromMap).toList();
  }
}
