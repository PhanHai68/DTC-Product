import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database_factory.dart'
    if (dart.library.io) '../../../core/database/local_database_factory_io.dart'
    if (dart.library.js_interop) '../../../core/database/local_database_factory_web.dart';

/// Database riêng cho "Báo cáo bảo trì" (Maintenance Report) — tách khỏi
/// `user_data.db` vì có nhiều bảng con liên quan tới 1 report (items, ảnh,
/// checklist, phụ tùng, thông số, activity log), theo đúng khuôn mẫu
/// `ProjectDatabase`. KHÔNG liên quan tới bảng `maintenance_records` (tính
/// năng "Nhắc Nhở Lịch Bảo Trì" đã có sẵn) — tên bảng ở đây đều có tiền tố
/// `maintenance_` khác (reports/items/photos/...) để không đụng nhau.
class MaintenanceReportDatabase {
  MaintenanceReportDatabase._();
  static final MaintenanceReportDatabase instance =
      MaintenanceReportDatabase._();

  /// Bọc quanh 1 Database đã mở sẵn (VD sqflite_common_ffi in-memory) — chỉ
  /// dùng cho test, tránh phải mở file thật trên đĩa.
  MaintenanceReportDatabase.forTesting(Database database)
    : _database = database;

  Database? _database;

  Future<Database> get database async {
    _database ??= await openLocalDatabase(
      fileName: 'maintenance_reports.db',
      version: 3,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _database!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE maintenance_reports(
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        customerName TEXT NOT NULL DEFAULT '',
        factorySite TEXT NOT NULL DEFAULT '',
        machineModel TEXT NOT NULL DEFAULT '',
        machineTagName TEXT NOT NULL DEFAULT '',
        machineRunningHours TEXT NOT NULL DEFAULT '',
        maintenanceDate TEXT NOT NULL,
        engineerNames TEXT NOT NULL DEFAULT '[]',
        sessionId TEXT,
        startTime TEXT,
        endTime TEXT,
        machineCondition TEXT NOT NULL DEFAULT '',
        overallResult TEXT,
        finalComment TEXT NOT NULL DEFAULT '',
        recommendation TEXT NOT NULL DEFAULT '',
        nextMaintenanceDate TEXT,
        nextMaintenanceRunningHours TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_maintenance_reports_updated ON maintenance_reports(updatedAt DESC)',
    );
    await db.execute('''
      CREATE TABLE maintenance_items(
        id TEXT PRIMARY KEY,
        reportId TEXT NOT NULL,
        name TEXT NOT NULL,
        orderIndex INTEGER NOT NULL DEFAULT 0,
        beforeFinding TEXT NOT NULL DEFAULT '',
        actionTaken TEXT NOT NULL DEFAULT '',
        afterResult TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'normal',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_maintenance_items_report ON maintenance_items(reportId, orderIndex)',
    );
    await db.execute('''
      CREATE TABLE maintenance_photos(
        id TEXT PRIMARY KEY,
        reportId TEXT NOT NULL,
        itemId TEXT,
        kind TEXT NOT NULL,
        sequence INTEGER NOT NULL,
        originalPath TEXT NOT NULL,
        reportPath TEXT NOT NULL,
        sha256 TEXT NOT NULL,
        verified INTEGER NOT NULL DEFAULT 1,
        capturedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_maintenance_photos_report ON maintenance_photos(reportId, kind, sequence)',
    );
    await db.execute(
      'CREATE INDEX idx_maintenance_photos_item ON maintenance_photos(itemId)',
    );
    await db.execute('''
      CREATE TABLE maintenance_checklist(
        id TEXT PRIMARY KEY,
        reportId TEXT NOT NULL,
        label TEXT NOT NULL,
        isChecked INTEGER NOT NULL DEFAULT 0,
        orderIndex INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_maintenance_checklist_report ON maintenance_checklist(reportId, orderIndex)',
    );
    await db.execute('''
      CREATE TABLE maintenance_parts(
        id TEXT PRIMARY KEY,
        reportId TEXT NOT NULL,
        partName TEXT NOT NULL,
        partNumber TEXT NOT NULL DEFAULT '',
        quantity REAL NOT NULL DEFAULT 1,
        unit TEXT NOT NULL DEFAULT 'pcs',
        note TEXT NOT NULL DEFAULT '',
        orderIndex INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_maintenance_parts_report ON maintenance_parts(reportId, orderIndex)',
    );
    await db.execute('''
      CREATE TABLE maintenance_activity_log(
        id TEXT PRIMARY KEY,
        reportId TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        message TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_maintenance_activity_report ON maintenance_activity_log(reportId, timestamp)',
    );
  }

  /// v2: đơn giản hoá cột của `maintenance_reports` (bỏ contactPerson/
  /// contactPhone/machineName/machineType/machineSerial/machineLocation,
  /// thêm machineTagName, đổi engineerName (String) thành engineerNames
  /// (JSON array)) và bỏ cột isCustom của `maintenance_checklist`. Tính
  /// năng này chưa từng phát hành rộng rãi (chỉ mới cài bản thử nghiệm),
  /// nên xoá sạch dữ liệu cũ và tạo lại theo schema mới thay vì viết
  /// migration ánh xạ từng cột — tránh vướng vì bản v1 cũ có domain dữ
  /// liệu không map 1-1 sang schema mới (VD Serial/Location không có chỗ
  /// tương ứng ở Tagname).
  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      for (final table in const [
        'maintenance_reports',
        'maintenance_items',
        'maintenance_photos',
        'maintenance_checklist',
        'maintenance_parts',
        'maintenance_parameters',
        'maintenance_activity_log',
        'maintenance_counters',
      ]) {
        await db.execute('DROP TABLE IF EXISTS $table');
      }
      await _create(db, newVersion);
      return;
    }
    // v3: thêm cột machineCondition (Tình trạng máy sau bảo trì — nay chỉ
    // còn 1 đoạn văn bản tự do thay vì danh sách thông số Label/Value/Unit),
    // bỏ bảng maintenance_parameters (không còn dùng) và maintenance_counters
    // (Session ID đổi sang định dạng TTM-<viết tắt kỹ sư>-<giờ tạo>, không
    // cần bộ đếm nữa). Giữ nguyên report/items/photos/checklist/parts/
    // activity_log đã có (khác v1→v2, lần này không cần xoá sạch).
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE maintenance_reports ADD COLUMN machineCondition TEXT NOT NULL DEFAULT ''",
      );
      await db.execute('DROP TABLE IF EXISTS maintenance_parameters');
      await db.execute('DROP TABLE IF EXISTS maintenance_counters');
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  /// Creates the current schema on an isolated database used by tests.
  Future<void> createSchemaForTesting(Database db) => _create(db, 3);

  /// Runs migrations on an isolated database used by tests.
  Future<void> upgradeSchemaForTesting(
    Database db,
    int oldVersion,
    int newVersion,
  ) => _upgrade(db, oldVersion, newVersion);
}
