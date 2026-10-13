import 'dart:convert';

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

  Future<void> _create(DatabaseExecutor db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_reports(
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
      'CREATE INDEX IF NOT EXISTS idx_maintenance_reports_updated ON maintenance_reports(updatedAt DESC)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_items(
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
      'CREATE INDEX IF NOT EXISTS idx_maintenance_items_report ON maintenance_items(reportId, orderIndex)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_photos(
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
      'CREATE INDEX IF NOT EXISTS idx_maintenance_photos_report ON maintenance_photos(reportId, kind, sequence)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_maintenance_photos_item ON maintenance_photos(itemId)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_checklist(
        id TEXT PRIMARY KEY,
        reportId TEXT NOT NULL,
        label TEXT NOT NULL,
        isChecked INTEGER NOT NULL DEFAULT 0,
        orderIndex INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_maintenance_checklist_report ON maintenance_checklist(reportId, orderIndex)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_parts(
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
      'CREATE INDEX IF NOT EXISTS idx_maintenance_parts_report ON maintenance_parts(reportId, orderIndex)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS maintenance_activity_log(
        id TEXT PRIMARY KEY,
        reportId TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        message TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_maintenance_activity_report ON maintenance_activity_log(reportId, timestamp)',
    );
  }

  /// Additive migration: keep original columns/tables as a lossless archive.
  /// sqflite runs onUpgrade in a transaction; never drop user reports/photos.
  Future<void> _upgrade(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion,
  ) async {
    final columns = (await db.rawQuery(
      'PRAGMA table_info(maintenance_reports)',
    )).map((row) => row['name'] as String).toSet();
    if (oldVersion < 2 && newVersion >= 2) {
      if (!columns.contains('machineTagName')) {
        await db.execute(
          "ALTER TABLE maintenance_reports ADD COLUMN machineTagName TEXT NOT NULL DEFAULT ''",
        );
      }
      if (!columns.contains('engineerNames')) {
        await db.execute(
          "ALTER TABLE maintenance_reports ADD COLUMN engineerNames TEXT NOT NULL DEFAULT '[]'",
        );
        if (columns.contains('engineerName')) {
          for (final row in await db.query('maintenance_reports')) {
            final name = (row['engineerName'] as String? ?? '').trim();
            await db.update(
              'maintenance_reports',
              {
                'engineerNames': jsonEncode(name.isEmpty ? <String>[] : [name]),
              },
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
      }
    }
    if (oldVersion < 3 && newVersion >= 3) {
      if (!columns.contains('machineCondition')) {
        await db.execute(
          "ALTER TABLE maintenance_reports ADD COLUMN machineCondition TEXT NOT NULL DEFAULT ''",
        );
      }
      final hasParameters = (await db.query(
        'sqlite_master',
        where: 'type = ? AND name = ?',
        whereArgs: ['table', 'maintenance_parameters'],
      )).isNotEmpty;
      for (final row in await db.query('maintenance_reports')) {
        final details = <String>[];
        final condition = row['machineCondition'] as String? ?? '';
        if (condition.isNotEmpty) details.add(condition);
        // These fields have no exact equivalent in the simplified form.
        // Keep their original columns and also make them visible in reports.
        for (final field in const {
          'contactPerson': 'Người liên hệ',
          'contactPhone': 'Điện thoại',
          'machineName': 'Tên máy',
          'machineType': 'Loại máy',
          'machineSerial': 'Số serial',
          'machineLocation': 'Vị trí máy',
        }.entries) {
          final value = row[field.key] as String? ?? '';
          if (value.isNotEmpty) details.add('${field.value}: $value');
        }
        if (hasParameters) {
          final parameters = await db.query(
            'maintenance_parameters',
            where: 'reportId = ?',
            whereArgs: [row['id']],
            orderBy: 'orderIndex ASC, id ASC',
          );
          for (final parameter in parameters) {
            final value =
                '${parameter['value'] ?? ''} ${parameter['unit'] ?? ''}'.trim();
            details.add('${parameter['label']}: $value');
          }
        }
        if (details.isNotEmpty) {
          await db.update(
            'maintenance_reports',
            {'machineCondition': details.join('\n')},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    }
    // Some early installations only created a subset of child tables.
    // CREATE IF NOT EXISTS fills the gaps without replacing existing data.
    await _create(db, newVersion);
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
  ) => db.transaction((txn) => _upgrade(txn, oldVersion, newVersion));
}
