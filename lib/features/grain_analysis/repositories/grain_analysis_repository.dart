import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../data/grain_analysis_database.dart';
import '../models/analysis_session.dart';
import '../models/grain.dart';

/// Đọc/ghi phiên phân tích trong `grain_analysis.db`.
class GrainAnalysisRepository {
  GrainAnalysisRepository({GrainAnalysisDatabase? database})
    : _database = database ?? GrainAnalysisDatabase.instance;

  final GrainAnalysisDatabase _database;

  static const operatorKey = 'operator_name';
  static const trayKey = 'tray_id';

  // ------------------------------------------------------------ Cài đặt

  Future<String?> getSetting(String key) async {
    final db = await _database.database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _database.database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ------------------------------------------------------------- Phiên

  Future<List<AnalysisSessionSummary>> listSessions({int limit = 200}) async {
    final db = await _database.database;
    final rows = await db.query(
      'sessions',
      columns: [
        'id',
        'mode',
        'lot_code',
        'sample_type',
        'status',
        'poor_quality',
        'created_at',
        'created_by',
      ],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    if (rows.isEmpty) return const [];
    final ids = [for (final r in rows) r['id'] as String];
    final resultRows = await db.query(
      'class_results',
      where: 'session_id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final bySession = <String, List<ClassResult>>{};
    for (final r in resultRows) {
      (bySession[r['session_id'] as String] ??= []).add(_resultFromRow(r));
    }
    return [
      for (final r in rows)
        AnalysisSessionSummary(
          id: r['id'] as String,
          mode: AnalysisMode.byName(r['mode'] as String?),
          lotCode: r['lot_code'] as String?,
          sampleType: SampleType.byName(r['sample_type'] as String?),
          status: SessionStatus.byName(r['status'] as String?),
          poorQuality: r['poor_quality'] == 1,
          createdAt: DateTime.parse(r['created_at'] as String),
          createdBy: r['created_by'] as String,
          results: bySession[r['id']] ?? const [],
        ),
    ];
  }

  Future<AnalysisSession?> getSession(String id) async {
    final db = await _database.database;
    final rows = await db.query('sessions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    final grainRows = await db.query(
      'grains',
      where: 'session_id = ?',
      whereArgs: [id],
    );
    final resultRows = await db.query(
      'class_results',
      where: 'session_id = ?',
      whereArgs: [id],
    );
    final images = [
      for (final j in jsonDecode(r['images_json'] as String) as List)
        SessionImage.fromJson((j as Map).cast<String, Object?>()),
    ];
    return AnalysisSession(
      id: id,
      profileId: r['profile_id'] as String?,
      mode: AnalysisMode.byName(r['mode'] as String?),
      lotCode: r['lot_code'] as String?,
      sampleType: SampleType.byName(r['sample_type'] as String?),
      sampleWeightG: (r['sample_weight_g'] as num?)?.toDouble(),
      streamWeightKg: (r['stream_weight_kg'] as num?)?.toDouble(),
      trayId: r['tray_id'] as String,
      images: images,
      grains: [for (final g in grainRows) _grainFromRow(g)]
        ..sort((a, b) => _grainOrder(a.id).compareTo(_grainOrder(b.id))),
      results: [for (final row in resultRows) _resultFromRow(row)],
      status: SessionStatus.byName(r['status'] as String?),
      algorithmVersion: r['algorithm_version'] as String,
      createdBy: r['created_by'] as String,
      createdAt: DateTime.parse(r['created_at'] as String),
      updatedAt: DateTime.parse(r['updated_at'] as String),
      note: r['note'] as String?,
    );
  }

  /// Ghi cả phiên (tạo mới hoặc thay toàn bộ hạt + kết quả).
  Future<void> saveSession(AnalysisSession s) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert(
        'sessions',
        _sessionRow(s),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('grains', where: 'session_id = ?', whereArgs: [s.id]);
      final batch = txn.batch();
      for (final g in s.grains) {
        batch.insert('grains', _grainRow(s.id, g));
      }
      await batch.commit(noResult: true);
      await _replaceResults(txn, s);
    });
  }

  /// Ghi các hạt vừa sửa tay và kết quả mới — nhanh hơn [saveSession].
  Future<void> saveEdits(
    AnalysisSession s, {
    required List<Grain> upserted,
    List<String> deletedIds = const [],
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      for (final id in deletedIds) {
        await txn.delete(
          'grains',
          where: 'session_id = ? AND id = ?',
          whereArgs: [s.id, id],
        );
      }
      for (final g in upserted) {
        await txn.insert(
          'grains',
          _grainRow(s.id, g),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.update(
        'sessions',
        {'status': s.status.name, 'updated_at': s.updatedAt.toIso8601String()},
        where: 'id = ?',
        whereArgs: [s.id],
      );
      await _replaceResults(txn, s);
    });
  }

  Future<void> deleteSession(String id) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete('grains', where: 'session_id = ?', whereArgs: [id]);
      await txn.delete(
        'class_results',
        where: 'session_id = ?',
        whereArgs: [id],
      );
      await txn.delete('sessions', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> _replaceResults(Transaction txn, AnalysisSession s) async {
    await txn.delete(
      'class_results',
      where: 'session_id = ?',
      whereArgs: [s.id],
    );
    for (final r in s.results) {
      await txn.insert('class_results', {
        'session_id': s.id,
        'class_id': r.classId,
        'grain_count': r.grainCount,
        'count_percent': r.countPercent,
        'area_percent': r.areaPercent,
        'est_weight_g': r.estWeightG,
        'weight_percent': r.weightPercent,
      });
    }
  }

  // ---------------------------------------------------------- Chuyển đổi

  static Map<String, Object?> _sessionRow(AnalysisSession s) => {
    'id': s.id,
    'profile_id': s.profileId,
    'mode': s.mode.name,
    'lot_code': s.lotCode,
    'sample_type': s.sampleType.name,
    'sample_weight_g': s.sampleWeightG,
    'stream_weight_kg': s.streamWeightKg,
    'tray_id': s.trayId,
    'image_paths': jsonEncode(s.imagePaths),
    'pixels_per_mm': s.pixelsPerMm,
    'images_json': jsonEncode([for (final i in s.images) i.toJson()]),
    'poor_quality': s.poorQuality ? 1 : 0,
    'status': s.status.name,
    'algorithm_version': s.algorithmVersion,
    'created_by': s.createdBy,
    'created_at': s.createdAt.toIso8601String(),
    'updated_at': s.updatedAt.toIso8601String(),
    'note': s.note,
  };

  static Map<String, Object?> _grainRow(String sessionId, Grain g) => {
    'session_id': sessionId,
    'id': g.id,
    'image_index': g.imageIndex,
    'contour': encodeContour(g.contour),
    'centroid_x': g.centroidX,
    'centroid_y': g.centroidY,
    'area_px': g.areaPx,
    'length_px': g.lengthPx,
    'width_px': g.widthPx,
    'length_mm': g.lengthMm,
    'width_mm': g.widthMm,
    'area_mm2': g.areaMm2,
    'mean_l': g.meanColorLab[0],
    'mean_a': g.meanColorLab[1],
    'mean_b': g.meanColorLab[2],
    'feature_vector': g.featureVector.isEmpty
        ? null
        : jsonEncode(g.featureVector),
    'predicted_class_id': g.predictedClassId,
    'confidence': g.confidence,
    'final_class_id': g.finalClassId,
    'needs_review': g.needsReview ? 1 : 0,
    'source': g.source.name,
    'removed': g.removed ? 1 : 0,
    'estimated_count': g.estimatedCount,
  };

  static Grain _grainFromRow(Map<String, Object?> r) => Grain(
    id: r['id'] as String,
    imageIndex: r['image_index'] as int,
    contour: decodeContour(r['contour'] as String),
    centroidX: (r['centroid_x'] as num).toDouble(),
    centroidY: (r['centroid_y'] as num).toDouble(),
    areaPx: (r['area_px'] as num).toDouble(),
    lengthPx: (r['length_px'] as num).toDouble(),
    widthPx: (r['width_px'] as num).toDouble(),
    lengthMm: (r['length_mm'] as num?)?.toDouble(),
    widthMm: (r['width_mm'] as num?)?.toDouble(),
    areaMm2: (r['area_mm2'] as num?)?.toDouble(),
    meanColorLab: [
      (r['mean_l'] as num).toDouble(),
      (r['mean_a'] as num).toDouble(),
      (r['mean_b'] as num).toDouble(),
    ],
    featureVector: r['feature_vector'] == null
        ? const []
        : [
            for (final v in jsonDecode(r['feature_vector'] as String) as List)
              (v as num).toDouble(),
          ],
    predictedClassId: r['predicted_class_id'] as String?,
    confidence: (r['confidence'] as num?)?.toDouble(),
    finalClassId: r['final_class_id'] as String?,
    needsReview: r['needs_review'] == 1,
    source: r['source'] == 'manual' ? GrainSource.manual : GrainSource.auto,
    removed: r['removed'] == 1,
    estimatedCount: r['estimated_count'] as int,
  );

  static ClassResult _resultFromRow(Map<String, Object?> r) => ClassResult(
    classId: r['class_id'] as String,
    grainCount: r['grain_count'] as int,
    countPercent: (r['count_percent'] as num).toDouble(),
    areaPercent: (r['area_percent'] as num).toDouble(),
    estWeightG: (r['est_weight_g'] as num?)?.toDouble(),
    weightPercent: (r['weight_percent'] as num?)?.toDouble(),
  );

  /// Mã id hạt dạng `i<ảnh>-<số>` hoặc `i<ảnh>-m<số>` → khóa sắp xếp ổn định.
  static String _grainOrder(String id) {
    final m = RegExp(r'^i(\d+)-(m?)(\d+)$').firstMatch(id);
    if (m == null) return id;
    return '${m[1]!.padLeft(3, '0')}${m[2]!.isEmpty ? 'a' : 'b'}'
        '${m[3]!.padLeft(8, '0')}';
  }

  /// Đường viền lưu gọn: "x,y x,y ..." làm tròn 0,1 px.
  static String encodeContour(List<double> pts) {
    final sb = StringBuffer();
    for (var i = 0; i + 1 < pts.length; i += 2) {
      if (i > 0) sb.write(' ');
      sb
        ..write(_fmt(pts[i]))
        ..write(',')
        ..write(_fmt(pts[i + 1]));
    }
    return sb.toString();
  }

  static String _fmt(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  }

  static List<double> decodeContour(String text) {
    if (text.isEmpty) return const [];
    final out = <double>[];
    for (final pair in text.split(' ')) {
      final xy = pair.split(',');
      out
        ..add(double.parse(xy[0]))
        ..add(double.parse(xy[1]));
    }
    return out;
  }
}
