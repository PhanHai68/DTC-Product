import 'package:dtc_product/features/sales_goal/data/sales_goal_database.dart';
import 'package:dtc_product/features/sales_goal/models/sales_entry.dart';
import 'package:dtc_product/features/sales_goal/models/sales_opportunity.dart';
import 'package:dtc_product/features/sales_goal/models/sales_target.dart';
import 'package:dtc_product/features/sales_goal/providers/sales_goal_provider.dart';
import 'package:dtc_product/features/sales_goal/repositories/sales_goal_repository.dart';
import 'package:dtc_product/features/sales_goal/screens/sales_goal_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late SalesGoalRepository repository;
  late SalesGoalProvider provider;
  final fixedNow = DateTime(2026, 9, 25, 10);

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final wrapper = SalesGoalDatabase.forTesting(database);
    await wrapper.createSchemaForTesting(database);
    repository = SalesGoalRepository(database: wrapper);
    provider = SalesGoalProvider(repository: repository, now: () => fixedNow);
  });

  tearDown(() async => database.close());

  test('provider tổng hợp mục tiêu, doanh số và dự báo đúng', () async {
    await _seed(repository, fixedNow);
    await provider.load();

    expect(provider.error, isNull);
    expect(provider.summary?.monthlyTarget, 100000000);
    expect(provider.summary?.monthlyActual, 40000000);
    expect(provider.summary?.quarterlyTarget, 300000000);
    expect(provider.summary?.weightedPipeline, 30000000);
    expect(provider.summary?.projectedTotal, 70000000);
    expect(provider.entries, hasLength(1));
    expect(provider.opportunities, hasLength(1));
    expect(provider.history, hasLength(12));
    expect(provider.quarterHistory, hasLength(8));
  });

  testWidgets('Dashboard hiển thị các khu vực chính bằng tiếng Việt', (
    tester,
  ) async {
    await _seed(repository, fixedNow);
    await provider.load();
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<SalesGoalProvider>.value(
        value: provider,
        child: const MaterialApp(home: SalesGoalDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mục tiêu doanh số'), findsOneWidget);
    expect(find.text('Mục tiêu tháng'), findsOneWidget);
    expect(find.text('Tiến độ quý hiện tại'), findsOneWidget);
    expect(find.text('Dự báo tháng'), findsOneWidget);
    expect(find.text('Tập trung hôm nay'), findsOneWidget);
    expect(find.text('Cơ hội'), findsOneWidget);
    expect(find.textContaining('Pipeline'), findsNothing);
  });
}

Future<void> _seed(SalesGoalRepository repository, DateTime now) async {
  await repository.saveTarget(
    SalesTarget(
      period: SalesTargetPeriod.month,
      year: 2026,
      periodNumber: 9,
      amount: 100000000,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repository.saveTarget(
    SalesTarget(
      period: SalesTargetPeriod.quarter,
      year: 2026,
      periodNumber: 3,
      amount: 300000000,
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repository.saveEntry(
    SalesEntry(
      saleDate: now,
      amount: 40000000,
      customerOrProject: 'Khách hàng A',
      createdAt: now,
      updatedAt: now,
    ),
  );
  await repository.saveOpportunity(
    SalesOpportunity(
      customerOrProject: 'Dự án B',
      estimatedValue: 50000000,
      probability: 60,
      expectedCloseDate: DateTime(2026, 9, 30),
      status: SalesOpportunityStatus.negotiating,
      createdAt: now,
      updatedAt: now,
    ),
  );
}
