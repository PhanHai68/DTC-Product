import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/sales_goal_summary.dart';
import '../providers/sales_goal_provider.dart';
import '../utils/sales_goal_format.dart';
import '../widgets/sales_goal_chart.dart';
import '../widgets/sales_goal_daily_focus_card.dart';
import '../widgets/sales_goal_forecast_card.dart';
import '../widgets/sales_goal_progress_card.dart';

class SalesGoalDashboardScreen extends StatefulWidget {
  const SalesGoalDashboardScreen({super.key});

  @override
  State<SalesGoalDashboardScreen> createState() =>
      _SalesGoalDashboardScreenState();
}

class _SalesGoalDashboardScreenState extends State<SalesGoalDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesGoalProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final provider = context.watch<SalesGoalProvider>();
    final summary = provider.summary;
    _showMilestoneIfNeeded(provider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mục tiêu doanh số'),
        actions: [
          IconButton(
            tooltip: 'Lịch sử',
            onPressed: () => context.push('/sales-goal/history'),
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'Thiết lập mục tiêu',
            onPressed: () => context.push('/sales-goal/targets'),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: provider.isLoading && summary == null
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && summary == null
          ? _ErrorState(message: provider.error!, onRetry: provider.load)
          : RefreshIndicator(
              onRefresh: provider.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (summary != null) SalesGoalProgressCard(summary: summary),
                  if (summary != null && summary.monthlyTarget == 0) ...[
                    const SizedBox(height: 10),
                    Card(
                      color: palette.cyan.withValues(alpha: 0.08),
                      child: ListTile(
                        leading: Icon(Icons.flag_outlined, color: palette.cyan),
                        title: const Text('Chưa thiết lập mục tiêu tháng'),
                        subtitle: const Text(
                          'Thiết lập mục tiêu để theo dõi tỷ lệ hoàn thành.',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/sales-goal/targets'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _QuickActions(
                    onEntries: () => context.push('/sales-goal/entries'),
                    onPipeline: () => context.push('/sales-goal/pipeline'),
                    onAddSale: () => context.push('/sales-goal/entries/form'),
                    onAddOpportunity: () =>
                        context.push('/sales-goal/pipeline/form'),
                  ),
                  const SizedBox(height: 12),
                  if (summary != null) ...[
                    _QuarterCard(summary: summary),
                    const SizedBox(height: 12),
                    SalesGoalForecastCard(summary: summary),
                    const SizedBox(height: 12),
                  ],
                  const SalesGoalDailyFocusCard(),
                  const SizedBox(height: 12),
                  SalesDailyChart(
                    entries: provider.entries,
                    month: DateTime.now(),
                  ),
                  const SizedBox(height: 12),
                  SalesGoalChart(history: provider.history),
                ],
              ),
            ),
    );
  }

  void _showMilestoneIfNeeded(SalesGoalProvider provider) {
    if (provider.newMilestones.isEmpty) return;
    final milestone = provider.newMilestones.last;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.clearMilestoneNotice();
      final message = milestone == 101
          ? 'Xuất sắc! Bạn đã vượt mục tiêu tháng.'
          : 'Chúc mừng! Bạn đã đạt $milestone% mục tiêu tháng.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
    });
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onEntries,
    required this.onPipeline,
    required this.onAddSale,
    required this.onAddOpportunity,
  });

  final VoidCallback onEntries;
  final VoidCallback onPipeline;
  final VoidCallback onAddSale;
  final VoidCallback onAddOpportunity;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: onAddSale,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ghi doanh số'),
          ),
          OutlinedButton.icon(
            onPressed: onAddOpportunity,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Thêm cơ hội'),
          ),
          TextButton.icon(
            onPressed: onEntries,
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Doanh số'),
          ),
          TextButton.icon(
            onPressed: onPipeline,
            icon: const Icon(Icons.filter_alt_outlined),
            label: const Text('Cơ hội'),
          ),
        ],
      ),
    ),
  );
}

class _QuarterCard extends StatelessWidget {
  const _QuarterCard({required this.summary});
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
            Text(
              'Tiến độ quý hiện tại',
              style: TextStyle(
                color: palette.navy,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: summary.quarterlyProgress,
              minHeight: 9,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: palette.border,
              color: palette.cyan,
            ),
            const SizedBox(height: 10),
            Text(
              '${formatSalesMoney(summary.quarterlyActual)} / ${formatSalesMoney(summary.quarterlyTarget)}',
              style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 52),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
