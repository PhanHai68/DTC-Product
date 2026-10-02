import 'package:dtc_product/features/sales_goal/data/sales_goal_database.dart';
import 'package:dtc_product/features/sales_goal/models/sales_entry.dart';
import 'package:dtc_product/features/sales_goal/models/sales_focus_task.dart';
import 'package:dtc_product/features/sales_goal/models/sales_opportunity.dart';
import 'package:dtc_product/features/sales_goal/models/sales_target.dart';
import 'package:dtc_product/features/sales_goal/repositories/sales_goal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late SalesGoalRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final wrapper = SalesGoalDatabase.forTesting(database);
    await wrapper.createSchemaForTesting(database);
    repository = SalesGoalRepository(database: wrapper);
  });

  tearDown(() async => database.close());

  test('schema nằm trong 5 bảng sales_goal độc lập', () async {
    final rows = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'sales_%'",
    );
    final names = rows.map((row) => row['name'] as String).toSet();
    expect(
      names,
      containsAll(const {
        'sales_targets',
        'sales_entries',
        'sales_opportunities',
        'sales_focus_tasks',
        'sales_milestones',
      }),
    );
  });

  test('lưu mục tiêu theo kỳ không làm mất mục tiêu kỳ trước', () async {
    final now = DateTime(2026, 9, 25);
    for (final month in [8, 9]) {
      await repository.saveTarget(
        SalesTarget(
          period: SalesTargetPeriod.month,
          year: 2026,
          periodNumber: month,
          amount: month * 1000000,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    expect(
      (await repository.getTarget(SalesTargetPeriod.month, 2026, 8))?.amount,
      8000000,
    );
    expect(
      (await repository.getTarget(SalesTargetPeriod.month, 2026, 9))?.amount,
      9000000,
    );
  });

  test('CRUD doanh số, pipeline và việc tập trung hoạt động độc lập', () async {
    final now = DateTime(2026, 9, 25);
    final entryId = await repository.saveEntry(
      SalesEntry(
        saleDate: now,
        amount: 12000000,
        customerOrProject: 'Dự án A',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final opportunityId = await repository.saveOpportunity(
      SalesOpportunity(
        customerOrProject: 'Khách hàng B',
        estimatedValue: 50000000,
        probability: 60,
        expectedCloseDate: DateTime(2026, 9, 30),
        status: SalesOpportunityStatus.negotiating,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final taskId = await repository.saveFocusTask(
      SalesFocusTask(
        title: 'Gọi lại khách hàng B',
        focusDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(
      await repository.getEntriesBetween(DateTime(2026, 9), DateTime(2026, 10)),
      hasLength(1),
    );
    expect(await repository.getOpportunities(), hasLength(1));
    expect(await repository.getFocusTasks(now), hasLength(1));

    await repository.deleteEntry(entryId);
    await repository.deleteOpportunity(opportunityId);
    await repository.deleteFocusTask(taskId);
    expect(
      await repository.getEntriesBetween(DateTime(2026, 9), DateTime(2026, 10)),
      isEmpty,
    );
    expect(await repository.getOpportunities(), isEmpty);
    expect(await repository.getFocusTasks(now), isEmpty);
  });

  test('mốc thành tích chỉ được ghi một lần trong cùng tháng', () async {
    final first = await repository.recordMilestones(
      year: 2026,
      month: 9,
      milestones: const [25, 50],
    );
    final repeated = await repository.recordMilestones(
      year: 2026,
      month: 9,
      milestones: const [25, 50],
    );

    expect(first, [25, 50]);
    expect(repeated, isEmpty);
  });
}
