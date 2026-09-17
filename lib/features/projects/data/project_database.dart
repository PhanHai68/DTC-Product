import 'package:sqflite/sqflite.dart';

import '../../../core/database/local_database_factory.dart'
    if (dart.library.io) '../../../core/database/local_database_factory_io.dart'
    if (dart.library.js_interop) '../../../core/database/local_database_factory_web.dart';

class ProjectDatabase {
  ProjectDatabase._();
  static final ProjectDatabase instance = ProjectDatabase._();

  Database? _database;

  Future<Database> get database async {
    _database ??= await openLocalDatabase(
      fileName: 'project_tracking.db',
      version: 3,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _database!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE projects(
        id TEXT PRIMARY KEY,
        projectName TEXT NOT NULL,
        customerName TEXT NOT NULL,
        projectCode TEXT NOT NULL,
        location TEXT NOT NULL,
        startDate TEXT NOT NULL,
        expectedCompletionDate TEXT,
        projectManager TEXT NOT NULL DEFAULT '',
        technicalEngineer TEXT NOT NULL DEFAULT '',
        salesPerson TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        syncStatus TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_projects_code ON projects(projectCode)',
    );
    await db.execute('''
      CREATE TABLE project_machines(
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        productId TEXT,
        machineName TEXT NOT NULL,
        model TEXT NOT NULL,
        serialNumber TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        installationPosition TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'Chuẩn bị',
        notes TEXT NOT NULL DEFAULT '',
        qrCode TEXT NOT NULL DEFAULT '',
        assetCode TEXT NOT NULL DEFAULT '',
        syncStatus TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_project_machines_project ON project_machines(projectId)',
    );
    await db.execute(
      'CREATE INDEX idx_project_machines_serial ON project_machines(serialNumber)',
    );
    await db.execute('''
      CREATE TABLE project_stages(
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        stageName TEXT NOT NULL,
        stageOrder INTEGER NOT NULL,
        status TEXT NOT NULL,
        startDate TEXT,
        completedDate TEXT,
        assignedUser TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        syncStatus TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_project_stages_project ON project_stages(projectId, stageOrder)',
    );
    await db.execute('''
      CREATE TABLE project_checklists(
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        stageId TEXT NOT NULL,
        machineId TEXT,
        title TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        completedBy TEXT NOT NULL DEFAULT '',
        completedAt TEXT,
        notes TEXT NOT NULL DEFAULT '',
        syncStatus TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_project_checklists_stage ON project_checklists(stageId)',
    );
    await db.execute('''
      CREATE TABLE project_activities(
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        machineId TEXT,
        stageId TEXT,
        activityType TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        userId TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        attachmentIds TEXT NOT NULL DEFAULT '',
        syncStatus TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_project_activities_project ON project_activities(projectId, createdAt DESC)',
    );
    await db.execute('''
      CREATE TABLE project_attachments(
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        machineId TEXT,
        stageId TEXT,
        activityId TEXT,
        category TEXT NOT NULL DEFAULT 'general',
        fileType TEXT NOT NULL,
        fileName TEXT NOT NULL,
        localPath TEXT NOT NULL DEFAULT '',
        cloudUrl TEXT NOT NULL DEFAULT '',
        thumbnailPath TEXT NOT NULL DEFAULT '',
        createdBy TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        location TEXT NOT NULL DEFAULT '',
        syncStatus TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_project_attachments_project ON project_attachments(projectId, createdAt DESC)',
    );
    await db.execute('''
      CREATE TABLE project_acceptances(
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        machineId TEXT,
        installationCompleted INTEGER NOT NULL DEFAULT 0,
        testingCompleted INTEGER NOT NULL DEFAULT 0,
        trainingCompleted INTEGER NOT NULL DEFAULT 0,
        acceptanceDate TEXT,
        customerRepresentative TEXT NOT NULL DEFAULT '',
        dtcRepresentative TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL,
        customerSignature TEXT NOT NULL DEFAULT '',
        dtcSignature TEXT NOT NULL DEFAULT '',
        customerName TEXT NOT NULL DEFAULT '',
        dtcEngineer TEXT NOT NULL DEFAULT '',
        acceptedAt TEXT,
        syncStatus TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX idx_project_acceptances_project ON project_acceptances(projectId)',
    );
    await _createStageSubmissions(db);
  }

  Future<void> _createStageSubmissions(Database db) async {
    await db.execute('''
      CREATE TABLE project_stage_submissions(
        id TEXT PRIMARY KEY,
        projectId TEXT NOT NULL,
        stageId TEXT NOT NULL,
        machineId TEXT,
        submissionType TEXT NOT NULL,
        dataJson TEXT NOT NULL DEFAULT '{}',
        workDate TEXT NOT NULL,
        result TEXT NOT NULL DEFAULT '',
        isFinalConfirmation INTEGER NOT NULL DEFAULT 0,
        confirmedBy TEXT NOT NULL DEFAULT '',
        confirmedAt TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        syncStatus TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_stage_submissions_stage ON project_stage_submissions(projectId, stageId, confirmedAt DESC)',
    );
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE project_attachments ADD COLUMN category TEXT NOT NULL DEFAULT 'general'",
      );
      await _createStageSubmissions(db);
    } else if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE project_stage_submissions ADD COLUMN workDate TEXT',
      );
      await db.execute(
        "ALTER TABLE project_stage_submissions ADD COLUMN result TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        'ALTER TABLE project_stage_submissions ADD COLUMN isFinalConfirmation INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'UPDATE project_stage_submissions SET workDate = confirmedAt WHERE workDate IS NULL',
      );
    }
    if (oldVersion < 3) await _migrateSimplifiedWorkflow(db);
  }

  Future<void> _migrateSimplifiedWorkflow(Database db) async {
    const groups = <String, Set<String>>{
      'Giao máy': {'Chuẩn bị', 'Giao hàng', 'Giao máy'},
      'Khui thùng': {'Mở kiện', 'Khui thùng'},
      'Lắp đặt': {
        'Hoàn thiện lắp đặt',
        'Lắp đặt',
        'Định vị máy',
        'Lắp đặt cơ khí',
        'Lắp đặt điện',
        'Lắp khí nén',
        'Kiểm tra trước chạy thử',
        'Chạy thử không tải',
        'Chạy thử có tải',
        'Tuning / Calibration',
        'Đào tạo khách hàng',
      },
      'Nghiệm thu': {'Nghiệm thu', 'Bàn giao', 'Bảo trì / After Sales'},
    };
    final projects = await db.query('projects', columns: ['id']);
    for (final projectRow in projects) {
      final projectId = projectRow['id']! as String;
      final stages = await db.query(
        'project_stages',
        where: 'projectId = ?',
        whereArgs: [projectId],
        orderBy: 'stageOrder ASC',
      );
      final now = DateTime.now().toIso8601String();
      var order = 0;
      for (final entry in groups.entries) {
        final matching = stages
            .where((row) => entry.value.contains(row['stageName']))
            .toList();
        Map<String, Object?> primary;
        if (matching.isEmpty) {
          primary = <String, Object?>{
            'id': 'stage_v3_${order}_$projectId',
            'projectId': projectId,
            'stageName': entry.key,
            'stageOrder': order,
            'status': 'notStarted',
            'startDate': null,
            'completedDate': null,
            'assignedUser': '',
            'notes': '',
            'syncStatus': 'pending',
            'createdAt': now,
            'updatedAt': now,
          };
          await db.insert('project_stages', primary);
        } else {
          primary = matching.firstWhere(
            (row) => row['stageName'] == entry.key,
            orElse: () => matching.first,
          );
          final allCompleted = matching.every(
            (row) => row['status'] == 'completed',
          );
          final anyStarted = matching.any(
            (row) => row['status'] != 'notStarted',
          );
          final starts =
              matching
                  .map((row) => row['startDate'] as String?)
                  .whereType<String>()
                  .toList()
                ..sort();
          final completions =
              matching
                  .map((row) => row['completedDate'] as String?)
                  .whereType<String>()
                  .toList()
                ..sort();
          await db.update(
            'project_stages',
            {
              'stageName': entry.key,
              'stageOrder': order,
              'status': allCompleted
                  ? 'completed'
                  : anyStarted
                  ? 'inProgress'
                  : 'notStarted',
              'startDate': starts.firstOrNull,
              'completedDate': allCompleted ? completions.lastOrNull : null,
              'syncStatus': 'pending',
              'updatedAt': now,
            },
            where: 'id = ?',
            whereArgs: [primary['id']],
          );
        }

        final primaryId = primary['id']! as String;
        for (final row in matching) {
          final oldId = row['id']! as String;
          if (oldId == primaryId) continue;
          for (final table in const [
            'project_checklists',
            'project_attachments',
            'project_activities',
            'project_stage_submissions',
          ]) {
            await db.update(
              table,
              {'stageId': primaryId},
              where: 'stageId = ?',
              whereArgs: [oldId],
            );
          }
          await db.delete(
            'project_stages',
            where: 'id = ?',
            whereArgs: [oldId],
          );
        }
        order++;
      }
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
