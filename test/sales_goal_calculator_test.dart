import 'package:dtc_product/features/sales_goal/models/sales_entry.dart';
import 'package:dtc_product/features/sales_goal/models/sales_opportunity.dart';
import 'package:dtc_product/features/sales_goal/services/sales_goal_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final timestamp = DateTime(2026, 9, 25, 10);

  SalesEntry entry(DateTime date, int amount) => SalesEntry(
    saleDate: date,
    amount: amount,
    createdAt: timestamp,
    updatedAt: timestamp,
  );

  SalesOpportunity opportunity({
    required DateTime closeDate,
    required int value,
    required int probability,
    SalesOpportunityStatus status = SalesOpportunityStatus.tracking,
  }) => SalesOpportunity(
    customerOrProject: 'Khách hàng A',
    estimatedValue: value,
    probability: probability,
    expectedCloseDate: closeDate,
    status: status,
    createdAt: timestamp,
    updatedAt: timestamp,
  );

  test('tách đúng doanh số tháng, quý và số ngày còn lại', () {
    final summary = SalesGoalCalculator.calculate(
      now: timestamp,
      monthlyTarget: 100000000,
      quarterlyTarget: 300000000,
      entries: [
        entry(DateTime(2026, 7, 2), 10000000),
        entry(DateTime(2026, 9, 1), 20000000),
        entry(DateTime(2026, 9, 25), 30000000),
        entry(DateTime(2026, 10, 1), 90000000),
      ],
      opportunities: const [],
    );

    expect(summary.monthlyActual, 50000000);
    expect(summary.quarterlyActual, 60000000);
    expect(summary.monthlyRemaining, 50000000);
    expect(summary.daysElapsed, 25);
    expect(summary.daysRemaining, 6);
    expect(summary.requiredPerDay, 8333334);
  });

  test('dự báo chỉ tính pipeline mở có ngày chốt trong tháng', () {
    final summary = SalesGoalCalculator.calculate(
      now: timestamp,
      monthlyTarget: 200000000,
      quarterlyTarget: 0,
      entries: [entry(DateTime(2026, 9, 10), 20000000)],
      opportunities: [
        opportunity(
          closeDate: DateTime(2026, 9, 28),
          value: 100000000,
          probability: 50,
        ),
        opportunity(
          closeDate: DateTime(2026, 9, 29),
          value: 90000000,
          probability: 100,
          status: SalesOpportunityStatus.won,
        ),
        opportunity(
          closeDate: DateTime(2026, 10, 1),
          value: 50000000,
          probability: 100,
        ),
      ],
    );

    expect(summary.weightedPipeline, 50000000);
    expect(summary.projectedTotal, 70000000);
    expect(summary.projectedGap, 130000000);
  });

  test('ghi nhận đủ các mốc và mốc vượt mục tiêu', () {
    final summary = SalesGoalCalculator.calculate(
      now: timestamp,
      monthlyTarget: 100,
      quarterlyTarget: 0,
      entries: [entry(DateTime(2026, 9, 10), 120)],
      opportunities: const [],
    );

    expect(SalesGoalCalculator.reachedMilestones(summary), [
      25,
      50,
      75,
      100,
      101,
    ]);
  });

  test('xử lý đúng năm nhuận và ranh giới quý cuối năm', () {
    final february = SalesGoalCalculator.calculate(
      now: DateTime(2028, 2, 29),
      monthlyTarget: 0,
      quarterlyTarget: 0,
      entries: const [],
      opportunities: const [],
    );
    expect(february.daysRemaining, 1);
    expect(february.requiredPerDay, 0);
    expect(SalesGoalCalculator.reachedMilestones(february), isEmpty);

    final december = SalesGoalCalculator.calculate(
      now: DateTime(2026, 12, 15),
      monthlyTarget: 100,
      quarterlyTarget: 500,
      entries: [
        entry(DateTime(2026, 10, 1), 100),
        entry(DateTime(2026, 12, 1), 200),
        entry(DateTime(2027, 1, 1), 400),
      ],
      opportunities: const [],
    );
    expect(december.monthlyActual, 200);
    expect(december.quarterlyActual, 300);
  });
}
