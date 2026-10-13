import 'package:dtc_product/features/maintenance_report/data/maintenance_report_database.dart';
import 'package:dtc_product/features/maintenance_report/repositories/maintenance_report_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Migrations preserve legacy reports, attachments and measured parameters.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v1 lên v3 giữ dữ liệu cũ và vẫn ghi được theo model mới', () async {
    sqfliteFfiInit();
    final database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );

    // Tạo lại đúng schema v1 CŨ (trước khi đơn giản hoá) để mô phỏng máy đã
    // cài bản APK trước đó.
    await database.execute('''
      CREATE TABLE maintenance_reports(
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        customerName TEXT NOT NULL DEFAULT '',
        factorySite TEXT NOT NULL DEFAULT '',
        contactPerson TEXT NOT NULL DEFAULT '',
        contactPhone TEXT NOT NULL DEFAULT '',
        machineName TEXT NOT NULL DEFAULT '',
        machineType TEXT NOT NULL DEFAULT '',
        machineModel TEXT NOT NULL DEFAULT '',
        machineSerial TEXT NOT NULL DEFAULT '',
        machineRunningHours TEXT NOT NULL DEFAULT '',
        machineLocation TEXT NOT NULL DEFAULT '',
        maintenanceDate TEXT NOT NULL,
        engineerName TEXT NOT NULL DEFAULT '',
        sessionId TEXT,
        startTime TEXT,
        endTime TEXT,
        overallResult TEXT,
        finalComment TEXT NOT NULL DEFAULT '',
        recommendation TEXT NOT NULL DEFAULT '',
        nextMaintenanceDate TEXT,
        nextMaintenanceRunningHours TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await database.insert('maintenance_reports', {
      'id': 'old_report',
      'status': 'draft',
      'maintenanceDate': DateTime(2026, 9, 20).toIso8601String(),
      'engineerName': 'Kevin',
      'machineSerial': 'SERIAL-OLD',
      'contactPerson': 'Liên hệ cũ',
      'createdAt': DateTime(2026, 9, 20).toIso8601String(),
      'updatedAt': DateTime(2026, 9, 20).toIso8601String(),
    });
    await database.execute('''
      CREATE TABLE maintenance_checklist(
        id TEXT PRIMARY KEY,
        reportId TEXT NOT NULL,
        label TEXT NOT NULL,
        isChecked INTEGER NOT NULL DEFAULT 0,
        isCustom INTEGER NOT NULL DEFAULT 0,
        orderIndex INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Child schemas are unchanged since v1. Seed every related record before
    // migration, including legacy tables no longer used by the current UI.
    await MaintenanceReportDatabase.instance.createSchemaForTesting(database);
    final related = <String, Map<String, Object?>>{
      'maintenance_items': {
        'id': 'item',
        'reportId': 'old_report',
        'name': 'Motor',
        'createdAt': '2026-09-20',
        'updatedAt': '2026-09-20',
      },
      'maintenance_photos': {
        'id': 'photo',
        'reportId': 'old_report',
        'itemId': 'item',
        'kind': 'before',
        'sequence': 1,
        'originalPath': '/original.jpg',
        'reportPath': '/report.jpg',
        'sha256': 'old-hash',
        'capturedAt': '2026-09-20',
      },
      'maintenance_checklist': {
        'id': 'check',
        'reportId': 'old_report',
        'label': 'Kiểm tra',
        'isChecked': 1,
        'isCustom': 1,
      },
      'maintenance_parts': {
        'id': 'part',
        'reportId': 'old_report',
        'partName': 'Bearing',
      },
      'maintenance_activity_log': {
        'id': 'log',
        'reportId': 'old_report',
        'timestamp': '2026-09-20',
        'message': 'Original activity',
      },
    };
    for (final entry in related.entries) {
      await database.insert(entry.key, entry.value);
    }
    final before = <String, List<Map<String, Object?>>>{
      for (final table in related.keys) table: await database.query(table),
    };
    await database.execute('''CREATE TABLE maintenance_parameters(
      id TEXT PRIMARY KEY, reportId TEXT NOT NULL, label TEXT NOT NULL,
      value TEXT NOT NULL DEFAULT '', unit TEXT NOT NULL DEFAULT '',
      orderIndex INTEGER NOT NULL DEFAULT 0)''');
    await database.insert('maintenance_parameters', {
      'id': 'parameter',
      'reportId': 'old_report',
      'label': 'Áp suất',
      'value': '7.5',
      'unit': 'bar',
    });
    await database.execute(
      'CREATE TABLE maintenance_counters(name TEXT PRIMARY KEY, value INTEGER)',
    );
    await database.insert('maintenance_counters', {
      'name': 'session',
      'value': 23,
    });

    await MaintenanceReportDatabase.instance.upgradeSchemaForTesting(
      database,
      1,
      3,
    );

    final repository = MaintenanceReportRepository(
      database: MaintenanceReportDatabase.forTesting(database),
    );

    // Trước khi sửa lỗi, dòng insert này sẽ ném SqfliteFfiException "no such
    // column: machineTagName" vì bảng cũ chưa được nâng cấp.
    final report = await repository.createReport(
      customerName: 'ABC Factory',
      factorySite: 'KCN Long An',
      machineModel: 'OPA-75PM',
      machineTagName: 'SC16PRO-JX26010333',
      machineRunningHours: '5000',
      maintenanceDate: DateTime(2026, 9, 23),
      engineerNames: ['Kevin', 'An'],
    );

    final reloaded = await repository.getReport(report.id);
    expect(reloaded, isNotNull);
    expect(reloaded!.machineTagName, 'SC16PRO-JX26010333');
    expect(reloaded.engineerNames, ['Kevin', 'An']);

    final old = (await repository.getReport('old_report'))!;
    expect(old.engineerNames, ['Kevin']);
    expect(old.machineCondition, contains('Số serial: SERIAL-OLD'));
    expect(old.machineCondition, contains('Người liên hệ: Liên hệ cũ'));
    expect(old.machineCondition, contains('Áp suất: 7.5 bar'));
    for (final table in related.keys) {
      expect(await database.query(table), before[table], reason: table);
    }
    expect(
      (await database.query('maintenance_parameters')).single['value'],
      '7.5',
    );
    expect((await database.query('maintenance_counters')).single['value'], 23);
    expect(
      (await database.query(
        'maintenance_reports',
        where: 'id = ?',
        whereArgs: ['old_report'],
      )).single['machineSerial'],
      'SERIAL-OLD',
    );
    await repository.updateReport(old.copyWith(finalComment: 'Updated'));
    expect((await repository.getReport('old_report'))!.finalComment, 'Updated');

    await database.close();
  });

  test(
    'nâng cấp từ schema v2 (đã đơn giản hoá) lên v3 GIỮ NGUYÊN report cũ',
    () async {
      sqfliteFfiInit();
      final database = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );

      // Tạo lại đúng schema v2 (bản đơn giản hoá vừa phát hành, chưa có
      // machineCondition, còn bảng maintenance_parameters/maintenance_counters)
      // để mô phỏng máy đang chạy đúng bản APK trước bản sửa lỗi này.
      await database.execute('''
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
        overallResult TEXT,
        finalComment TEXT NOT NULL DEFAULT '',
        recommendation TEXT NOT NULL DEFAULT '',
        nextMaintenanceDate TEXT,
        nextMaintenanceRunningHours TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
      await database.insert('maintenance_reports', {
        'id': 'v2_report',
        'status': 'draft',
        'customerName': 'Phúc Long',
        'machineModel': 'DF53Pro',
        'maintenanceDate': DateTime(2026, 9, 20).toIso8601String(),
        'engineerNames': '["Kevin"]',
        'createdAt': DateTime(2026, 9, 20).toIso8601String(),
        'updatedAt': DateTime(2026, 9, 20).toIso8601String(),
      });
      await database.execute('''
      CREATE TABLE maintenance_parameters(
        id TEXT PRIMARY KEY,
        reportId TEXT NOT NULL,
        label TEXT NOT NULL,
        value TEXT NOT NULL DEFAULT '',
        unit TEXT NOT NULL DEFAULT '',
        orderIndex INTEGER NOT NULL DEFAULT 0
      )
    ''');
      await database.execute('''
      CREATE TABLE maintenance_counters(
        name TEXT PRIMARY KEY,
        value INTEGER NOT NULL DEFAULT 0
      )
    ''');

      await database.insert('maintenance_parameters', {
        'id': 'v2_parameter',
        'reportId': 'v2_report',
        'label': 'Nhiệt độ',
        'value': '45',
        'unit': '°C',
      });
      await database.insert('maintenance_counters', {
        'name': 'session',
        'value': 5,
      });
      await MaintenanceReportDatabase.instance.upgradeSchemaForTesting(
        database,
        2,
        3,
      );

      final repository = MaintenanceReportRepository(
        database: MaintenanceReportDatabase.forTesting(database),
      );

      // Report đã tạo trước khi nâng cấp vẫn còn nguyên (khác nhánh v1→v2 —
      // lần này KHÔNG xoá dữ liệu vì schema map 1-1 được, chỉ thêm cột).
      final reloaded = await repository.getReport('v2_report');
      expect(reloaded, isNotNull);
      expect(reloaded!.customerName, 'Phúc Long');
      expect(reloaded.machineCondition, 'Nhiệt độ: 45 °C');
      expect(await database.query('maintenance_parameters'), hasLength(1));
      expect((await database.query('maintenance_counters')).single['value'], 5);

      await repository.updateReport(
        reloaded.copyWith(machineCondition: 'Máy chạy êm, không rò rỉ.'),
      );
      final updated = await repository.getReport('v2_report');
      expect(updated!.machineCondition, 'Máy chạy êm, không rò rỉ.');

      await database.close();
    },
  );

  test(
    'migration failure rolls back added columns and report values',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(db.close);
      await db.execute(
        'CREATE TABLE maintenance_reports(id TEXT PRIMARY KEY, updatedAt TEXT)',
      );
      await db.insert('maintenance_reports', {
        'id': 'original',
        'updatedAt': '2026-09-20',
      });
      await db.execute(
        '''CREATE TABLE maintenance_parameters(
      id TEXT PRIMARY KEY, reportId TEXT, label TEXT, value TEXT, unit TEXT, orderIndex INTEGER)''',
      );
      await db.insert('maintenance_parameters', {
        'id': 'p',
        'reportId': 'original',
        'label': 'Pressure',
        'value': '7',
        'unit': 'bar',
        'orderIndex': 0,
      });
      await db.execute(
        '''CREATE TRIGGER fail_migration BEFORE UPDATE ON maintenance_reports
      BEGIN SELECT RAISE(ABORT, 'simulated migration failure'); END''',
      );
      await expectLater(
        MaintenanceReportDatabase.instance.upgradeSchemaForTesting(db, 2, 3),
        throwsA(isA<DatabaseException>()),
      );
      final columns = await db.rawQuery(
        'PRAGMA table_info(maintenance_reports)',
      );
      expect(
        columns.map((row) => row['name']),
        isNot(contains('machineCondition')),
      );
      expect((await db.query('maintenance_reports')).single['id'], 'original');
      expect((await db.query('maintenance_parameters')).single['value'], '7');
    },
  );
}
