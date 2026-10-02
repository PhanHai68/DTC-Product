import 'package:flutter/material.dart';

import '../../../theme/dtc_palette.dart';
import '../models/sales_goal_summary.dart';
import '../utils/sales_goal_format.dart';

class SalesGoalProgressCard extends StatelessWidget {
  const SalesGoalProgressCard({super.key, required this.summary});

  final SalesGoalSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final percent = (summary.rawMonthlyProgress * 100).round();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mục tiêu tháng',
                    style: TextStyle(
                      color: palette.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$percent%',
                  style: TextStyle(
                    color: palette.cyan,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: summary.monthlyProgress,
                minHeight: 12,
                backgroundColor: palette.border,
                valueColor: AlwaysStoppedAnimation(palette.cyan),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 22,
              runSpacing: 14,
              children: [
                _Metric(
                  label: 'Mục tiêu',
                  value: formatSalesMoney(summary.monthlyTarget),
                ),
                _Metric(
                  label: 'Đã đạt',
                  value: formatSalesMoney(summary.monthlyActual),
                ),
                _Metric(
                  label: 'Còn thiếu',
                  value: formatSalesMoney(summary.monthlyRemaining),
                ),
                _Metric(
                  label: 'Cần mỗi ngày',
                  value: formatSalesMoney(summary.requiredPerDay),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Đã qua ${summary.daysElapsed} ngày · còn ${summary.daysRemaining} ngày (kể cả hôm nay)',
              style: TextStyle(color: palette.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return SizedBox(
      width: 135,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: palette.muted, fontSize: 12)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: palette.ink,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
