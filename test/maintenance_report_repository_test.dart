import 'package:dtc_product/features/maintenance_report/data/maintenance_report_database.dart';
import 'package:dtc_product/features/maintenance_report/models/maintenance_photo.dart';
import 'package:dtc_product/features/maintenance_report/models/maintenance_report.dart';
import 'package:dtc_product/features/maintenance_report/repositories/maintenance_report_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late MaintenanceReportRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await MaintenanceReportDatabase.instance.createSchemaForTesting(database);
    repository = MaintenanceReportRepository(
      database: MaintenanceReportDatabase.forTesting(database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('createReport tạo report Draft kèm checklist mặc định 10 mục', () async {
    final report = await repository.createReport(
      customerName: 'ABC Factory',
      factorySite: 'KCN Long An',
      contactPerson: 'Mr. A',
      contactPhone: '0900000000',
      machineName: 'Air Compressor 100 HP',
      machineType: 'Screw',
      machineModel: 'OPA-75PM',
      machineSerial: 'SN123',
      machineRunningHours: '5000',
      machineLocation: 'Xưởng 1',
      maintenanceDate: DateTime(2026, 9, 23),
      engineerName: 'Kevin',
    );

    expect(report.status, MaintenanceReportStatus.draft);
    expect(report.hasStarted, isFalse);

    final checklist = await repository.getChecklist(report.id);
    expect(checklist, hasLength(10));
    expect(checklist.every((task) => !task.isChecked), isTrue);

    final reports = await repository.getReports();
    expect(reports.map((item) => item.id), contains(report.id));
  });

  test('startMaintenance sinh Session ID đúng định dạng và ghi activity log', () async {
    final report = await repository.createReport(
      customerName: 'ABC',
      factorySite: '',
      contactPerson: '',
      contactPhone: '',
      machineName: 'Máy A',
      machineType: '',
      machineModel: '',
      machineSerial: '',
      machineRunningHours: '',
      machineLocation: '',
      maintenanceDate: DateTime(2026, 9, 23),
      engineerName: 'Kevin',
    );

    final started = await repository.startMaintenance(report.id);

    expect(started.sessionId, matches(RegExp(r'^MNT-\d{8}-\d{4}$')));
    expect(started.startTime, isNotNull);

    final activities = await repository.getActivities(report.id);
    expect(activities.map((item) => item.message), contains('Start Maintenance'));

    // Gọi lại lần 2 không sinh Session ID mới (đã start rồi).
    final startedAgain = await repository.startMaintenance(report.id);
    expect(startedAgain.sessionId, started.sessionId);
  });

  test('Session ID tăng dần và không lặp lại giữa các report', () async {
    final reportA = await repository.createReport(
      customerName: 'A',
      factorySite: '',
      contactPerson: '',
      contactPhone: '',
      machineName: '',
      machineType: '',
      machineModel: '',
      machineSerial: '',
      machineRunningHours: '',
      machineLocation: '',
      maintenanceDate: DateTime(2026, 9, 23),
      engineerName: '',
    );
    final reportB = await repository.createReport(
      customerName: 'B',
      factorySite: '',
      contactPerson: '',
      contactPhone: '',
      machineName: '',
      machineType: '',
      machineModel: '',
      machineSerial: '',
      machineRunningHours: '',
      machineLocation: '',
      maintenanceDate: DateTime(2026, 9, 23),
      engineerName: '',
    );

    final startedA = await repository.startMaintenance(reportA.id);
    final startedB = await repository.startMaintenance(reportB.id);

    expect(startedA.sessionId, isNot(equals(startedB.sessionId)));
  });

  test('nextPhotoId sinh B01, B02... và A01... tăng dần theo loại', () async {
    final report = await repository.createReport(
      customerName: 'A',
      factorySite: '',
      contactPerson: '',
      contactPhone: '',
      machineName: '',
      machineType: '',
      machineModel: '',
      machineSerial: '',
      machineRunningHours: '',
      machineLocation: '',
      maintenanceDate: DateTime(2026, 9, 23),
      engineerName: '',
    );
    final started = await repository.startMaintenance(report.id);
    final sessionId = started.sessionId!;

    final (firstBeforeId, firstBeforeSeq) = await repository.nextPhotoId(
      reportId: report.id,
      sessionId: sessionId,
      kind: MaintenancePhotoKind.before,
    );
    expect(firstBeforeId, '$sessionId-B01');
    expect(firstBeforeSeq, 1);

    await repository.insertPhoto(
      MaintenancePhoto(
        id: firstBeforeId,
        reportId: report.id,
        kind: MaintenancePhotoKind.before,
        sequence: firstBeforeSeq,
        originalPath: '/tmp/original.jpg',
        reportPath: '/tmp/report.jpg',
        sha256: 'hash1',
        capturedAt: DateTime.now(),
      ),
    );

    final (secondBeforeId, secondBeforeSeq) = await repository.nextPhotoId(
      reportId: report.id,
      sessionId: sessionId,
      kind: MaintenancePhotoKind.before,
    );
    expect(secondBeforeId, '$sessionId-B02');
    expect(secondBeforeSeq, 2);

    final (firstAfterId, firstAfterSeq) = await repository.nextPhotoId(
      reportId: report.id,
      sessionId: sessionId,
      kind: MaintenancePhotoKind.after,
    );
    expect(firstAfterId, '$sessionId-A01');
    expect(firstAfterSeq, 1);

    final photos = await repository.getPhotos(report.id);
    expect(photos, hasLength(1));
  });

  test('addItem/updateItem/addPart/addParameter lưu và đọc lại đúng', () async {
    final report = await repository.createReport(
      customerName: 'A',
      factorySite: '',
      contactPerson: '',
      contactPhone: '',
      machineName: '',
      machineType: '',
      machineModel: '',
      machineSerial: '',
      machineRunningHours: '',
      machineLocation: '',
      maintenanceDate: DateTime(2026, 9, 23),
      engineerName: '',
    );

    final item = await repository.addItem(report.id, 'Air Filter');
    await repository.updateItem(
      item.copyWith(beforeFinding: 'Bẩn nhiều', actionTaken: 'Thay mới'),
    );
    final items = await repository.getItems(report.id);
    expect(items, hasLength(1));
    expect(items.first.beforeFinding, 'Bẩn nhiều');

    await repository.addPart(reportId: report.id, partName: 'Air Filter', quantity: 1);
    final parts = await repository.getParts(report.id);
    expect(parts, hasLength(1));

    await repository.addParameter(
      reportId: report.id,
      label: 'Running Pressure',
      value: '7.2',
      unit: 'bar',
    );
    final parameters = await repository.getParameters(report.id);
    expect(parameters, hasLength(1));
    expect(parameters.first.value, '7.2');
  });

  test('completeMaintenance chuyển status sang Completed và ghi endTime', () async {
    final report = await repository.createReport(
      customerName: 'A',
      factorySite: '',
      contactPerson: '',
      contactPhone: '',
      machineName: '',
      machineType: '',
      machineModel: '',
      machineSerial: '',
      machineRunningHours: '',
      machineLocation: '',
      maintenanceDate: DateTime(2026, 9, 23),
      engineerName: '',
    );
    await repository.startMaintenance(report.id);

    final completed = await repository.completeMaintenance(report.id);

    expect(completed.status, MaintenanceReportStatus.completed);
    expect(completed.endTime, isNotNull);

    final activities = await repository.getActivities(report.id);
    expect(
      activities.map((item) => item.message),
      contains('Report Completed'),
    );
  });

  test('toggleChecklistTask và addCustomTask hoạt động đúng', () async {
    final report = await repository.createReport(
      customerName: 'A',
      factorySite: '',
      contactPerson: '',
      contactPhone: '',
      machineName: '',
      machineType: '',
      machineModel: '',
      machineSerial: '',
      machineRunningHours: '',
      machineLocation: '',
      maintenanceDate: DateTime(2026, 9, 23),
      engineerName: '',
    );

    final checklist = await repository.getChecklist(report.id);
    await repository.toggleChecklistTask(checklist.first.id, true);
    final custom = await repository.addCustomTask(report.id, 'Kiểm tra riêng');

    final updated = await repository.getChecklist(report.id);
    expect(updated.firstWhere((t) => t.id == checklist.first.id).isChecked, isTrue);
    expect(updated.firstWhere((t) => t.id == custom.id).isCustom, isTrue);
  });
}
