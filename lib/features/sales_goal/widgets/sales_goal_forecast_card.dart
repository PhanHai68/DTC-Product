import 'package:flutter/material.dart';

import '../../../theme/dtc_palette.dart';
import '../models/sales_goal_summary.dart';
import '../utils/sales_goal_format.dart';

class SalesGoalForecastCard extends StatelessWidget {
  const SalesGoalForecastCard({super.key, required this.summary});

  final SalesGoalSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_graph_rounded, color: palette.cyan),
                const SizedBox(width: 8),
                Text(
                  'Dự báo tháng',
                  style: TextStyle(
                    color: palette.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Row(
              label: 'Doanh số thực tế',
              value: formatSalesMoney(summary.monthlyActual),
            ),
            _Row(
              label: 'Cơ hội theo xác suất',
              value: formatSalesMoney(summary.weightedPipeline),
            ),
            const Divider(height: 22),
            _Row(
              label: 'Dự kiến đạt',
              value: formatSalesMoney(summary.projectedTotal),
              strong: true,
            ),
            _Row(
              label: 'Thiếu hụt dự kiến',
              value: formatSalesMoney(summary.projectedGap),
              strong: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Cơ hội bán hàng chỉ dùng để dự báo, không được tính vào doanh số thực tế.',
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: palette.muted)),
          ),
          Text(
            value,
            style: TextStyle(
              color: palette.ink,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
