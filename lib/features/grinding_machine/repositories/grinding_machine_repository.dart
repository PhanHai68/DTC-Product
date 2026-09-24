import 'package:sqflite/sqflite.dart';

import '../data/grinding_machine_database.dart';
import '../models/grinding_ai_config.dart';
import '../models/grinding_extra_spec.dart';
import '../models/grinding_machine.dart';
import '../models/grinding_material.dart';
import '../models/grinding_material_series_map.dart';
import '../models/grinding_selection_tag.dart';
import '../models/grinding_series.dart';

/// Toàn bộ dữ liệu đã parse từ 1 lần import (Excel/JSON) — dùng để nạp/nạp
/// lại database qua [GrindingMachineRepository.importSnapshot]. Cùng 1 cấu
/// trúc này phục vụ cả file JSON seed đóng gói sẵn (Phase 1) lẫn import từ
/// Excel chọn trong app (Phase 5) — UI/Repository không cần biết dữ liệu đến
/// từ nguồn nào.
class GrindingDatabaseSnapshot {
  final String databaseVersion;
  final String? sourceDocument;
  final List<GrindingSeries> series;
  final List<GrindingMachine> machines;
  final List<GrindingExtraSpec> extraSpecs;
  final List<GrindingSelectionTag> selectionTags;
  final List<GrindingMaterial> materials;
  final List<GrindingMaterialSeriesMap> materialSeriesMap;
  final List<GrindingAiConfig> aiConfig;

  const GrindingDatabaseSnapshot({
    required this.databaseVersion,
    this.sourceDocument,
    required this.series,
    required this.machines,
    required this.extraSpecs,
    required this.selectionTags,
    required this.materials,
    required this.materialSeriesMap,
    required this.aiConfig,
  });
}

/// Repository duy nhất cho module "Máy nghiền" — UI/Provider KHÔNG được
/// truy vấn `GrindingMachineDatabase` trực tiếp, luôn đi qua đây.
class GrindingMachineRepository {
  GrindingMachineRepository({GrindingMachineDatabase? database})
    : _db = database ?? GrindingMachineDatabase.instance;

  final GrindingMachineDatabase _db;

  Map<String, dynamic> _map(Map<String, Object?> row) =>
      Map<String, dynamic>.from(row);

  // ---------------------------------------------------------------------
  // Import (Excel/JSON -> SQLite) — xem GrindingDatabaseSnapshot.
  // ---------------------------------------------------------------------

  /// Phiên bản database Excel đã import gần nhất (`null` nếu chưa import
  /// lần nào) — so sánh với version của file mới để biết có cần import lại.
  Future<String?> getImportedDatabaseVersion() async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_db_meta',
      where: 'key = ?',
      whereArgs: ['databaseVersion'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Nạp toàn bộ [snapshot] vào database, THAY THẾ HOÀN TOÀN dữ liệu catalog
  /// cũ (series/models/extra_specs/selection_tags/materials/
  /// material_series_map/ai_config) — vì đây là dữ liệu tham chiếu từ Excel
  /// (source of truth bên ngoài), không phải dữ liệu người dùng tự tạo, nên
  /// replace-all là đúng và an toàn hơn merge từng dòng. Chạy trong 1
  /// transaction để không bao giờ để database ở trạng thái nạp dở.
  Future<void> importSnapshot(GrindingDatabaseSnapshot snapshot) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      for (final table in const [
        'grinding_series',
        'grinding_machines',
        'grinding_extra_specs',
        'grinding_selection_tags',
        'grinding_materials',
        'grinding_material_series_map',
        'grinding_ai_config',
      ]) {
        await txn.delete(table);
      }

      final batch = txn.batch();
      for (final s in snapshot.series) {
        batch.insert('grinding_series', s.toJson());
      }
      for (final m in snapshot.machines) {
        batch.insert('grinding_machines', m.toJson());
      }
      for (final e in snapshot.extraSpecs) {
        batch.insert('grinding_extra_specs', e.toJson());
      }
      for (final t in snapshot.selectionTags) {
        batch.insert('grinding_selection_tags', t.toJson());
      }
      for (final mat in snapshot.materials) {
        batch.insert('grinding_materials', mat.toJson());
      }
      for (final map in snapshot.materialSeriesMap) {
        batch.insert('grinding_material_series_map', map.toJson());
      }
      for (final cfg in snapshot.aiConfig) {
        batch.insert('grinding_ai_config', cfg.toRow());
      }
      await batch.commit(noResult: true);

      // grinding_db_meta không bị xoá sạch ở bước trên (chỉ các bảng catalog
      // mới cần replace-all) — dùng `replace` để lần import sau ghi đè đúng
      // key thay vì đụng UNIQUE constraint.
      await txn.insert(
        'grinding_db_meta',
        {'key': 'databaseVersion', 'value': snapshot.databaseVersion},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (snapshot.sourceDocument != null) {
        await txn.insert(
          'grinding_db_meta',
          {'key': 'sourceDocument', 'value': snapshot.sourceDocument},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.insert(
        'grinding_db_meta',
        {'key': 'importedAt', 'value': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // ---------------------------------------------------------------------
  // Series
  // ---------------------------------------------------------------------

  Future<List<GrindingSeries>> getAllSeries() async {
    final db = await _db.database;
    final rows = await db.query('grinding_series', orderBy: 'displayCode ASC');
    return rows.map((row) => GrindingSeries.fromJson(_map(row))).toList();
  }

  Future<GrindingSeries?> getSeriesByCode(String seriesCode) async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_series',
      where: 'seriesCode = ?',
      whereArgs: [seriesCode],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GrindingSeries.fromJson(_map(rows.first));
  }

  // ---------------------------------------------------------------------
  // Machines
  // ---------------------------------------------------------------------

  Future<List<GrindingMachine>> getAllMachines({bool activeOnly = true}) async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_machines',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'seriesCode ASC, model ASC',
    );
    return rows.map((row) => GrindingMachine.fromJson(_map(row))).toList();
  }

  Future<List<GrindingMachine>> getMachinesBySeries(
    String seriesCode, {
    bool activeOnly = true,
  }) async {
    final db = await _db.database;
    final where = activeOnly
        ? 'seriesCode = ? AND active = 1'
        : 'seriesCode = ?';
    final rows = await db.query(
      'grinding_machines',
      where: where,
      whereArgs: [seriesCode],
      orderBy: 'model ASC',
    );
    return rows.map((row) => GrindingMachine.fromJson(_map(row))).toList();
  }

  Future<GrindingMachine?> getMachineById(String machineId) async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_machines',
      where: 'machineId = ?',
      whereArgs: [machineId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GrindingMachine.fromJson(_map(rows.first));
  }

  Future<GrindingMachine?> getMachineByModel(String model) async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_machines',
      where: 'model = ?',
      whereArgs: [model],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GrindingMachine.fromJson(_map(rows.first));
  }

  /// Tìm nhanh theo model/series/tên dòng máy — khớp một phần, không phân
  /// biệt hoa thường.
  Future<List<GrindingMachine>> searchMachines(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return getAllMachines();
    final db = await _db.database;
    final like = '%$trimmed%';
    final rows = await db.rawQuery(
      '''
      SELECT m.* FROM grinding_machines m
      LEFT JOIN grinding_series s ON s.seriesCode = m.seriesCode
      WHERE m.active = 1 AND (
        m.model LIKE ? COLLATE NOCASE
        OR m.seriesCode LIKE ? COLLATE NOCASE
        OR s.nameVi LIKE ? COLLATE NOCASE
        OR s.nameEn LIKE ? COLLATE NOCASE
        OR s.displayCode LIKE ? COLLATE NOCASE
      )
      ORDER BY m.seriesCode ASC, m.model ASC
      ''',
      [like, like, like, like, like],
    );
    return rows.map((row) => GrindingMachine.fromJson(_map(row))).toList();
  }

  // ---------------------------------------------------------------------
  // Extra specs / Selection tags
  // ---------------------------------------------------------------------

  Future<List<GrindingExtraSpec>> getExtraSpecs(String machineId) async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_extra_specs',
      where: 'machineId = ?',
      whereArgs: [machineId],
      orderBy: 'id ASC',
    );
    return rows.map((row) => GrindingExtraSpec.fromJson(_map(row))).toList();
  }

  Future<List<GrindingSelectionTag>> getSelectionTags(String seriesCode) async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_selection_tags',
      where: 'seriesCode = ?',
      whereArgs: [seriesCode],
      orderBy: 'tag ASC',
    );
    return rows
        .map((row) => GrindingSelectionTag.fromJson(_map(row)))
        .toList();
  }

  /// Toàn bộ tag duy nhất trong database — dùng để dựng danh sách filter
  /// Application mà KHÔNG hard-code trong UI.
  Future<List<String>> getAllDistinctTags() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT tag FROM grinding_selection_tags ORDER BY tag ASC',
    );
    return rows.map((row) => row['tag'] as String).toList();
  }

  /// Toàn bộ Selection Tags, gộp theo seriesCode — dùng 1 lần cho Selection
  /// Engine thay vì query riêng từng series.
  Future<Map<String, Set<String>>> getAllSelectionTagsGrouped() async {
    final db = await _db.database;
    final rows = await db.query('grinding_selection_tags');
    final grouped = <String, Set<String>>{};
    for (final row in rows) {
      final seriesCode = row['seriesCode'] as String;
      final tag = row['tag'] as String;
      (grouped[seriesCode] ??= {}).add(tag);
    }
    return grouped;
  }

  // ---------------------------------------------------------------------
  // Materials
  // ---------------------------------------------------------------------

  Future<List<GrindingMaterial>> getAllMaterials() async {
    final db = await _db.database;
    final rows = await db.query('grinding_materials', orderBy: 'nameVi ASC');
    return rows.map((row) => GrindingMaterial.fromJson(_map(row))).toList();
  }

  Future<GrindingMaterial?> getMaterialById(String materialId) async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_materials',
      where: 'materialId = ?',
      whereArgs: [materialId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GrindingMaterial.fromJson(_map(rows.first));
  }

  Future<List<GrindingMaterialSeriesMap>> getMaterialSeriesMapFor(
    String materialId,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_material_series_map',
      where: 'materialId = ?',
      whereArgs: [materialId],
    );
    return rows
        .map((row) => GrindingMaterialSeriesMap.fromJson(_map(row)))
        .toList();
  }

  // ---------------------------------------------------------------------
  // AI Config (trọng số Selection Engine)
  // ---------------------------------------------------------------------

  Future<List<GrindingAiConfig>> getAllAiConfig() async {
    final db = await _db.database;
    final rows = await db.query('grinding_ai_config');
    return rows.map((row) => GrindingAiConfig.fromRow(row)).toList();
  }

  Future<GrindingAiConfig?> getAiConfigByKey(String key) async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_ai_config',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GrindingAiConfig.fromRow(rows.first);
  }
}
