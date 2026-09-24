import 'package:sqflite/sqflite.dart';

import '../data/grinding_machine_database.dart';
import '../models/grinding_selection_project.dart';

/// Repository RIÊNG cho hồ sơ "chọn máy phù hợp" (Phase 7) — domain khác
/// catalog máy nghiền, dùng chung 1 database (`grinding_machines.db`) nhưng
/// chỉ đụng 2 bảng `grinding_selection_projects`/`grinding_selection_project_machines`,
/// KHÔNG bao giờ đọc/ghi bảng catalog (đó là việc của [GrindingMachineRepository]).
class GrindingSelectionProjectRepository {
  GrindingSelectionProjectRepository({GrindingMachineDatabase? database})
    : _db = database ?? GrindingMachineDatabase.instance;

  final GrindingMachineDatabase _db;

  Map<String, dynamic> _map(Map<String, Object?> row) =>
      Map<String, dynamic>.from(row);

  /// Lưu [project] mới + quan hệ máy (nếu có) trong CÙNG 1 transaction — nếu
  /// insert quan hệ lỗi thì project cũng KHÔNG được lưu (mục 16, "phải dùng
  /// transaction khi lưu project + machine relation").
  Future<int> createProject(
    GrindingSelectionProject project, {
    String? primaryMachineId,
    List<String> shortlistMachineIds = const [],
  }) async {
    final db = await _db.database;
    return db.transaction((txn) async {
      final id = await txn.insert(
        'grinding_selection_projects',
        project.toRow(),
      );
      await _replaceMachineRelations(
        txn,
        id,
        primaryMachineId: primaryMachineId,
        shortlistMachineIds: shortlistMachineIds,
      );
      return id;
    });
  }

  /// Cập nhật [project] đã có (`project.id` bắt buộc) + thay toàn bộ quan hệ
  /// máy bằng dữ liệu mới, cùng 1 transaction.
  Future<void> updateProject(
    GrindingSelectionProject project, {
    String? primaryMachineId,
    bool clearPrimaryMachine = false,
    List<String>? shortlistMachineIds,
  }) async {
    final id = project.id;
    if (id == null) {
      throw ArgumentError('updateProject yêu cầu project.id đã tồn tại.');
    }
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'grinding_selection_projects',
        project.toRow(),
        where: 'id = ?',
        whereArgs: [id],
      );
      if (primaryMachineId != null ||
          clearPrimaryMachine ||
          shortlistMachineIds != null) {
        final current = await _machinesForTxn(txn, id);
        await _replaceMachineRelations(
          txn,
          id,
          primaryMachineId: clearPrimaryMachine
              ? null
              : (primaryMachineId ?? current.primaryMachineId),
          shortlistMachineIds: shortlistMachineIds ?? current.shortlistMachineIds,
        );
      }
    });
  }

  Future<void> _replaceMachineRelations(
    Transaction txn,
    int projectId, {
    String? primaryMachineId,
    List<String> shortlistMachineIds = const [],
  }) async {
    await txn.delete(
      'grinding_selection_project_machines',
      where: 'projectId = ?',
      whereArgs: [projectId],
    );
    final now = DateTime.now().toIso8601String();
    final batch = txn.batch();
    if (primaryMachineId != null) {
      batch.insert('grinding_selection_project_machines', {
        'projectId': projectId,
        'machineId': primaryMachineId,
        'role': 'primary',
        'addedAt': now,
      });
    }
    for (final machineId in shortlistMachineIds) {
      batch.insert('grinding_selection_project_machines', {
        'projectId': projectId,
        'machineId': machineId,
        'role': 'shortlist',
        'addedAt': now,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<GrindingSelectionProject>> getAllProjects() async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_selection_projects',
      orderBy: 'updatedAt DESC',
    );
    return rows
        .map((row) => GrindingSelectionProject.fromRow(_map(row)))
        .toList();
  }

  Future<GrindingSelectionProject?> getProject(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_selection_projects',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GrindingSelectionProject.fromRow(_map(rows.first));
  }

  Future<GrindingProjectMachines> getProjectMachines(int projectId) async {
    final db = await _db.database;
    return _machinesForTxn(db, projectId);
  }

  Future<GrindingProjectMachines> _machinesForTxn(
    DatabaseExecutor executor,
    int projectId,
  ) async {
    final rows = await executor.query(
      'grinding_selection_project_machines',
      where: 'projectId = ?',
      whereArgs: [projectId],
    );
    String? primary;
    final shortlist = <String>[];
    for (final row in rows) {
      final machineId = row['machineId'] as String;
      if (row['role'] == 'primary') {
        primary = machineId;
      } else {
        shortlist.add(machineId);
      }
    }
    return GrindingProjectMachines(
      primaryMachineId: primary,
      shortlistMachineIds: shortlist,
    );
  }

  /// TOÀN BỘ quan hệ project<->machine (mọi project) — dùng cho Backup
  /// (Phase 11) để export nguyên vẹn bảng quan hệ, không qua aggregate
  /// [GrindingProjectMachines]. Chỉ trả 4 field cần cho restore
  /// (`projectId`/`machineId`/`role`/`addedAt`) — `id` tự sinh lại khi
  /// insert, không có gì tham chiếu ngược vào nó nên không cần giữ.
  Future<List<Map<String, Object?>>> getAllProjectMachineRelations() async {
    final db = await _db.database;
    final rows = await db.query(
      'grinding_selection_project_machines',
      columns: ['projectId', 'machineId', 'role', 'addedAt'],
      orderBy: 'projectId ASC, id ASC',
    );
    return rows.map(_map).toList();
  }

  Future<void> deleteProject(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'grinding_selection_project_machines',
        where: 'projectId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'grinding_selection_projects',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}
