import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Dựng thủ công bảng `grinding_proposals` ĐÚNG schema v3 thật (Phase 8,
/// trước khi có cột revision chain) — mô phỏng 1 database đã cài v3 trước
/// khi nâng cấp lên v4, để test migration thật thay vì chỉ test schema mới.
/// Kèm `grinding_selection_projects` schema v2-v4 (chưa có cột follow-up
/// Phase 10) vì 1 database v3 thật LUÔN có bảng này (tạo từ v2) — thiếu nó
/// thì `_upgrade` gọi `_addProjectFollowUpColumns` sẽ lỗi "no such table",
/// điều không bao giờ xảy ra với database thật.
Future<void> _createV3Schema(Database db) async {
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
    'Migration 3->4: proposal Phase 8 (Draft) còn nguyên, rootProposalId backfill = id, revision vẫn 0',
    () async {
      await _createV3Schema(database);
      final draftId = await database.insert('grinding_proposals', {
        'projectId': 1,
        'proposalNumber': 'GM-2026-0001',
        'status': 'draft',
        'currency': 'VND',
        'machineId': 'M1',
        'machineUnitPrice': 100000000,
        'machineQuantity': 1,
        'revision': 0,
        'createdAt': DateTime(2026, 9, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 9, 1).toIso8601String(),
      });

      await GrindingMachineDatabase.instance.upgradeSchemaForTesting(database, 3, 4);

      final rows = await database.query(
        'grinding_proposals',
        where: 'id = ?',
        whereArgs: [draftId],
      );
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row['proposalNumber'], 'GM-2026-0001');
      expect(row['status'], 'draft');
      expect(row['machineUnitPrice'], 100000000);
      expect(row['revision'], 0);
      expect(row['rootProposalId'], draftId, reason: 'Proposal Phase 8 phải backfill thành R0 của chính nó.');
      // Cột mới phải tồn tại (không throw khi query) và mặc định null.
      expect(row['sentAt'], isNull);
      expect(row['acceptedAt'], isNull);
      expect(row['validityDays'], isNull);
    },
  );

  test('Migration 3->4: proposal Final còn nguyên technicalSnapshotJson', () async {
    await _createV3Schema(database);
    const snapshotJson = '{"machineId":"M1","model":"ASP-350","capturedAt":"2026-09-01T00:00:00.000"}';
    final finalId = await database.insert('grinding_proposals', {
      'projectId': 1,
      'proposalNumber': 'GM-2026-0002',
      'status': 'final',
      'currency': 'VND',
      'machineId': 'M1',
      'technicalSnapshotJson': snapshotJson,
      'revision': 0,
      'createdAt': DateTime(2026, 9, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 9, 1).toIso8601String(),
      'finalizedAt': DateTime(2026, 9, 1).toIso8601String(),
    });

    await GrindingMachineDatabase.instance.upgradeSchemaForTesting(database, 3, 4);

    final row = (await database.query(
      'grinding_proposals',
      where: 'id = ?',
      whereArgs: [finalId],
    )).single;
    expect(row['technicalSnapshotJson'], snapshotJson);
    expect(row['status'], 'final');
    expect(row['rootProposalId'], finalId);
  });

  test('Migration 3->4: line items còn nguyên, không bị đụng', () async {
    await _createV3Schema(database);
    final proposalId = await database.insert('grinding_proposals', {
      'projectId': 1,
      'status': 'draft',
      'currency': 'VND',
      'revision': 0,
      'createdAt': DateTime(2026, 9, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 9, 1).toIso8601String(),
    });
    await database.insert('grinding_proposal_line_items', {
      'proposalId': proposalId,
      'kind': 'accessory',
      'name': 'Cyclone phụ',
      'quantity': 1,
      'unitPrice': 10000000,
      'sortOrder': 0,
    });

    await GrindingMachineDatabase.instance.upgradeSchemaForTesting(database, 3, 4);

    final items = await database.query(
      'grinding_proposal_line_items',
      where: 'proposalId = ?',
      whereArgs: [proposalId],
    );
    expect(items, hasLength(1));
    expect(items.single['name'], 'Cyclone phụ');
  });

  test('Migration 3->4: nhiều proposal cũ -> mỗi cái backfill rootProposalId RIÊNG (không gộp nhầm)', () async {
    await _createV3Schema(database);
    final id1 = await database.insert('grinding_proposals', {
      'projectId': 1,
      'status': 'draft',
      'currency': 'VND',
      'revision': 0,
      'createdAt': DateTime(2026, 9, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 9, 1).toIso8601String(),
    });
    final id2 = await database.insert('grinding_proposals', {
      'projectId': 1,
      'status': 'draft',
      'currency': 'VND',
      'revision': 0,
      'createdAt': DateTime(2026, 9, 2).toIso8601String(),
      'updatedAt': DateTime(2026, 9, 2).toIso8601String(),
    });

    await GrindingMachineDatabase.instance.upgradeSchemaForTesting(database, 3, 4);

    final row1 = (await database.query('grinding_proposals', where: 'id = ?', whereArgs: [id1])).single;
    final row2 = (await database.query('grinding_proposals', where: 'id = ?', whereArgs: [id2])).single;
    expect(row1['rootProposalId'], id1);
    expect(row2['rootProposalId'], id2);
    expect(row1['rootProposalId'], isNot(row2['rootProposalId']));
  });

  test('Fresh install thẳng lên v4: tạo đủ schema, có UNIQUE(rootProposalId, revision)', () async {
    await GrindingMachineDatabase.instance.createSchemaForTesting(database);

    final id = await database.insert('grinding_proposals', {
      'projectId': 1,
      'status': 'draft',
      'currency': 'VND',
      'rootProposalId': 1,
      'revision': 0,
      'createdAt': DateTime(2026, 9, 1).toIso8601String(),
      'updatedAt': DateTime(2026, 9, 1).toIso8601String(),
    });
    expect(id, greaterThan(0));

    // UNIQUE(rootProposalId, revision) phải chặn insert trùng.
    await expectLater(
      database.insert('grinding_proposals', {
        'projectId': 1,
        'status': 'draft',
        'currency': 'VND',
        'rootProposalId': 1,
        'revision': 0,
        'createdAt': DateTime(2026, 9, 1).toIso8601String(),
        'updatedAt': DateTime(2026, 9, 1).toIso8601String(),
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
