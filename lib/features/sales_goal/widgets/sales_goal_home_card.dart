import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../providers/settings_provider.dart';
import '../../../theme/dtc_palette.dart';
import '../providers/sales_goal_provider.dart';
import '../utils/sales_goal_format.dart';

class SalesGoalHomeCard extends StatefulWidget {
  const SalesGoalHomeCard({super.key});

  @override
  State<SalesGoalHomeCard> createState() => _SalesGoalHomeCardState();
}

class _SalesGoalHomeCardState extends State<SalesGoalHomeCard> {
  bool _requestedLoad = false;

  @override
  Widget build(BuildContext context) {
    final enabled = context.watch<SettingsProvider>().homeSalesGoalEnabled;
    if (!enabled) return const SizedBox.shrink();
    if (!_requestedLoad) {
      _requestedLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<SalesGoalProvider>().load();
      });
    }
    final provider = context.watch<SalesGoalProvider>();
    final summary = provider.summary;
    final palette = DtcPalette.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Card(
            child: InkWell(
              key: const Key('sales_goal_home_card'),
              borderRadius: BorderRadius.circular(18),
              onTap: () => context.push('/sales-goal'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: provider.isLoading && summary == null
                    ? const SizedBox(
                        height: 42,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: palette.cyan.withValues(
                              alpha: 0.12,
                            ),
                            child: Icon(
                              Icons.flag_circle_rounded,
                              color: palette.cyan,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MỤC TIÊU DOANH SỐ',
                                  style: TextStyle(
                                    color: palette.navy,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  summary == null
                                      ? 'Mở để thiết lập mục tiêu tháng'
                                      : '${formatSalesMoney(summary.monthlyActual)} / ${formatSalesMoney(summary.monthlyTarget)}',
                                  style: TextStyle(color: palette.muted),
                                ),
                                if (summary != null) ...[
                                  const SizedBox(height: 7),
                                  LinearProgressIndicator(
                                    value: summary.monthlyProgress,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(4),
                                    backgroundColor: palette.border,
                                    color: palette.cyan,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            summary == null
                                ? ''
                                : '${(summary.rawMonthlyProgress * 100).round()}%',
                            style: TextStyle(
                              color: palette.cyan,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
