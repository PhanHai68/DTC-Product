import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Dựng thủ công schema v4 thật (Phase 9, đủ project + proposal + revision
/// chain, CHƯA có cột follow-up) — mô phỏng database đã cài v4 trước khi
/// nâng cấp lên v5 (Phase 10), test migration thật thay vì chỉ test schema
/// mới.
Future<void> _createV4Schema(Database db) async {
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

  test(
    'Migration 4->5: Project cũ còn nguyên, cột follow-up mới mặc định null',
    () async {
      await _createV4Schema(database);
      final projectId = await database.insert('grinding_selection_projects', {
        'projectName': 'Trà xanh Bảo Lộc',
        'customerName': 'Công ty ABC',
        'status': 'evaluating',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      });

      await GrindingMachineDatabase.instance.upgradeSchemaForTesting(database, 4, 5);

      final row = (await database.query(
        'grinding_selection_projects',
        where: 'id = ?',
        whereArgs: [projectId],
      )).single;
      expect(row['projectName'], 'Trà xanh Bảo Lộc');
      expect(row['status'], 'evaluating');
      expect(row['nextFollowUpAt'], isNull);
      expect(row['followUpNote'], isNull);
    },
  );

  test('Migration 4->5: Proposal chain + revision + line items + snapshot còn nguyên', () async {
    await _createV4Schema(database);
    const snapshotJson = '{"machineId":"M1","model":"ASP-350","capturedAt":"2026-09-01T00:00:00.000"}';
    final projectId = await database.insert('grinding_selection_projects', {
      'projectName': 'Dự án X',
      'status': 'draft',
      'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
    });
    final r0Id = await database.insert('grinding_proposals', {
      'projectId': projectId,
      'proposalNumber': 'GM-2026-0001',
      'status': 'final',
      'currency': 'VND',
      'machineId': 'M1',
      'technicalSnapshotJson': snapshotJson,
      'rootProposalId': null,
      'revision': 0,
      'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      'finalizedAt': DateTime(2026, 1, 1).toIso8601String(),
    });
    await database.rawUpdate(
      'UPDATE grinding_proposals SET rootProposalId = ? WHERE id = ?',
      [r0Id, r0Id],
    );
    final r1Id = await database.insert('grinding_proposals', {
      'projectId': projectId,
      'proposalNumber': 'GM-2026-0001',
      'status': 'sent',
      'currency': 'VND',
      'machineId': 'M1',
      'rootProposalId': r0Id,
      'revision': 1,
      'createdAt': DateTime(2026, 2, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 2, 1).toIso8601String(),
    });
    await database.insert('grinding_proposal_line_items', {
      'proposalId': r1Id,
      'kind': 'accessory',
      'name': 'Cyclone phụ',
      'quantity': 1,
      'unitPrice': 10000000,
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
    expect(proposals[0]['revision'], 0);
    expect(proposals[0]['technicalSnapshotJson'], snapshotJson);
    expect(proposals[1]['revision'], 1);
    expect(proposals[1]['rootProposalId'], r0Id);

    final items = await database.query(
      'grinding_proposal_line_items',
      where: 'proposalId = ?',
      whereArgs: [r1Id],
    );
    expect(items, hasLength(1));
    expect(items.single['name'], 'Cyclone phụ');
  });

  test('Fresh install thẳng lên v5: grinding_selection_projects có sẵn cột follow-up', () async {
    await GrindingMachineDatabase.instance.createSchemaForTesting(database);

    final id = await database.insert('grinding_selection_projects', {
      'projectName': 'Dự án mới',
      'status': 'draft',
      'nextFollowUpAt': DateTime(2026, 10, 1).toIso8601String(),
      'followUpNote': 'Gọi lại sau khi gửi báo giá',
      'createdAt': DateTime(2026, 9, 24).toIso8601String(),
      'updatedAt': DateTime(2026, 9, 24).toIso8601String(),
    });

    final row = (await database.query(
      'grinding_selection_projects',
      where: 'id = ?',
      whereArgs: [id],
    )).single;
    expect(row['nextFollowUpAt'], DateTime(2026, 10, 1).toIso8601String());
    expect(row['followUpNote'], 'Gọi lại sau khi gửi báo giá');
  });

  test('Migration 1->5 (v1 chưa có project/proposal tables) chạy trọn vẹn, không lỗi', () async {
    // v1 chỉ có catalog máy — dùng _create thật cho v1 sẽ tạo catalog + (từ
    // Phase 9/10) project/proposal luôn vì _create luôn build full schema
    // hiện tại; ở đây ta mô phỏng đúng tình huống oldVersion=1 (DB rất cũ)
    // bằng cách chỉ gọi upgrade trực tiếp trên DB rỗng.
    await GrindingMachineDatabase.instance.upgradeSchemaForTesting(database, 1, 5);

    final tables = await database.query(
      'sqlite_master',
      where: "type = 'table'",
      columns: ['name'],
    );
    final names = tables.map((t) => t['name'] as String).toSet();
    expect(names, containsAll([
      'grinding_selection_projects',
      'grinding_selection_project_machines',
      'grinding_proposals',
      'grinding_proposal_line_items',
    ]));

    final id = await database.insert('grinding_selection_projects', {
      'projectName': 'X',
      'status': 'draft',
      'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
    });
    expect(id, greaterThan(0));
  });
}
