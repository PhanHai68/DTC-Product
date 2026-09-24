import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database_factory.dart'
    if (dart.library.io) '../../../core/database/local_database_factory_io.dart'
    if (dart.library.js_interop) '../../../core/database/local_database_factory_web.dart';

/// Database riêng cho module "Máy nghiền" (Grinding Machine) — tách khỏi
/// database của các feature khác, theo đúng khuôn mẫu
/// `MaintenanceReportDatabase`/`ProjectDatabase`. Dữ liệu trong các bảng này
/// LUÔN được nạp từ file Excel/JSON nguồn (xem `GrindingMachineImporter`),
/// KHÔNG được ghi tay thông số kỹ thuật vào đây.
class GrindingMachineDatabase {
  GrindingMachineDatabase._();
  static final GrindingMachineDatabase instance = GrindingMachineDatabase._();

  /// Bọc quanh 1 Database đã mở sẵn (VD sqflite_common_ffi in-memory) — chỉ
  /// dùng cho test.
  GrindingMachineDatabase.forTesting(Database database) : _database = database;

  Database? _database;

  Future<Database> get database async {
    _database ??= await openLocalDatabase(
      fileName: 'grinding_machines.db',
      version: 1,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _database!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE grinding_series(
        seriesCode TEXT PRIMARY KEY,
        displayCode TEXT NOT NULL DEFAULT '',
        nameVi TEXT NOT NULL DEFAULT '',
        nameEn TEXT NOT NULL DEFAULT '',
        technology TEXT NOT NULL DEFAULT '',
        pdfPages TEXT NOT NULL DEFAULT '',
        applicationVi TEXT NOT NULL DEFAULT '',
        workingPrincipleVi TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE grinding_machines(
        machineId TEXT PRIMARY KEY,
        seriesCode TEXT NOT NULL,
        model TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        pdfPage INTEGER,
        capacityMinKgH REAL,
        capacityMaxKgH REAL,
        inputSizeMaxMm REAL,
        inputSizeNote TEXT,
        finenessMin REAL,
        finenessMax REAL,
        finenessUnit TEXT,
        mainMotorKwMin REAL,
        mainMotorKwMax REAL,
        speedRpmMin REAL,
        speedRpmMax REAL,
        lengthMm REAL,
        widthMm REAL,
        heightMm REAL,
        weightKg REAL,
        sourceDocument TEXT,
        editNote TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_grinding_machines_series ON grinding_machines(seriesCode)',
    );
    await db.execute(
      'CREATE INDEX idx_grinding_machines_model ON grinding_machines(model)',
    );

    await db.execute('''
      CREATE TABLE grinding_extra_specs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        machineId TEXT NOT NULL,
        specKey TEXT NOT NULL,
        specValueNumber REAL,
        specValueText TEXT,
        unit TEXT,
        sourcePdfPage INTEGER,
        note TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_grinding_extra_specs_machine ON grinding_extra_specs(machineId)',
    );

    await db.execute('''
      CREATE TABLE grinding_selection_tags(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        seriesCode TEXT NOT NULL,
        tag TEXT NOT NULL,
        note TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_grinding_selection_tags_series ON grinding_selection_tags(seriesCode)',
    );
    await db.execute(
      'CREATE INDEX idx_grinding_selection_tags_tag ON grinding_selection_tags(tag)',
    );

    await db.execute('''
      CREATE TABLE grinding_materials(
        materialId TEXT PRIMARY KEY,
        nameVi TEXT NOT NULL DEFAULT '',
        nameEn TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT '',
        hardness TEXT,
        fibrous INTEGER,
        oily INTEGER,
        stickyOrPaste INTEGER,
        wet INTEGER,
        heatSensitive INTEGER,
        brittle INTEGER,
        crystalline INTEGER,
        sourceCandidateSeries TEXT,
        sourceBasis TEXT,
        status TEXT NOT NULL DEFAULT 'Needs validation',
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE grinding_material_series_map(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        materialId TEXT NOT NULL,
        seriesCode TEXT NOT NULL,
        scoreAdjustment REAL NOT NULL DEFAULT 0,
        basisType TEXT,
        reasonVi TEXT,
        sourceBasis TEXT,
        status TEXT NOT NULL DEFAULT 'Needs validation'
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_grinding_material_series_map_material ON grinding_material_series_map(materialId)',
    );
    await db.execute(
      'CREATE INDEX idx_grinding_material_series_map_series ON grinding_material_series_map(seriesCode)',
    );

    await db.execute('''
      CREATE TABLE grinding_ai_config(
        key TEXT PRIMARY KEY,
        value TEXT,
        unit TEXT,
        category TEXT,
        description TEXT,
        editable INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Key-value nhỏ lưu databaseVersion/sourceDocument của lần import gần
    // nhất — dùng để biết khi nào cần import lại sau khi thay Excel/JSON.
    await db.execute('''
      CREATE TABLE grinding_db_meta(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    // Chưa có phiên bản cũ nào để migrate — để sẵn cho các lần nâng schema
    // sau này (thêm cột/bảng mới khi database Excel mở rộng).
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Tạo schema hiện tại trên 1 database cô lập dùng cho test.
  Future<void> createSchemaForTesting(Database db) => _create(db, 1);

  /// Chạy migration trên 1 database cô lập dùng cho test.
  Future<void> upgradeSchemaForTesting(
    Database db,
    int oldVersion,
    int newVersion,
  ) => _upgrade(db, oldVersion, newVersion);
}
