import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_project.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_selection_project_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

GrindingSelectionProject _project({
  int? id,
  String projectName = 'Dự án A',
  String? customerName,
  GrindingProjectStatus status = GrindingProjectStatus.draft,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime(2026, 9, 24, 10, 0);
  return GrindingSelectionProject(
    id: id,
    projectName: projectName,
    customerName: customerName,
    status: status,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late GrindingSelectionProjectRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await GrindingMachineDatabase.instance.createSchemaForTesting(database);
    repository = GrindingSelectionProjectRepository(
      database: GrindingMachineDatabase.forTesting(database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('createProject lưu đúng dữ liệu, đọc lại (read) khớp 100%', () async {
    final id = await repository.createProject(
      _project(projectName: 'Trà xanh Bảo Lộc', customerName: 'Công ty ABC'),
    );
    final loaded = await repository.getProject(id);

    expect(loaded, isNotNull);
    expect(loaded!.projectName, 'Trà xanh Bảo Lộc');
    expect(loaded.customerName, 'Công ty ABC');
    expect(loaded.status, GrindingProjectStatus.draft);
    // Field không nhập phải giữ null, không tự thành rỗng/0.
    expect(loaded.contactName, isNull);
    expect(loaded.requiredCapacityKgH, isNull);
  });

  test('updateProject đổi status và cập nhật đúng field, không đụng field khác', () async {
    final id = await repository.createProject(_project(customerName: 'Khách A'));
    final loaded = (await repository.getProject(id))!;

    await repository.updateProject(
      loaded.copyWith(status: GrindingProjectStatus.evaluating),
    );
    final updated = await repository.getProject(id);

    expect(updated!.status, GrindingProjectStatus.evaluating);
    expect(updated.customerName, 'Khách A');
  });

  test('deleteProject xóa cả project lẫn quan hệ máy', () async {
    final id = await repository.createProject(
      _project(),
      primaryMachineId: 'BSP_ULTRAFINE__ASP-350',
      shortlistMachineIds: const ['BSC_COARSE__ASC-200'],
    );
    await repository.deleteProject(id);

    expect(await repository.getProject(id), isNull);
    final machines = await repository.getProjectMachines(id);
    expect(machines.primaryMachineId, isNull);
    expect(machines.shortlistMachineIds, isEmpty);
  });

  test('Quan hệ selected machine (primary) + shortlist lưu và đọc đúng', () async {
    final id = await repository.createProject(
      _project(),
      primaryMachineId: 'BSP_ULTRAFINE__ASP-350',
      shortlistMachineIds: const [
        'BSC_COARSE__ASC-200',
        'BSC_COARSE__ASC-300',
      ],
    );
    final machines = await repository.getProjectMachines(id);

    expect(machines.primaryMachineId, 'BSP_ULTRAFINE__ASP-350');
    expect(machines.shortlistMachineIds, [
      'BSC_COARSE__ASC-200',
      'BSC_COARSE__ASC-300',
    ]);
  });

  test('updateProject thay đổi primary/shortlist -> quan hệ cũ bị thay hoàn toàn', () async {
    final id = await repository.createProject(
      _project(),
      primaryMachineId: 'BSP_ULTRAFINE__ASP-350',
      shortlistMachineIds: const ['BSC_COARSE__ASC-200'],
    );
    final loaded = (await repository.getProject(id))!;

    await repository.updateProject(
      loaded,
      primaryMachineId: 'BSC_COARSE__ASC-300',
      shortlistMachineIds: const [],
    );
    final machines = await repository.getProjectMachines(id);

    expect(machines.primaryMachineId, 'BSC_COARSE__ASC-300');
    expect(machines.shortlistMachineIds, isEmpty);
  });

  test('Project tồn tại sau khi mở lại Repository mới trên cùng database', () async {
    final id = await repository.createProject(
      _project(projectName: 'Dự án bền vững'),
    );

    final reopened = GrindingSelectionProjectRepository(
      database: GrindingMachineDatabase.forTesting(database),
    );
    final loaded = await reopened.getProject(id);

    expect(loaded, isNotNull);
    expect(loaded!.projectName, 'Dự án bền vững');
  });

  test('getAllProjects sắp theo updatedAt giảm dần', () async {
    final idOld = await repository.createProject(
      _project(
        projectName: 'Cũ',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    final idNew = await repository.createProject(
      _project(
        projectName: 'Mới',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 1),
      ),
    );

    final all = await repository.getAllProjects();

    expect(all.map((p) => p.id).toList(), [idNew, idOld]);
  });

  test(
    'Transaction rollback: insert quan hệ máy lỗi -> project KHÔNG được lưu',
    () async {
      // Trigger buộc INSERT vào bảng quan hệ thất bại khi machineId = 'FAIL'
      // -> mô phỏng lỗi giữa transaction (cùng kỹ thuật đã dùng ở
      // grinding_machine_repository_test.dart).
      await database.execute('''
        CREATE TRIGGER fail_project_machine
        BEFORE INSERT ON grinding_selection_project_machines
        WHEN NEW.machineId = 'FAIL'
        BEGIN SELECT RAISE(ABORT, 'test failure'); END
      ''');

      final countBefore = (await repository.getAllProjects()).length;

      await expectLater(
        repository.createProject(
          _project(projectName: 'Sẽ rollback'),
          primaryMachineId: 'FAIL',
        ),
        throwsA(isA<DatabaseException>()),
      );

      final all = await repository.getAllProjects();
      expect(all, hasLength(countBefore));
      expect(all.any((p) => p.projectName == 'Sẽ rollback'), isFalse);
    },
  );
}
