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

  Future<MaintenanceReport> createReport({
    String customerName = 'A',
    String factorySite = '',
    String machineModel = '',
    String machineTagName = '',
    String machineRunningHours = '',
    List<String> engineerNames = const [],
  }) {
    return repository.createReport(
      customerName: customerName,
      factorySite: factorySite,
      machineModel: machineModel,
      machineTagName: machineTagName,
      machineRunningHours: machineRunningHours,
      maintenanceDate: DateTime(2026, 9, 23),
      engineerNames: engineerNames,
    );
  }

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

  test('createReport tạo report Draft, checklist rỗng (không còn mặc định)', () async {
    final report = await createReport(
      customerName: 'ABC Factory',
      factorySite: 'KCN Long An',
      machineModel: 'OPA-75PM',
      machineTagName: 'SC16PRO-JX26010333',
      machineRunningHours: '5000',
      engineerNames: ['Kevin', 'An'],
    );

    expect(report.status, MaintenanceReportStatus.draft);
    expect(report.hasStarted, isFalse);
    expect(report.engineerNames, ['Kevin', 'An']);
    expect(report.engineerNamesDisplay, 'Kevin, An');

    final checklist = await repository.getChecklist(report.id);
    expect(checklist, isEmpty);

    final reports = await repository.getReports();
    expect(reports.map((item) => item.id), contains(report.id));

    // Đọc lại từ DB (không chỉ đối tượng vừa tạo) để chắc chắn engineerNames
    // round-trip đúng qua JSON lưu trong 1 cột TEXT.
    final reloaded = await repository.getReport(report.id);
    expect(reloaded!.engineerNames, ['Kevin', 'An']);
  });

  test('startMaintenance sinh Session ID đúng định dạng và ghi activity log', () async {
    final report = await createReport(
      customerName: 'ABC',
      machineModel: 'Máy A',
      engineerNames: ['Kevin'],
    );

    final started = await repository.startMaintenance(report.id);

    // Định dạng TTM-<viết tắt tên kỹ sư>-<thời gian tạo đến phút>.
    expect(started.sessionId, matches(RegExp(r'^TTM-K-\d{12}$')));
    expect(started.startTime, isNotNull);

    final activities = await repository.getActivities(report.id);
    expect(
      activities.map((item) => item.message),
      contains('Bắt đầu bảo trì'),
    );

    // Gọi lại lần 2 không sinh Session ID mới (đã start rồi).
    final startedAgain = await repository.startMaintenance(report.id);
    expect(startedAgain.sessionId, started.sessionId);
  });

  test('Session ID viết tắt đúng nhiều kỹ sư, bỏ dấu tiếng Việt an toàn', () async {
    final report = await createReport(
      engineerNames: ['Nguyễn Văn An', 'Kevin'],
    );
    final started = await repository.startMaintenance(report.id);

    // "Nguyễn Văn An" -> NVA, "Kevin" -> K, nối lại thành NVAK.
    expect(started.sessionId, startsWith('TTM-NVAK-'));

    final noEngineerReport = await createReport(engineerNames: const []);
    final startedNoEngineer = await repository.startMaintenance(
      noEngineerReport.id,
    );
    expect(startedNoEngineer.sessionId, startsWith('TTM-XX-'));
  });

  test('Session ID tăng dần và không lặp lại giữa các report', () async {
    final reportA = await createReport(customerName: 'A');
    final reportB = await createReport(customerName: 'B');

    final startedA = await repository.startMaintenance(reportA.id);
    final startedB = await repository.startMaintenance(reportB.id);

    expect(startedA.sessionId, isNot(equals(startedB.sessionId)));
  });

  test('nextPhotoId sinh B01, B02... và A01... tăng dần theo loại', () async {
    final report = await createReport();
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

  test('addItem/updateItem/addPart/machineCondition lưu và đọc lại đúng', () async {
    final report = await createReport();

    final item = await repository.addItem(report.id, 'Lọc gió');
    await repository.updateItem(
      item.copyWith(beforeFinding: 'Bẩn nhiều', actionTaken: 'Thay mới'),
    );
    final items = await repository.getItems(report.id);
    expect(items, hasLength(1));
    expect(items.first.beforeFinding, 'Bẩn nhiều');

    await repository.addPart(reportId: report.id, partName: 'Lọc gió', quantity: 1);
    final parts = await repository.getParts(report.id);
    expect(parts, hasLength(1));

    await repository.updateReport(
      report.copyWith(machineCondition: 'Máy chạy êm, áp suất ổn định.'),
    );
    final reloaded = await repository.getReport(report.id);
    expect(reloaded!.machineCondition, 'Máy chạy êm, áp suất ổn định.');
  });

  test('completeMaintenance chuyển status sang Completed và ghi endTime', () async {
    final report = await createReport();
    await repository.startMaintenance(report.id);

    final completed = await repository.completeMaintenance(report.id);

    expect(completed.status, MaintenanceReportStatus.completed);
    expect(completed.endTime, isNotNull);

    final activities = await repository.getActivities(report.id);
    expect(
      activities.map((item) => item.message),
      contains('Hoàn tất bảo trì'),
    );
  });

  test('addChecklistTask và toggleChecklistTask hoạt động đúng, xóa được', () async {
    final report = await createReport();

    final task = await repository.addChecklistTask(report.id, 'Kiểm tra riêng');
    await repository.toggleChecklistTask(task.id, true);

    final updated = await repository.getChecklist(report.id);
    expect(updated, hasLength(1));
    expect(updated.first.isChecked, isTrue);
    expect(updated.first.label, 'Kiểm tra riêng');

    await repository.deleteChecklistTask(task.id);
    expect(await repository.getChecklist(report.id), isEmpty);
  });
}
