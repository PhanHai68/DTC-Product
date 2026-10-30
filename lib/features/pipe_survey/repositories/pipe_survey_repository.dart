import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/pipe_survey_database.dart';
import '../models/pipe_survey.dart';

/// Dòng tóm tắt trong danh sách khảo sát.
class PipeSurveySummary {
  const PipeSurveySummary({
    required this.id,
    required this.name,
    required this.customer,
    required this.usePoints,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String customer;
  final int usePoints;
  final DateTime updatedAt;
}

class PipeSurveyRepository {
  PipeSurveyRepository({PipeSurveyDatabase? database})
    : _database = database ?? PipeSurveyDatabase.instance;

  final PipeSurveyDatabase _database;

  Future<Database> get _db => _database.database;

  /// Danh sách mới sửa trước; [query] lọc theo tên công trình / khách hàng.
  Future<List<PipeSurveySummary>> list({String query = ''}) async {
    final db = await _db;
    final q = query.trim().toLowerCase();
    final rows = await db.query(
      'pipe_surveys',
      where: q.isEmpty ? null : 'LOWER(name) LIKE ? OR LOWER(customer) LIKE ?',
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%'],
      orderBy: 'updatedAt DESC',
    );
    return [
      for (final row in rows)
        PipeSurveySummary(
          id: row['id'] as String,
          name: row['name'] as String,
          customer: row['customer'] as String,
          usePoints: _decode(row['json'] as String)?.usePoints.length ?? 0,
          updatedAt:
              DateTime.tryParse(row['updatedAt'] as String) ?? DateTime(2000),
        ),
    ];
  }

  Future<PipeSurvey?> get(String id) async {
    final db = await _db;
    final rows = await db.query(
      'pipe_surveys',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _decode(rows.first['json'] as String);
  }

  Future<void> save(PipeSurvey survey) async {
    final db = await _db;
    survey.updatedAt = DateTime.now();
    await db.insert('pipe_surveys', {
      'id': survey.id,
      'name': survey.name.trim(),
      'customer': survey.customer.trim(),
      'json': jsonEncode(survey.toJson()),
      'createdAt': survey.createdAt.toIso8601String(),
      'updatedAt': survey.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('pipe_surveys', where: 'id = ?', whereArgs: [id]);
  }

  PipeSurvey? _decode(String json) {
    try {
      return PipeSurvey.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
