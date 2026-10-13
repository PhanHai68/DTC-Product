import 'package:dtc_product/features/sales_goal/data/sales_goal_database.dart';
import 'package:dtc_product/features/sales_goal/models/sales_opportunity.dart';
import 'package:dtc_product/features/sales_goal/models/sales_entry.dart';
import 'package:dtc_product/features/sales_goal/repositories/sales_goal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late SalesGoalRepository repository;
  final now = DateTime(2026, 10, 9);
  SalesOpportunity opportunity({
    SalesOpportunityStatus status = SalesOpportunityStatus.negotiating,
  }) => SalesOpportunity(
    customerOrProject: 'Customer',
    estimatedValue: 10000000,
    probability: 60,
    expectedCloseDate: now,
    status: status,
    createdAt: now,
    updatedAt: now,
  );

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final wrapper = SalesGoalDatabase.forTesting(db);
    await wrapper.createSchemaForTesting(db);
    repository = SalesGoalRepository(database: wrapper);
  });
  tearDown(() async => db.close());

  test('concurrent conversions and retries book revenue only once', () async {
    final id = await repository.saveOpportunity(opportunity());
    final results = await Future.wait([
      repository.convertOpportunityToEntry(id, now),
      repository.convertOpportunityToEntry(id, now),
    ]);
    expect(results.first, results.last);
    expect(await repository.convertOpportunityToEntry(id, now), results.first);
    final entries = await repository.getEntriesBetween(
      DateTime(2026, 10),
      DateTime(2026, 11),
    );
    expect(entries, hasLength(1));
    expect(entries.single.amount, 10000000);
    expect(entries.single.sourceOpportunityId, id);
    expect(entries.single.copyWith(notes: 'edited').sourceOpportunityId, id);
    expect(
      (await repository.getOpportunities()).single.status,
      SalesOpportunityStatus.won,
    );
    await expectLater(
      db.insert('sales_entries', entries.single.copyWith(id: 999).toMap()),
      throwsA(isA<DatabaseException>()),
    );
  });

  test(
    'conversion reads current data instead of stale caller values',
    () async {
      final original = opportunity();
      final id = await repository.saveOpportunity(original);
      await repository.saveOpportunity(
        original.copyWith(id: id, estimatedValue: 20000000),
      );
      await repository.convertOpportunityToEntry(id, now);
      expect((await db.query('sales_entries')).single['amount'], 20000000);
    },
  );

  test('failure updating opportunity rolls back revenue', () async {
    final id = await repository.saveOpportunity(opportunity());
    await db.execute(
      '''CREATE TRIGGER fail_conversion BEFORE UPDATE ON sales_opportunities
      BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END''',
    );
    await expectLater(
      repository.convertOpportunityToEntry(id, now),
      throwsA(isA<DatabaseException>()),
    );
    expect(await db.query('sales_entries'), isEmpty);
    expect(
      (await repository.getOpportunities()).single.status,
      SalesOpportunityStatus.negotiating,
    );
    await db.execute('DROP TRIGGER fail_conversion');
    await repository.convertOpportunityToEntry(id, now);
    expect(await db.query('sales_entries'), hasLength(1));
  });

  test(
    'legacy won, lost and deleted opportunities cannot book duplicate revenue',
    () async {
      final won = await repository.saveOpportunity(
        opportunity(status: SalesOpportunityStatus.won),
      );
      expect(await repository.convertOpportunityToEntry(won, now), isNull);
      final lost = await repository.saveOpportunity(
        opportunity(status: SalesOpportunityStatus.lost),
      );
      await expectLater(
        repository.convertOpportunityToEntry(lost, now),
        throwsStateError,
      );
      await repository.deleteOpportunity(lost);
      await expectLater(
        repository.convertOpportunityToEntry(lost, now),
        throwsStateError,
      );
      expect(await db.query('sales_entries'), isEmpty);
    },
  );

  test(
    'v1 migration keeps existing sales entries and adds unique source link',
    () async {
      final legacy = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(legacy.close);
      await legacy.execute('''CREATE TABLE sales_entries(
      id INTEGER PRIMARY KEY AUTOINCREMENT, saleDate TEXT NOT NULL,
      amount INTEGER NOT NULL, customerOrProject TEXT NOT NULL DEFAULT '',
      productOrMachine TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '',
      createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL)''');
      await legacy.insert('sales_entries', {
        'id': 42,
        'saleDate': '2026-10-09',
        'amount': 5000000,
        'notes': 'Original',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
      await SalesGoalDatabase.forTesting(legacy)
          .upgradeSchemaForTesting(legacy, 1);
      final row = (await legacy.query('sales_entries')).single;
      expect(row['id'], 42);
      expect(row['amount'], 5000000);
      expect(row['notes'], 'Original');
      expect(row['sourceOpportunityId'], isNull);
      final indexes = await legacy.rawQuery('PRAGMA index_list(sales_entries)');
      expect(
        indexes.any(
          (index) =>
              index['name'] == 'idx_sales_entries_opportunity' &&
              index['unique'] == 1,
        ),
        isTrue,
      );
    },
  );

  test('editing revenue without provenance keeps its source and cannot book it again', () async {
    final original = opportunity();
    final id = await repository.saveOpportunity(original);
    final entryId = await repository.convertOpportunityToEntry(id, now);
    await repository.saveEntry(
      SalesEntry(
        id: entryId,
        saleDate: now,
        amount: 15000000,
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect((await db.query('sales_entries')).single['sourceOpportunityId'], id);
    await repository.saveOpportunity(original.copyWith(id: id));
    expect(await repository.convertOpportunityToEntry(id, now), entryId);
    expect(await db.query('sales_entries'), hasLength(1));
    expect((await db.query('sales_entries')).single['amount'], 15000000);
  });
}
