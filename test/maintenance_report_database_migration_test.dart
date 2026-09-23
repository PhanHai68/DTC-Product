import 'package:dtc_product/features/maintenance_report/data/maintenance_report_database.dart';
import 'package:dtc_product/features/maintenance_report/repositories/maintenance_report_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Bug thực tế đã gặp: máy đã cài bản APK cũ (schema v1 có contactPerson/
/// machineName/... và engineerName dạng String) rồi cập nhật lên bản mới mà
/// KHÔNG tăng version của database — sqflite coi đây là "không có gì thay
/// đổi" nên giữ nguyên bảng cũ, khiến insert theo cột mới (machineTagName,
/// engineerNames) báo lỗi "no such column" và nút "Tạo báo cáo" im lặng
/// không làm gì. Test này mô phỏng đúng tình huống đó bằng cách tạo thủ công
/// schema v1 CŨ rồi chạy migration lên v2, xác nhận insert/đọc theo model
/// mới hoạt động được sau khi nâng cấp.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nâng cấp từ schema v1 cũ (cột cũ) lên v2 không còn lỗi insert', () async {
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

    // Chạy đúng migration thật (_upgrade) từ v1 lên v2.
    await MaintenanceReportDatabase.instance.upgradeSchemaForTesting(
      database,
      1,
      2,
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

    // Dữ liệu report cũ (schema v1) không còn — chấp nhận được vì tính năng
    // chưa phát hành rộng rãi khi đổi schema.
    final reports = await repository.getReports();
    expect(reports.map((item) => item.id), isNot(contains('old_report')));

    await database.close();
  });
}
