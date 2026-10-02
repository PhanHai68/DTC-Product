import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/dtc_palette.dart';
import '../models/sales_entry.dart';
import '../models/sales_goal_summary.dart';
import '../utils/sales_goal_format.dart';

class SalesGoalChart extends StatelessWidget {
  const SalesGoalChart({super.key, required this.history});

  final List<SalesMonthHistory> history;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final visible = history.length > 6
        ? history.sublist(history.length - 6)
        : history;
    final maxValue = visible.fold<int>(1, (current, item) {
      return math.max(current, math.max(item.target, item.actual));
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mục tiêu và thực đạt 6 tháng gần nhất',
              style: TextStyle(
                color: palette.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  maxY: maxValue * 1.15,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= visible.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'T${visible[index].month}',
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(visible.length, (index) {
                    final item = visible[index];
                    return BarChartGroupData(
                      x: index,
                      barsSpace: 3,
                      barRods: [
                        BarChartRodData(
                          toY: item.target.toDouble(),
                          width: 7,
                          color: palette.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        BarChartRodData(
                          toY: item.actual.toDouble(),
                          width: 7,
                          color: palette.cyan,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _Legend(color: palette.border, label: 'Mục tiêu'),
                const SizedBox(width: 18),
                _Legend(color: palette.cyan, label: 'Thực đạt'),
              ],
            ),
            if (visible.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Tháng gần nhất: ${formatSalesMoney(visible.last.actual)}',
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SalesDailyChart extends StatelessWidget {
  const SalesDailyChart({
    super.key,
    required this.entries,
    required this.month,
  });

  final List<SalesEntry> entries;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totals = <int, int>{};
    for (final entry in entries) {
      totals.update(
        entry.saleDate.day,
        (value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    final maxValue = totals.values.fold<int>(1, math.max);
    final labelDays = <int>{1, 5, 10, 15, 20, 25, daysInMonth};

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Doanh số theo ngày trong tháng',
              style: TextStyle(
                color: palette.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  maxY: maxValue * 1.15,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final day = value.toInt();
                          if (!labelDays.contains(day)) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(daysInMonth, (index) {
                    final day = index + 1;
                    return BarChartGroupData(
                      x: day,
                      barRods: [
                        BarChartRodData(
                          toY: (totals[day] ?? 0).toDouble(),
                          width: 5,
                          color: totals.containsKey(day)
                              ? palette.cyan
                              : palette.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 11, height: 11, color: color),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}
