import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Test chain migration THẬT (Phase 11, mục 31/64) — không chỉ 4->5 liền
/// kề (đã có ở `grinding_project_followup_migration_test.dart`) mà còn
/// nhảy thẳng từ các version đã thực sự tồn tại (v1-v4) lên v5 hiện tại,
/// giống tình huống người dùng lâu ngày mới cập nhật app.
///
/// Mỗi schema builder dưới đây dựng ĐÚNG cấu trúc bảng của version đó tại
/// thời điểm nó tồn tại (Phase 1-4/6-9) — không giả lập tùy tiện.
Future<void> _createCatalogTables(Database db) async {
  await db.execute('''
    CREATE TABLE grinding_series(
      seriesCode TEXT PRIMARY KEY,
      displayCode TEXT NOT NULL DEFAULT '',
      nameVi TEXT NOT NULL DEFAULT '',
      nameEn TEXT NOT NULL DEFAULT '',
      technology TEXT NOT NULL DEFAULT '',
      pdfPages TEXT NOT NULL DEFAULT '',
      applicationVi TEXT NOT NULL DEFAULT '',
      workingPrincipleVi TEXT NOT NULL DEFAULT '',
      notes TEXT NOT NULL DEFAULT ''
    )
  ''');
  await db.execute('''
    CREATE TABLE grinding_machines(
      machineId TEXT PRIMARY KEY,
      seriesCode TEXT NOT NULL,
      model TEXT NOT NULL,
      active INTEGER NOT NULL DEFAULT 1,
      pdfPage INTEGER,
      capacityMinKgH REAL,
      capacityMaxKgH REAL,
      inputSizeMaxMm REAL,
      inputSizeNote TEXT,
      finenessMin REAL,
      finenessMax REAL,
      finenessUnit TEXT,
      mainMotorKwMin REAL,
      mainMotorKwMax REAL,
      speedRpmMin REAL,
      speedRpmMax REAL,
      lengthMm REAL,
      widthMm REAL,
      heightMm REAL,
      weightKg REAL,
      sourceDocument TEXT,
      editNote TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE grinding_extra_specs(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      machineId TEXT NOT NULL,
      specKey TEXT NOT NULL,
      specValueNumber REAL,
      specValueText TEXT,
      unit TEXT,
      sourcePdfPage INTEGER,
      note TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE grinding_selection_tags(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      seriesCode TEXT NOT NULL,
      tag TEXT NOT NULL,
      note TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE grinding_materials(
      materialId TEXT PRIMARY KEY,
      nameVi TEXT NOT NULL DEFAULT '',
      nameEn TEXT NOT NULL DEFAULT '',
      category TEXT NOT NULL DEFAULT '',
      hardness TEXT,
      fibrous INTEGER,
      oily INTEGER,
      stickyOrPaste INTEGER,
      wet INTEGER,
      heatSensitive INTEGER,
      brittle INTEGER,
      crystalline INTEGER,
      sourceCandidateSeries TEXT,
      sourceBasis TEXT,
      status TEXT NOT NULL DEFAULT 'Needs validation',
      notes TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE grinding_material_series_map(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      materialId TEXT NOT NULL,
      seriesCode TEXT NOT NULL,
      scoreAdjustment REAL NOT NULL DEFAULT 0,
      basisType TEXT,
      reasonVi TEXT,
      sourceBasis TEXT,
      status TEXT NOT NULL DEFAULT 'Needs validation'
    )
  ''');
  await db.execute('''
    CREATE TABLE grinding_ai_config(
      key TEXT PRIMARY KEY,
      value TEXT,
      unit TEXT,
      category TEXT,
      description TEXT,
      editable INTEGER NOT NULL DEFAULT 1
    )
  ''');
  await db.execute('''
    CREATE TABLE grinding_db_meta(
      key TEXT PRIMARY KEY,
      value TEXT
    )
  ''');
}

/// Schema `grinding_selection_projects`/`_project_machines` v2-v4 (CHƯA có
/// cột follow-up Phase 10).
Future<void> _createV2ProjectTables(Database db) async {
  await db.execute('''
    CREATE TABLE grinding_selection_projects(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      projectName TEXT NOT NULL,
      customerName TEXT,
      contactName TEXT,
      contactInfo TEXT,
      materialId TEXT,
      materialName TEXT,
      requiredCapacityKgH REAL,
      requiredFinenessValue REAL,
      requiredFinenessUnit TEXT,
      feedSizeMm REAL,
      maxMotorKw REAL,
      application TEXT,
      notes TEXT,
      status TEXT NOT NULL DEFAULT 'draft',
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE grinding_selection_project_machines(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      projectId INTEGER NOT NULL,
      machineId TEXT NOT NULL,
      role TEXT NOT NULL,
      addedAt TEXT NOT NULL
    )
  ''');
}

/// Schema `grinding_proposals` v3 (Phase 8, CHƯA có cột revision chain).
Future<void> _createV3ProposalTables(Database db) async {
  await db.execute('''
    CREATE TABLE grinding_proposals(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      projectId INTEGER NOT NULL,
      proposalNumber TEXT UNIQUE,
      status TEXT NOT NULL DEFAULT 'draft',
      currency TEXT NOT NULL DEFAULT 'VND',
      machineId TEXT,
      machineUnitPrice REAL,
      machineQuantity REAL,
      discount REAL,
      vatPercent REAL,
      notes TEXT,
      technicalSnapshotJson TEXT,
      revision INTEGER NOT NULL DEFAULT 0,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
      finalizedAt TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE grinding_proposal_line_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      proposalId INTEGER NOT NULL,
      kind TEXT NOT NULL,
      name TEXT NOT NULL,
      quantity REAL,
      unitPrice REAL,
      note TEXT,
      sortOrder INTEGER NOT NULL DEFAULT 0
    )
  ''');
}

/// Schema `grinding_proposals` v4 (Phase 9, ĐÃ có revision chain, CHƯA có
/// follow-up ở project).
Future<void> _createV4ProposalTables(Database db) async {
  await db.execute('''
    CREATE TABLE grinding_proposals(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      projectId INTEGER NOT NULL,
      proposalNumber TEXT,
      status TEXT NOT NULL DEFAULT 'draft',
      currency TEXT NOT NULL DEFAULT 'VND',
      machineId TEXT,
      machineUnitPrice REAL,
      machineQuantity REAL,
      discount REAL,
      vatPercent REAL,
      notes TEXT,
      technicalSnapshotJson TEXT,
      rootProposalId INTEGER,
      revision INTEGER NOT NULL DEFAULT 0,
      validityDays INTEGER,
      deliveryTime TEXT,
      warranty TEXT,
      paymentTerms TEXT,
      sentAt TEXT,
      acceptedAt TEXT,
      rejectedAt TEXT,
      responseNote TEXT,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
      finalizedAt TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE grinding_proposal_line_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      proposalId INTEGER NOT NULL,
      kind TEXT NOT NULL,
      name TEXT NOT NULL,
      quantity REAL,
      unitPrice REAL,
      note TEXT,
      sortOrder INTEGER NOT NULL DEFAULT 0
    )
  ''');
}

Future<void> _seedCatalogMachine(Database db) async {
  await db.insert('grinding_series', {
    'seriesCode': 'BSP_ULTRAFINE',
    'displayCode': 'BSP',
    'nameVi': 'Siêu mịn',
    'nameEn': 'Ultrafine',
  });
  await db.insert('grinding_machines', {
    'machineId': 'M1',
    'seriesCode': 'BSP_ULTRAFINE',
    'model': 'ASP-350',
  });
}

Future<List<String>> _tableNames(Database db) async {
  final rows = await db.query('sqlite_master', where: "type = 'table'", columns: ['name']);
  return rows.map((r) => r['name'] as String).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('v1 -> latest (v5): catalog giữ nguyên, project/proposal tables được tạo mới hoạt động được', () async {
    await _createCatalogTables(database);
    await _seedCatalogMachine(database);

    await GrindingMachineDatabase.instance.upgradeSchemaForTesting(database, 1, 5);

    final machines = await database.query('grinding_machines');
    expect(machines, hasLength(1));
    expect(machines.single['model'], 'ASP-350');

    final tables = await _tableNames(database);
    expect(
      tables,
      containsAll([
        'grinding_selection_projects',
        'grinding_selection_project_machines',
        'grinding_proposals',
        'grinding_proposal_line_items',
      ]),
    );

    // Bảng mới phải hoạt động thật (insert được, có đủ cột follow-up/revision).
    final projectId = await database.insert('grinding_selection_projects', {
      'projectName': 'Dự án sau khi upgrade từ v1',
      'status': 'draft',
      'nextFollowUpAt': DateTime(2026, 10, 1).toIso8601String(),
      'createdAt': DateTime(2026, 9, 24).toIso8601String(),
      'updatedAt': DateTime(2026, 9, 24).toIso8601String(),
    });
    expect(projectId, greaterThan(0));
  });

  test('v2 -> latest (v5): project cũ giữ nguyên, follow-up mặc định null, proposal tables mới tạo', () async {
    await _createCatalogTables(database);
    await _createV2ProjectTables(database);
    await _seedCatalogMachine(database);
    final projectId = await database.insert('grinding_selection_projects', {
      'projectName': 'Dự án v2',
      'customerName': 'Khách hàng v2',
      'status': 'evaluating',
      'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
    });
    await database.insert('grinding_selection_project_machines', {
      'projectId': projectId,
      'machineId': 'M1',
      'role': 'primary',
      'addedAt': DateTime(2026, 1, 1).toIso8601String(),
    });

    await GrindingMachineDatabase.instance.upgradeSchemaForTesting(database, 2, 5);

    final row = (await database.query('grinding_selection_projects', where: 'id = ?', whereArgs: [projectId])).single;
    expect(row['projectName'], 'Dự án v2');
    expect(row['customerName'], 'Khách hàng v2');
    expect(row['nextFollowUpAt'], isNull);
    expect(row['followUpNote'], isNull);

    final relations = await database.query('grinding_selection_project_machines');
    expect(relations, hasLength(1));
    expect(relations.single['machineId'], 'M1');

    final tables = await _tableNames(database);
    expect(tables, containsAll(['grinding_proposals', 'grinding_proposal_line_items']));
  });

  test(
    'v3 -> latest (v5): project + proposal Phase 8 (chưa có revision chain) giữ nguyên, rootProposalId backfill, follow-up cột mới',
    () async {
      await _createCatalogTables(database);
      await _createV2ProjectTables(database);
      await _createV3ProposalTables(database);
      await _seedCatalogMachine(database);
      final projectId = await database.insert('grinding_selection_projects', {
        'projectName': 'Dự án v3',
        'status': 'draft',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      });
      final proposalId = await database.insert('grinding_proposals', {
        'projectId': projectId,
        'proposalNumber': 'GM-2026-0001',
        'status': 'final',
        'currency': 'VND',
        'machineId': 'M1',
        'technicalSnapshotJson': '{"machineId":"M1","model":"ASP-350","capturedAt":"2026-01-01T00:00:00.000"}',
        'revision': 0,
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
        'finalizedAt': DateTime(2026, 1, 1).toIso8601String(),
      });
      await database.insert('grinding_proposal_line_items', {
        'proposalId': proposalId,
        'kind': 'accessory',
        'name': 'Cyclone phụ',
        'quantity': 1,
        'unitPrice': 5000000,
        'sortOrder': 0,
      });

      await GrindingMachineDatabase.instance.upgradeSchemaForTesting(database, 3, 5);

      final proposalRow = (await database.query('grinding_proposals', where: 'id = ?', whereArgs: [proposalId])).single;
      expect(proposalRow['proposalNumber'], 'GM-2026-0001');
      expect(proposalRow['status'], 'final');
      expect(proposalRow['rootProposalId'], proposalId);
      expect(proposalRow['revision'], 0);
      expect(
        proposalRow['technicalSnapshotJson'],
        '{"machineId":"M1","model":"ASP-350","capturedAt":"2026-01-01T00:00:00.000"}',
      );

      final items = await database.query('grinding_proposal_line_items', where: 'proposalId = ?', whereArgs: [proposalId]);
      expect(items, hasLength(1));
      expect(items.single['name'], 'Cyclone phụ');

      final projectRow = (await database.query('grinding_selection_projects', where: 'id = ?', whereArgs: [projectId])).single;
      expect(projectRow['nextFollowUpAt'], isNull);
    },
  );

  test(
    'v4 -> latest (v5): project + proposal chain + revision + line items + snapshot + status/timestamps giữ nguyên toàn bộ, follow-up mới null',
    () async {
      await _createCatalogTables(database);
      await _createV2ProjectTables(database);
      await _createV4ProposalTables(database);
      await _seedCatalogMachine(database);

      final projectId = await database.insert('grinding_selection_projects', {
        'projectName': 'Dự án v4 đầy đủ',
        'customerName': 'Khách hàng v4',
        'status': 'selected',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 2, 1).toIso8601String(),
      });
      final r0Id = await database.insert('grinding_proposals', {
        'projectId': projectId,
        'proposalNumber': 'GM-2026-0012',
        'status': 'sent',
        'currency': 'USD',
        'machineId': 'M1',
        'technicalSnapshotJson': '{"machineId":"M1","model":"ASP-350","capturedAt":"2026-01-01T00:00:00.000"}',
        'rootProposalId': null,
        'revision': 0,
        'sentAt': DateTime(2026, 1, 15).toIso8601String(),
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 15).toIso8601String(),
        'finalizedAt': DateTime(2026, 1, 1).toIso8601String(),
      });
      await database.rawUpdate('UPDATE grinding_proposals SET rootProposalId = ? WHERE id = ?', [r0Id, r0Id]);
      final r1Id = await database.insert('grinding_proposals', {
        'projectId': projectId,
        'proposalNumber': 'GM-2026-0012',
        'status': 'accepted',
        'currency': 'USD',
        'machineId': 'M1',
        'rootProposalId': r0Id,
        'revision': 1,
        'acceptedAt': DateTime(2026, 2, 1).toIso8601String(),
        'createdAt': DateTime(2026, 1, 20).toIso8601String(),
        'updatedAt': DateTime(2026, 2, 1).toIso8601String(),
      });
      await database.insert('grinding_proposal_line_items', {
        'proposalId': r1Id,
        'kind': 'additional_cost',
        'name': 'Shipping',
        'quantity': 1,
        'unitPrice': 500,
        'sortOrder': 0,
      });

      await GrindingMachineDatabase.instance.upgradeSchemaForTesting(database, 4, 5);

      final proposals = await database.query(
        'grinding_proposals',
        where: 'projectId = ?',
        whereArgs: [projectId],
        orderBy: 'revision ASC',
      );
      expect(proposals, hasLength(2));
      expect(proposals[0]['status'], 'sent');
      expect(proposals[0]['sentAt'], DateTime(2026, 1, 15).toIso8601String());
      expect(proposals[0]['technicalSnapshotJson'], isNotNull);
      expect(proposals[1]['status'], 'accepted');
      expect(proposals[1]['acceptedAt'], DateTime(2026, 2, 1).toIso8601String());
      expect(proposals[1]['rootProposalId'], r0Id);

      final items = await database.query('grinding_proposal_line_items', where: 'proposalId = ?', whereArgs: [r1Id]);
      expect(items, hasLength(1));
      expect(items.single['name'], 'Shipping');

      final projectRow = (await database.query('grinding_selection_projects', where: 'id = ?', whereArgs: [projectId])).single;
      expect(projectRow['projectName'], 'Dự án v4 đầy đủ');
      expect(projectRow['nextFollowUpAt'], isNull);
      expect(projectRow['followUpNote'], isNull);
    },
  );

  test('v5 fresh install: schema đầy đủ, đủ bảng, catalog trống hợp lệ (chưa import)', () async {
    await GrindingMachineDatabase.instance.createSchemaForTesting(database);

    final tables = await _tableNames(database);
    expect(
      tables,
      containsAll([
        'grinding_series',
        'grinding_machines',
        'grinding_extra_specs',
        'grinding_selection_tags',
        'grinding_materials',
        'grinding_material_series_map',
        'grinding_ai_config',
        'grinding_db_meta',
        'grinding_selection_projects',
        'grinding_selection_project_machines',
        'grinding_proposals',
        'grinding_proposal_line_items',
      ]),
    );

    final projectId = await database.insert('grinding_selection_projects', {
      'projectName': 'Fresh install',
      'status': 'draft',
      'nextFollowUpAt': DateTime(2026, 10, 1).toIso8601String(),
      'followUpNote': 'Note',
      'createdAt': DateTime(2026, 9, 24).toIso8601String(),
      'updatedAt': DateTime(2026, 9, 24).toIso8601String(),
    });
    final proposalId = await database.insert('grinding_proposals', {
      'projectId': projectId,
      'status': 'draft',
      'currency': 'VND',
      'rootProposalId': null,
      'revision': 0,
      'createdAt': DateTime(2026, 9, 24).toIso8601String(),
      'updatedAt': DateTime(2026, 9, 24).toIso8601String(),
    });
    expect(proposalId, greaterThan(0));
  });
}
