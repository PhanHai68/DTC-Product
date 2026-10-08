import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database_factory.dart'
    if (dart.library.io) '../../../core/database/local_database_factory_io.dart'
    if (dart.library.js_interop) '../../../core/database/local_database_factory_web.dart';

/// Database cục bộ `grain_analysis.db` của Phân tích mẫu AI — file riêng,
/// không chạm dữ liệu của các chức năng khác (NFR-08).
///
/// Lịch sử phiên bản:
/// - v1 (giai đoạn 1): phiên phân tích, hạt, kết quả, cài đặt.
///   Hồ sơ nguyên liệu, mẫu tham chiếu, lần sửa tay thêm ở giai đoạn 2
///   bằng migration lên v2.
class GrainAnalysisDatabase {
  GrainAnalysisDatabase._();
  static final GrainAnalysisDatabase instance = GrainAnalysisDatabase._();

  GrainAnalysisDatabase.forTesting(Database database) : _database = database;

  static const currentVersion = 1;

  Database? _database;

  Future<Database> get database async => _database ??= await openLocalDatabase(
    fileName: 'grain_analysis.db',
    version: currentVersion,
    onCreate: _create,
    onUpgrade: _upgrade,
  );

  static Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE sessions(
        id TEXT PRIMARY KEY,
        profile_id TEXT,
        mode TEXT NOT NULL CHECK(mode IN ('count', 'quick')),
        lot_code TEXT,
        sample_type TEXT NOT NULL
          CHECK(sample_type IN ('input', 'accept', 'reject', 'other')),
        sample_weight_g REAL,
        stream_weight_kg REAL,
        tray_id TEXT NOT NULL,
        image_paths TEXT NOT NULL,
        pixels_per_mm REAL,
        images_json TEXT NOT NULL,
        poor_quality INTEGER NOT NULL DEFAULT 0 CHECK(poor_quality IN (0, 1)),
        status TEXT NOT NULL CHECK(status IN ('draft', 'confirmed')),
        algorithm_version TEXT NOT NULL,
        created_by TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        note TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_grain_sessions_created ON sessions(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_grain_sessions_lot ON sessions(lot_code)',
    );
    await db.execute('''
      CREATE TABLE grains(
        session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        id TEXT NOT NULL,
        image_index INTEGER NOT NULL DEFAULT 0,
        contour TEXT NOT NULL,
        centroid_x REAL NOT NULL,
        centroid_y REAL NOT NULL,
        area_px REAL NOT NULL,
        length_px REAL NOT NULL DEFAULT 0,
        width_px REAL NOT NULL DEFAULT 0,
        length_mm REAL,
        width_mm REAL,
        area_mm2 REAL,
        mean_l REAL NOT NULL DEFAULT 0,
        mean_a REAL NOT NULL DEFAULT 0,
        mean_b REAL NOT NULL DEFAULT 0,
        feature_vector TEXT,
        predicted_class_id TEXT,
        confidence REAL,
        final_class_id TEXT,
        needs_review INTEGER NOT NULL DEFAULT 0,
        source TEXT NOT NULL DEFAULT 'auto' CHECK(source IN ('auto', 'manual')),
        removed INTEGER NOT NULL DEFAULT 0 CHECK(removed IN (0, 1)),
        estimated_count INTEGER NOT NULL DEFAULT 1 CHECK(estimated_count >= 1),
        PRIMARY KEY(session_id, id)
      )
    ''');
    await db.execute('''
      CREATE TABLE class_results(
        session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        class_id TEXT NOT NULL,
        grain_count INTEGER NOT NULL,
        count_percent REAL NOT NULL,
        area_percent REAL NOT NULL,
        est_weight_g REAL,
        weight_percent REAL,
        PRIMARY KEY(session_id, class_id)
      )
    ''');
  }

  static Future<void> _upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {}

  Future<void> createSchemaForTesting(Database db) =>
      _create(db, currentVersion);

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
