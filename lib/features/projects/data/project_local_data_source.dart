import 'package:sqflite/sqflite.dart';

import 'project_database.dart';

class ProjectLocalDataSource {
  const ProjectLocalDataSource({Database? database})
    : _overrideDatabase = database;

  final Database? _overrideDatabase;

  Future<Database> get _db async =>
      _overrideDatabase ?? await ProjectDatabase.instance.database;

  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    final db = await _db;
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
  }

  Future<void> insert(String table, Map<String, Object?> values) async {
    final db = await _db;
    await db.insert(
      table,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(
    String table,
    Map<String, Object?> values,
    String id,
  ) async {
    final db = await _db;
    await db.update(table, values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteProject(String projectId) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final table in const [
        'project_checklists',
        'project_attachments',
        'project_activities',
        'project_acceptances',
        'project_stage_submissions',
        'project_stages',
        'project_machines',
      ]) {
        await txn.delete(table, where: 'projectId = ?', whereArgs: [projectId]);
      }
      await txn.delete('projects', where: 'id = ?', whereArgs: [projectId]);
    });
  }

  Future<void> deleteById(String table, String id) async {
    final db = await _db;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}
