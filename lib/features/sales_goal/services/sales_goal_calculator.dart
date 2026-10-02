import '../models/sales_entry.dart';
import '../models/sales_goal_summary.dart';
import '../models/sales_opportunity.dart';

abstract final class SalesGoalCalculator {
  static SalesGoalSummary calculate({
    required DateTime now,
    required int monthlyTarget,
    required int quarterlyTarget,
    required Iterable<SalesEntry> entries,
    required Iterable<SalesOpportunity> opportunities,
  }) {
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);
    final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    final quarterStart = DateTime(now.year, quarterStartMonth);
    final quarterEnd = DateTime(now.year, quarterStartMonth + 3);

    final monthlyActual = entries
        .where((entry) => _inRange(entry.saleDate, monthStart, monthEnd))
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final quarterlyActual = entries
        .where((entry) => _inRange(entry.saleDate, quarterStart, quarterEnd))
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final weightedPipeline = opportunities
        .where(
          (item) =>
              item.status.isOpen &&
              _inRange(item.expectedCloseDate, monthStart, monthEnd),
        )
        .fold<int>(
          0,
          (sum, item) =>
              sum + (item.estimatedValue * item.probability / 100).round(),
        );
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    return SalesGoalSummary(
      monthlyTarget: monthlyTarget,
      monthlyActual: monthlyActual,
      quarterlyTarget: quarterlyTarget,
      quarterlyActual: quarterlyActual,
      weightedPipeline: weightedPipeline,
      daysElapsed: now.day,
      daysRemaining: daysInMonth - now.day + 1,
    );
  }

  static List<int> reachedMilestones(SalesGoalSummary summary) {
    if (summary.monthlyTarget <= 0) return const [];
    final percent = summary.rawMonthlyProgress * 100;
    return [
      if (percent >= 25) 25,
      if (percent >= 50) 50,
      if (percent >= 75) 75,
      if (percent >= 100) 100,
      if (percent > 100) 101,
    ];
  }

  static bool _inRange(DateTime date, DateTime start, DateTime end) =>
      !date.isBefore(start) && date.isBefore(end);
}
