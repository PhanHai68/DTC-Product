import 'package:dtc_product/features/projects/data/project_database.dart';
import 'package:dtc_product/features/projects/data/project_local_data_source.dart';
import 'package:dtc_product/features/projects/models/project.dart';
import 'package:dtc_product/features/projects/models/project_stage.dart';
import 'package:dtc_product/features/projects/models/project_machine.dart';
import 'package:dtc_product/features/projects/models/project_checklist.dart';
import 'package:dtc_product/features/projects/models/project_attachment.dart';
import 'package:dtc_product/features/projects/models/project_acceptance.dart';
import 'package:dtc_product/features/projects/models/project_stage_submission.dart';
import 'package:dtc_product/features/projects/repositories/local_project_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late LocalProjectRepository repository;
  final now = DateTime(2026, 10, 9);
  final project = Project(
    id: 'project',
    projectName: 'Test',
    customerName: 'DTC',
    projectCode: 'P1',
    location: 'Long An',
    startDate: now,
    projectManager: 'Manager',
    technicalEngineer: 'Engineer',
    createdAt: now,
    updatedAt: now,
  );
  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await ProjectDatabase.instance.createSchemaForTesting(db);
    repository = LocalProjectRepository(
      localDataSource: ProjectLocalDataSource(database: db),
    );
  });
  tearDown(() async => db.close());
  Future<void> rejectActivity() => db.execute('''CREATE TRIGGER fail_log
    BEFORE INSERT ON project_activities
    BEGIN SELECT RAISE(ABORT, 'simulated log failure'); END''');

  test('failed middle stage creation rolls back the entire project', () async {
    await db.execute(
      '''CREATE TRIGGER fail_stage BEFORE INSERT ON project_stages
      WHEN NEW.stageOrder = 2 BEGIN SELECT RAISE(ABORT, 'stage failure'); END''',
    );
    await expectLater(
      repository.createProject(project),
      throwsA(isA<DatabaseException>()),
    );
    for (final table in ['projects', 'project_stages', 'project_activities']) {
      expect(await db.query(table), isEmpty, reason: table);
    }
  });

  test('stage and activity roll back if parent status update fails', () async {
    await repository.createProject(project);
    final stage = (await repository.getStages(project.id)).first;
    final activities = await db.query('project_activities');
    await db.execute('''CREATE TRIGGER fail_project BEFORE UPDATE ON projects
      BEGIN SELECT RAISE(ABORT, 'parent update failure'); END''');
    await expectLater(
      repository.saveStage(
        stage.copyWith(status: ProjectStageStatus.completed, updatedAt: now),
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect((await repository.getStages(project.id)).first.status, stage.status);
    expect(await db.query('project_activities'), activities);
    expect(
      (await repository.getProjectById(project.id))!.status,
      project.status,
    );
  });

  test(
    'all record plus activity operations roll back on log failure',
    () async {
      await repository.createProject(project);
      final stage = (await repository.getStages(project.id)).first;
      final activities = await db.query('project_activities');
      await rejectActivity();
      final actions = <String, Future<void> Function()>{
        'project_machines': () => repository.saveMachine(
          ProjectMachine(
            id: 'machine',
            projectId: project.id,
            machineName: 'SX8',
            model: 'SX8',
            serialNumber: 'S1',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        'project_checklists': () => repository.saveChecklist(
          ProjectChecklist(
            id: 'check',
            projectId: project.id,
            stageId: stage.id,
            title: 'Test',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        'project_attachments': () => repository.saveAttachment(
          ProjectAttachment(
            id: 'photo',
            projectId: project.id,
            category: 'evidence',
            fileType: ProjectFileType.photo,
            fileName: 'photo.jpg',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        'project_acceptances': () => repository.saveAcceptance(
          ProjectAcceptance(
            id: 'acceptance',
            projectId: project.id,
            createdAt: now,
            updatedAt: now,
          ),
        ),
        'project_stage_submissions': () => repository.saveStageSubmission(
          ProjectStageSubmission(
            id: 'submission',
            projectId: project.id,
            stageId: stage.id,
            submissionType: ProjectSubmissionType.delivery,
            workDate: now,
            confirmedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        ),
      };
      for (final action in actions.entries) {
        await expectLater(action.value(), throwsA(isA<DatabaseException>()));
        expect(await db.query(action.key), isEmpty, reason: action.key);
      }
      expect(await db.query('project_activities'), activities);
    },
  );
}
