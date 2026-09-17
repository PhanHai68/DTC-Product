import 'package:dtc_product/features/projects/data/project_database.dart';
import 'package:dtc_product/features/projects/data/project_local_data_source.dart';
import 'package:dtc_product/features/projects/models/project.dart';
import 'package:dtc_product/features/projects/models/project_acceptance.dart';
import 'package:dtc_product/features/projects/models/project_attachment.dart';
import 'package:dtc_product/features/projects/models/project_checklist.dart';
import 'package:dtc_product/features/projects/models/project_machine.dart';
import 'package:dtc_product/features/projects/models/project_stage.dart';
import 'package:dtc_product/features/projects/models/project_stage_submission.dart';
import 'package:dtc_product/features/projects/repositories/local_project_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late LocalProjectRepository repository;
  final suffix = DateTime.now().microsecondsSinceEpoch;
  final projectId = 'test_project_$suffix';
  final now = DateTime(2026, 9, 17, 9);

  setUpAll(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await ProjectDatabase.instance.createSchemaForTesting(database);
    repository = LocalProjectRepository(
      localDataSource: ProjectLocalDataSource(database: database),
    );
  });

  tearDownAll(() async {
    await database.close();
  });

  test('SQLite lưu được toàn bộ vòng đời dự án và tự tính tiến độ', () async {
    final project = Project(
      id: projectId,
      projectName: 'Dự án kiểm thử',
      customerName: 'DTC Test',
      projectCode: 'TEST-$suffix',
      location: 'Long An',
      startDate: now,
      projectManager: 'Manager',
      technicalEngineer: 'Engineer',
      createdAt: now,
      updatedAt: now,
    );
    await repository.createProject(project);

    final stages = await repository.getStages(projectId);
    expect(stages, hasLength(4));

    final machine = ProjectMachine(
      id: 'test_machine_$suffix',
      projectId: projectId,
      machineName: 'SX8-01',
      model: 'SX8',
      serialNumber: 'SX8-TEST-$suffix',
      createdAt: now,
      updatedAt: now,
    );
    await repository.saveMachine(machine);

    final firstStage = stages.first;
    await repository.saveChecklist(
      ProjectChecklist(
        id: 'test_check_$suffix',
        projectId: projectId,
        stageId: firstStage.id,
        machineId: machine.id,
        title: 'Kiểm tra nguồn điện',
        isCompleted: true,
        completedBy: 'Engineer',
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.saveStage(
      firstStage.copyWith(
        status: ProjectStageStatus.completed,
        completedDate: now,
        updatedAt: now,
      ),
    );

    await repository.saveAttachment(
      ProjectAttachment(
        id: 'test_attachment_$suffix',
        projectId: projectId,
        machineId: machine.id,
        stageId: firstStage.id,
        category: 'evidence',
        fileType: ProjectFileType.photo,
        fileName: 'test.jpg',
        localPath: 'test/path.jpg',
        createdBy: 'Engineer',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.saveStageSubmission(
      ProjectStageSubmission(
        id: 'test_submission_$suffix',
        projectId: projectId,
        stageId: firstStage.id,
        machineId: machine.id,
        submissionType: ProjectSubmissionType.delivery,
        data: const {'photoCount': 1},
        workDate: now,
        result: 'Đã giao máy tại khu vực lắp đặt.',
        confirmedBy: 'Engineer',
        confirmedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.saveAcceptance(
      ProjectAcceptance(
        id: 'test_acceptance_$suffix',
        projectId: projectId,
        machineId: machine.id,
        installationCompleted: true,
        status: AcceptanceStatus.acceptedWithConditions,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final loaded = await repository.getProjectById(projectId);
    expect(loaded, isNotNull);
    expect(loaded!.machines.single.serialNumber, machine.serialNumber);
    expect(loaded.completedStages, 1);
    expect(loaded.progress, closeTo(1 / 4, .0001));
    expect(loaded.status, ProjectStatus.active);
    expect(await repository.getChecklists(firstStage.id), hasLength(1));
    expect(await repository.getAttachments(projectId), hasLength(1));
    expect(await repository.getStageSubmissions(projectId), hasLength(1));
    expect(await repository.getAcceptance(projectId), isNotNull);
    expect(await repository.getActivities(projectId), isNotEmpty);

    await repository.deleteProject(projectId);
    expect(await repository.getProjectById(projectId), isNull);
  });

  test('migration hợp nhất workflow cũ và giữ liên kết ảnh', () async {
    final legacy = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(legacy.close);
    await legacy.execute('''
      CREATE TABLE projects(id TEXT PRIMARY KEY)
    ''');
    await legacy.execute('''
      CREATE TABLE project_stages(
        id TEXT PRIMARY KEY, projectId TEXT, stageName TEXT, stageOrder INTEGER,
        status TEXT, startDate TEXT, completedDate TEXT, assignedUser TEXT,
        notes TEXT, syncStatus TEXT, createdAt TEXT, updatedAt TEXT
      )
    ''');
    await legacy.execute('''
      CREATE TABLE project_attachments(
        id TEXT PRIMARY KEY, projectId TEXT, stageId TEXT
      )
    ''');
    await legacy.execute(
      'CREATE TABLE project_checklists(id TEXT PRIMARY KEY, stageId TEXT)',
    );
    await legacy.execute(
      'CREATE TABLE project_activities(id TEXT PRIMARY KEY, stageId TEXT)',
    );
    await legacy.insert('projects', {'id': 'legacy_project'});
    final legacyStages = [
      ('prepare', 'Chuẩn bị', 0),
      ('delivery', 'Giao hàng', 1),
      ('unpacking', 'Mở kiện', 2),
      ('mechanical', 'Lắp đặt cơ khí', 3),
      ('electrical', 'Lắp đặt điện', 4),
      ('acceptance', 'Nghiệm thu', 5),
    ];
    for (final item in legacyStages) {
      await legacy.insert('project_stages', {
        'id': item.$1,
        'projectId': 'legacy_project',
        'stageName': item.$2,
        'stageOrder': item.$3,
        'status': item.$1 == 'mechanical' ? 'completed' : 'notStarted',
        'startDate': item.$1 == 'mechanical' ? now.toIso8601String() : null,
        'completedDate': item.$1 == 'mechanical'
            ? now.add(const Duration(hours: 1)).toIso8601String()
            : null,
        'assignedUser': '',
        'notes': '',
        'syncStatus': 'local',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
    }
    await legacy.insert('project_attachments', {
      'id': 'legacy_photo',
      'projectId': 'legacy_project',
      'stageId': 'mechanical',
    });

    await ProjectDatabase.instance.upgradeSchemaForTesting(legacy, 1, 3);

    final migratedStages = await legacy.query(
      'project_stages',
      where: 'projectId = ?',
      whereArgs: ['legacy_project'],
      orderBy: 'stageOrder',
    );
    expect(
      migratedStages.map((item) => item['stageName']),
      defaultProjectStageNames,
    );
    final installation = migratedStages.singleWhere(
      (item) => item['stageName'] == 'Lắp đặt',
    );
    final photo = (await legacy.query('project_attachments')).single;
    expect(photo['stageId'], installation['id']);
    expect(photo['category'], 'general');
  });
}
