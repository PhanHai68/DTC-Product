import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../data/technical_dictionary_database.dart';
import '../models/technical_term.dart';

class TechnicalDictionaryRepository {
  TechnicalDictionaryRepository({
    TechnicalDictionaryDatabase? database,
    AssetBundle? bundle,
    DateTime Function()? now,
  }) : _database = database ?? TechnicalDictionaryDatabase.instance,
       _bundle = bundle ?? rootBundle,
       _now = now ?? DateTime.now;

  static const assetPath = 'assets/database/dictionary/technical_terms.json';
  static const _table = TechnicalDictionaryDatabase.progressTable;

  final TechnicalDictionaryDatabase _database;
  final AssetBundle _bundle;
  final DateTime Function() _now;

  /// Từ điển đọc từ asset thật, dùng chung cả app (thẻ "Từ vựng hôm nay" trên
  /// Home và màn Từ điển) để chỉ đọc, giải mã file ~600 KB một lần.
  static Future<TechnicalDictionaryData>? _shared;

  Future<TechnicalDictionaryData> loadDictionary() {
    if (!identical(_bundle, rootBundle)) return _read();
    return _shared ??= _read().catchError((Object e) {
      _shared = null; // Lần sau đọc lại.
      throw e;
    });
  }

  Future<TechnicalDictionaryData> _read() async {
    final raw = await _bundle.loadString(assetPath);
    return TechnicalDictionaryData.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  /// Chỉ dùng trong test: nạp sẵn dữ liệu dùng chung (null để xóa).
  @visibleForTesting
  static void debugSetSharedDictionary(TechnicalDictionaryData? data) =>
      _shared = data == null ? null : Future.value(data);

  /// Trạng thái học và ghi chú theo [TechnicalTerm.key].
  Future<Map<String, TermProgress>> loadProgress() async {
    final db = await _database.database;
    final rows = await db.query(_table);
    return {
      for (final row in rows)
        row['term_key'] as String: TermProgress(
          status: TermStatus.fromName(row['status'] as String?),
          note: row['note'] as String? ?? '',
        ),
    };
  }

  /// Lưu, hoặc xóa dòng khi không còn trạng thái lẫn ghi chú.
  Future<void> saveProgress(String termKey, TermProgress progress) async {
    final db = await _database.database;
    if (progress.isEmpty) {
      await db.delete(_table, where: 'term_key = ?', whereArgs: [termKey]);
      return;
    }
    await db.insert(_table, {
      'term_key': termKey,
      'status': progress.status?.name,
      'note': progress.note.trim(),
      'updated_at': _now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
