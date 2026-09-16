import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/electricity_bill_provider.dart';
import '../providers/payback_period_provider.dart';
import '../providers/processing_profit_provider.dart';
import '../providers/self_business_provider.dart';

class PaybackAnalysisMenuScreen extends StatelessWidget {
  const PaybackAnalysisMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final electricity = context.watch<ElectricityBillProvider>();
    final processing = context.watch<ProcessingProfitProvider>();
    final payback = context.watch<PaybackPeriodProvider>();
    final business = context.watch<SelfBusinessProvider>();
    final currency = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    final hasElectricity = electricity.totalBill != null;
    final hasProcessing = processing.totalProfit != null;
    final hasPayback = payback.machinePaybackDays != null;
    final hasBusiness = business.netProfit != null;
    final canChart = hasProcessing && hasPayback && hasBusiness;
    final completedCount = [
      hasElectricity,
      hasProcessing,
      hasPayback,
      hasBusiness,
    ].where((value) => value).length;

    final steps = <_PaybackStep>[
      _PaybackStep(
        number: 1,
        title: 'Tra cứu công suất tiêu thụ',
        description: 'Xem công suất theo model trước khi lập phương án.',
        icon: Icons.bolt_rounded,
        status: 'Tra cứu độc lập',
        onTap: () => context.push('/power_consumption'),
      ),
      _PaybackStep(
        number: 2,
        title: 'Tính tiền điện mỗi ngày',
        description: hasElectricity
            ? '${electricity.selectedModel} · ${electricity.totalHours} giờ · ${currency.format(electricity.totalBill)}'
            : 'Chọn model và nhập thời gian vận hành theo từng khung giá.',
        icon: Icons.payments_rounded,
        completed: hasElectricity,
        onTap: () => context.push('/electricity_bill'),
      ),
      _PaybackStep(
        number: 3,
        title: 'Tính lợi nhuận gia công',
        description: hasProcessing
            ? 'Lợi nhuận dự kiến: ${currency.format(processing.totalProfit)} / ngày'
            : 'Cần kết quả tiền điện ở bước 2.',
        icon: Icons.trending_up_rounded,
        completed: hasProcessing,
        onTap: () => _openRequiredStep(
          context,
          ready: hasElectricity,
          target: '/processing_profit',
          prerequisite: '/electricity_bill',
          message: 'Hãy hoàn thành bước 2: Tính tiền điện mỗi ngày.',
        ),
      ),
      _PaybackStep(
        number: 4,
        title: 'Tính thời gian hoàn vốn',
        description: hasPayback
            ? 'Đã có kết quả hoàn vốn theo ngày.'
            : 'Cần kết quả lợi nhuận gia công ở bước 3.',
        icon: Icons.calculate_rounded,
        completed: hasPayback,
        onTap: () {
          if (!hasElectricity) {
            _redirect(
              context,
              '/electricity_bill',
              'Hãy hoàn thành bước 2 trước.',
            );
          } else {
            _openRequiredStep(
              context,
              ready: hasProcessing,
              target: '/payback_period',
              prerequisite: '/processing_profit',
              message: 'Hãy hoàn thành bước 3: Tính lợi nhuận gia công.',
            );
          }
        },
      ),
      _PaybackStep(
        number: 5,
        title: 'Tính lợi nhuận tự kinh doanh',
        description: hasBusiness
            ? 'Lợi nhuận ròng: ${currency.format(business.netProfit)} / ngày'
            : 'Sử dụng tiền điện ở bước 2 và giá nguyên liệu thực tế.',
        icon: Icons.storefront_rounded,
        completed: hasBusiness,
        onTap: () => _openRequiredStep(
          context,
          ready: hasElectricity,
          target: '/self_business',
          prerequisite: '/electricity_bill',
          message: 'Hãy hoàn thành bước 2: Tính tiền điện mỗi ngày.',
        ),
      ),
      _PaybackStep(
        number: 6,
        title: 'Xem biểu đồ hoàn vốn',
        description: canChart
            ? 'Dữ liệu đã sẵn sàng để đối chiếu hai phương án.'
            : 'Hoàn thành các bước 3, 4 và 5 để mở biểu đồ.',
        icon: Icons.show_chart_rounded,
        status: canChart ? 'Sẵn sàng' : 'Còn thiếu dữ liệu',
        completed: canChart,
        onTap: () {
          if (!hasElectricity) {
            _redirect(
              context,
              '/electricity_bill',
              'Hãy hoàn thành bước 2 trước.',
            );
          } else if (!hasProcessing) {
            _redirect(
              context,
              '/processing_profit',
              'Hãy hoàn thành bước 3 trước.',
            );
          } else if (!hasPayback) {
            _redirect(
              context,
              '/payback_period',
              'Hãy hoàn thành bước 4 trước.',
            );
          } else if (!hasBusiness) {
            _redirect(
              context,
              '/self_business',
              'Hãy hoàn thành bước 5 trước.',
            );
          } else {
            context.push('/payback_chart');
          }
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phân tích hoàn vốn'),
        actions: [
          if (completedCount > 0)
            IconButton(
              tooltip: 'Bắt đầu lại',
              onPressed: () => _confirmReset(
                context,
                electricity,
                processing,
                payback,
                business,
              ),
              icon: const Icon(Icons.restart_alt_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProgressHeader(completed: completedCount, total: 4),
                  const SizedBox(height: 14),
                  ...steps.map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PaybackStepCard(step: step),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _openRequiredStep(
    BuildContext context, {
    required bool ready,
    required String target,
    required String prerequisite,
    required String message,
  }) {
    ready ? context.push(target) : _redirect(context, prerequisite, message);
  }

  static void _redirect(BuildContext context, String route, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    context.push(route);
  }

  static Future<void> _confirmReset(
    BuildContext context,
    ElectricityBillProvider electricity,
    ProcessingProfitProvider processing,
    PaybackPeriodProvider payback,
    SelfBusinessProvider business,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bắt đầu phương án mới?'),
        content: const Text(
          'Các kết quả đang tính sẽ được xóa. Cài đặt đơn giá điện vẫn được giữ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Bắt đầu lại'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    electricity.resetSession();
    processing.resetSession();
    payback.resetSession();
    business.resetSession();
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiến độ phương án: $completed/$total kết quả',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bấm vào bất kỳ bước nào. Nếu còn thiếu dữ liệu, ứng dụng sẽ đưa bạn tới đúng bước cần hoàn thành.',
              style: TextStyle(color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 14),
            Semantics(
              label: 'Đã hoàn thành $completed trên $total kết quả',
              child: LinearProgressIndicator(
                value: completed / total,
                minHeight: 8,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaybackStep {
  const _PaybackStep({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.completed = false,
    this.status,
  });

  final int number;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool completed;
  final String? status;
}

class _PaybackStepCard extends StatelessWidget {
  const _PaybackStepCard({required this.step});

  final _PaybackStep step;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Bước ${step.number}: ${step.title}',
      hint: step.completed ? 'Đã hoàn thành' : step.status,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: step.onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: step.completed
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    step.completed ? Icons.check_rounded : step.icon,
                    color: step.completed
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bước ${step.number}',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        step.description,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      if (step.status != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          step.status!,
                          style: TextStyle(
                            color: step.completed
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
