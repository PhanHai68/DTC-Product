import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/sales_goal_summary.dart';
import '../models/sales_target.dart';
import '../providers/sales_goal_provider.dart';
import '../utils/sales_goal_action.dart';
import '../utils/sales_goal_format.dart';
import '../widgets/sales_goal_chart.dart';

class SalesGoalHistoryScreen extends StatelessWidget {
  const SalesGoalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesGoalProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử doanh số')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SalesGoalChart(history: provider.history),
          const SizedBox(height: 16),
          const _Title('Theo tháng'),
          const SizedBox(height: 8),
          ...provider.history.reversed.map(_MonthRow.new),
          const SizedBox(height: 20),
          const _Title('Theo quý'),
          const SizedBox(height: 8),
          ...provider.quarterHistory.reversed.map(_QuarterRow.new),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Text(
      text,
      style: TextStyle(
        color: palette.navy,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow(this.item);
  final SalesMonthHistory item;

  @override
  Widget build(BuildContext context) => _HistoryCard(
    period: 'Tháng ${item.month}/${item.year}',
    targetPeriod: SalesTargetPeriod.month,
    year: item.year,
    periodNumber: item.month,
    target: item.target,
    actual: item.actual,
    progress: item.progress,
  );
}

class _QuarterRow extends StatelessWidget {
  const _QuarterRow(this.item);
  final SalesQuarterHistory item;

  @override
  Widget build(BuildContext context) => _HistoryCard(
    period: 'Quý ${item.quarter}/${item.year}',
    targetPeriod: SalesTargetPeriod.quarter,
    year: item.year,
    periodNumber: item.quarter,
    target: item.target,
    actual: item.actual,
    progress: item.progress,
  );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.period,
    required this.targetPeriod,
    required this.year,
    required this.periodNumber,
    required this.target,
    required this.actual,
    required this.progress,
  });
  final String period;
  final SalesTargetPeriod targetPeriod;
  final int year;
  final int periodNumber;
  final int target;
  final int actual;
  final double progress;

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: target > 0 ? '$target' : '');
    final formKey = GlobalKey<FormState>();
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Mục tiêu $period'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Số tiền mục tiêu',
              suffixText: 'VND',
            ),
            validator: (value) => parseSalesMoney(value ?? '') == null
                ? 'Vui lòng nhập số tiền'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, parseSalesMoney(controller.text));
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || !context.mounted) return;
    final provider = context.read<SalesGoalProvider>();
    await runSalesGoalAction(
      context,
      () => provider.saveTarget(
        period: targetPeriod,
        year: year,
        periodNumber: periodNumber,
        amount: amount,
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa mục tiêu?'),
        content: Text(
          'Xóa mục tiêu ${formatSalesMoney(target)} của $period? Doanh số đã ghi nhận vẫn được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final provider = context.read<SalesGoalProvider>();
    await runSalesGoalAction(
      context,
      () => provider.deleteTarget(
        period: targetPeriod,
        year: year,
        periodNumber: periodNumber,
      ),
      errorMessage: 'Không thể xóa mục tiêu. Vui lòng thử lại.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    period,
                    style: TextStyle(
                      color: palette.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  target <= 0
                      ? 'Chưa đặt mục tiêu'
                      : '${(progress * 100).round()}%',
                  style: TextStyle(
                    color: palette.cyan,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Tùy chọn',
                  onSelected: (value) =>
                      value == 'edit' ? _edit(context) : _delete(context),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(
                        target > 0 ? 'Chỉnh sửa mục tiêu' : 'Đặt mục tiêu',
                      ),
                    ),
                    if (target > 0)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Xóa mục tiêu'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 7,
              borderRadius: BorderRadius.circular(5),
              backgroundColor: palette.border,
              color: palette.cyan,
            ),
            const SizedBox(height: 8),
            Text(
              '${formatSalesMoney(actual)} / ${formatSalesMoney(target)}',
              style: TextStyle(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}
