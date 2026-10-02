class SalesGoalSummary {
  const SalesGoalSummary({
    required this.monthlyTarget,
    required this.monthlyActual,
    required this.quarterlyTarget,
    required this.quarterlyActual,
    required this.weightedPipeline,
    required this.daysElapsed,
    required this.daysRemaining,
  });

  final int monthlyTarget;
  final int monthlyActual;
  final int quarterlyTarget;
  final int quarterlyActual;
  final int weightedPipeline;
  final int daysElapsed;
  final int daysRemaining;

  int get monthlyRemaining =>
      (monthlyTarget - monthlyActual).clamp(0, monthlyTarget);
  double get monthlyProgress =>
      monthlyTarget <= 0 ? 0 : (monthlyActual / monthlyTarget).clamp(0, 1);
  double get rawMonthlyProgress =>
      monthlyTarget <= 0 ? 0 : monthlyActual / monthlyTarget;
  int get projectedTotal => monthlyActual + weightedPipeline;
  int get projectedGap =>
      (monthlyTarget - projectedTotal).clamp(0, monthlyTarget);
  int get requiredPerDay => daysRemaining <= 0
      ? monthlyRemaining
      : (monthlyRemaining / daysRemaining).ceil();
  double get quarterlyProgress => quarterlyTarget <= 0
      ? 0
      : (quarterlyActual / quarterlyTarget).clamp(0, 1);
}

class SalesMonthHistory {
  const SalesMonthHistory({
    required this.year,
    required this.month,
    required this.target,
    required this.actual,
  });

  final int year;
  final int month;
  final int target;
  final int actual;

  double get progress => target <= 0 ? 0 : actual / target;
}

class SalesQuarterHistory {
  const SalesQuarterHistory({
    required this.year,
    required this.quarter,
    required this.target,
    required this.actual,
  });

  final int year;
  final int quarter;
  final int target;
  final int actual;

  double get progress => target <= 0 ? 0 : actual / target;
}
