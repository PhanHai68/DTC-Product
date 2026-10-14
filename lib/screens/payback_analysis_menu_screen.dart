import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../providers/electricity_bill_provider.dart';
import '../providers/payback_period_provider.dart';
import '../providers/processing_profit_provider.dart';
import '../providers/self_business_provider.dart';

class PaybackAnalysisMenuScreen extends StatelessWidget {
  const PaybackAnalysisMenuScreen({super.key, this.line = ColorSorterLine.rice});

  /// Dòng máy đang phân tích (gạo, thóc hoặc trà) — quyết định danh sách model.
  final ColorSorterLine line;

  /// Máy trà mới tính được tiền điện (bước 2) và lợi nhuận gia công (bước 3);
  /// các bước sau chưa có dữ liệu.
  static const _teaComingSoonFromStep = 4;

  static const _lineNames = {
    ColorSorterLine.paddy: 'Máy tách màu Thóc',
    ColorSorterLine.tea: 'Máy tách màu Trà',
  };

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
    final lineQuery = line == ColorSorterLine.rice ? '' : '?line=${line.name}';
    final isTea = line == ColorSorterLine.tea;

    // Kết quả đang có thuộc model của dòng máy khác (VD đã tính máy gạo rồi
    // mở từ menu máy thóc): không dùng tiếp, phải bắt đầu phương án mới.
    final selectedModel = electricity.selectedModel;
    final otherLinePlan =
        selectedModel != null &&
        !powerConsumptionModels(line).contains(selectedModel);

    final hasElectricity = !otherLinePlan && electricity.totalBill != null;
    final hasProcessing = !otherLinePlan && processing.totalProfit != null;
    final hasPayback = !otherLinePlan && payback.machinePaybackDays != null;
    final hasBusiness = !otherLinePlan && business.netProfit != null;
    final canChart = hasProcessing && hasPayback && hasBusiness;
    final results = [
      hasElectricity,
      hasProcessing,
      if (!isTea) ...[hasPayback, hasBusiness],
    ];
    final completedCount = results.where((value) => value).length;

    final steps = <_PaybackStep>[
      _PaybackStep(
        number: 1,
        title: 'Tra cứu công suất tiêu thụ',
        description: 'Xem công suất theo model trước khi lập phương án.',
        icon: Icons.bolt_rounded,
        status: 'Tra cứu độc lập',
        onTap: () => context.push('/power_consumption$lineQuery'),
      ),
      _PaybackStep(
        number: 2,
        title: 'Tính tiền điện mỗi ngày',
        description: hasElectricity
            ? '${electricity.selectedModel} · ${electricity.totalHours} giờ · ${currency.format(electricity.totalBill)}'
            : 'Chọn model và nhập thời gian vận hành theo từng khung giá.',
        icon: Icons.payments_rounded,
        completed: hasElectricity,
        onTap: () => context.push('/electricity_bill$lineQuery'),
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
          prerequisite: '/electricity_bill$lineQuery',
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
              '/electricity_bill$lineQuery',
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
          prerequisite: '/electricity_bill$lineQuery',
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
              '/electricity_bill$lineQuery',
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

    Future<void> startNewPlan() async {
      final reset = await _confirmReset(
        context,
        electricity,
        processing,
        payback,
        business,
      );
      if (reset && context.mounted) {
        context.push('/electricity_bill$lineQuery');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: _lineNames[line] == null
            ? const Text('Phân tích hoàn vốn')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Phân tích hoàn vốn'),
                  Text(
                    _lineNames[line]!,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
        actions: [
          if (completedCount > 0 || otherLinePlan)
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
                  _ProgressHeader(
                    completed: completedCount,
                    total: results.length,
                  ),
                  const SizedBox(height: 14),
                  if (otherLinePlan) ...[
                    _OtherLinePlanCard(
                      model: selectedModel,
                      onStartNew: startNewPlan,
                    ),
                    const SizedBox(height: 14),
                  ],
                  ...steps.map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: isTea && step.number >= _teaComingSoonFromStep
                          ? _PaybackStepCard(
                              step: step,
                              comingSoon: true,
                              onTap: () => ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Bước này sắp có cho máy tách màu Trà.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                ),
                            )
                          : _PaybackStepCard(
                              step: step,
                              // Bước 1 chỉ tra cứu; các bước khác cần phương
                              // án mới.
                              onTap: otherLinePlan && step.number > 1
                                  ? startNewPlan
                                  : null,
                            ),
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

  /// Hỏi rồi xóa kết quả phương án hiện tại; trả về `true` nếu đã xóa.
  static Future<bool> _confirmReset(
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
    if (confirmed != true) return false;
    electricity.resetSession();
    processing.resetSession();
    payback.resetSession();
    business.resetSession();
    return true;
  }
}

class _OtherLinePlanCard extends StatelessWidget {
  const _OtherLinePlanCard({required this.model, required this.onStartNew});

  final String model;
  final VoidCallback onStartNew;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Đang có phương án tính cho model $model của dòng máy khác.',
              style: TextStyle(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bắt đầu phương án mới để chọn model của dòng máy này.',
              style: TextStyle(color: colorScheme.onTertiaryContainer),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onStartNew,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Bắt đầu phương án mới'),
              ),
            ),
          ],
        ),
      ),
    );
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
  const _PaybackStepCard({
    required this.step,
    this.onTap,
    this.comingSoon = false,
  });

  final _PaybackStep step;

  /// Thay cho [_PaybackStep.onTap] khi cần (VD phải bắt đầu phương án mới).
  final VoidCallback? onTap;

  /// Bước chưa có cho dòng máy này: hiện mờ, nhãn "Sắp có".
  final bool comingSoon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shown = comingSoon
        ? _PaybackStep(
            number: step.number,
            title: step.title,
            description: 'Chưa có dữ liệu cho dòng máy này.',
            icon: step.icon,
            onTap: step.onTap,
            status: 'Sắp có',
          )
        : step;
    return Opacity(
      opacity: comingSoon ? 0.6 : 1,
      child: _buildCard(context, colorScheme, shown),
    );
  }

  Widget _buildCard(
    BuildContext context,
    ColorScheme colorScheme,
    _PaybackStep step,
  ) {
    return Semantics(
      button: true,
      label: 'Bước ${step.number}: ${step.title}',
      hint: step.completed ? 'Đã hoàn thành' : step.status,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap ?? step.onTap,
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
