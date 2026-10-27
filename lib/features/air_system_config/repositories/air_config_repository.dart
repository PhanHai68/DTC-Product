import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/air_config_database.dart';
import '../models/air_config.dart';

/// Dòng tóm tắt trong danh sách cấu hình đã lưu.
class AirConfigSummary {
  const AirConfigSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.lineCount,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final CompressorType type;
  final int lineCount;
  final DateTime updatedAt;
}

class AirConfigRepository {
  AirConfigRepository({AirConfigDatabase? database})
    : _database = database ?? AirConfigDatabase.instance;

  final AirConfigDatabase _database;

  Future<Database> get _db => _database.database;

  /// Danh sách mới sửa trước; [query] lọc theo tên dự án.
  Future<List<AirConfigSummary>> list({String query = ''}) async {
    final db = await _db;
    final q = query.trim().toLowerCase();
    final rows = await db.query(
      'air_configs',
      where: q.isEmpty ? null : 'LOWER(name) LIKE ?',
      whereArgs: q.isEmpty ? null : ['%$q%'],
      orderBy: 'updatedAt DESC',
    );
    return [
      for (final row in rows)
        () {
          final config = _decode(row['json'] as String);
          return AirConfigSummary(
            id: row['id'] as String,
            name: row['name'] as String,
            type: config?.compressor.type ?? CompressorType.pmVsd,
            lineCount: config?.lines.length ?? 0,
            updatedAt:
                DateTime.tryParse(row['updatedAt'] as String) ?? DateTime(2000),
          );
        }(),
    ];
  }

  Future<AirConfig?> get(String id) async {
    final db = await _db;
    final rows = await db.query(
      'air_configs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _decode(rows.first['json'] as String);
  }

  Future<void> save(AirConfig config) async {
    final db = await _db;
    config.updatedAt = DateTime.now();
    await db.insert('air_configs', {
      'id': config.id,
      'name': config.project.name.trim(),
      'json': jsonEncode(config.toJson()),
      'createdAt': config.createdAt.toIso8601String(),
      'updatedAt': config.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AirConfig?> duplicate(String id, {required String suffix}) async {
    final original = await get(id);
    if (original == null) return null;
    final copy = original.duplicate(
      name: '${original.project.name} $suffix'.trim(),
    );
    await save(copy);
    return copy;
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('air_configs', where: 'id = ?', whereArgs: [id]);
  }

  static AirConfig? _decode(String json) {
    try {
      return AirConfig.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
