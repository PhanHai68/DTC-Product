import 'package:sqflite/sqflite.dart';

import 'project_database.dart';

class ProjectLocalDataSource {
  const ProjectLocalDataSource({Database? database})
    : _overrideDatabase = database,
      _executor = null;

  const ProjectLocalDataSource._transaction(DatabaseExecutor executor)
    : _executor = executor,
      _overrideDatabase = null;

  final Database? _overrideDatabase;
  final DatabaseExecutor? _executor;

  Future<DatabaseExecutor> get _db async =>
      _executor ?? _overrideDatabase ?? await ProjectDatabase.instance.database;

  Future<T> transaction<T>(
    Future<T> Function(ProjectLocalDataSource local) action,
  ) async {
    if (_executor != null) return action(this);
    final db = _overrideDatabase ?? await ProjectDatabase.instance.database;
    return db.transaction(
      (txn) => action(ProjectLocalDataSource._transaction(txn)),
    );
  }

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
    await transaction((local) async {
      final txn = await local._db;
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
