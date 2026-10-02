import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/sales_opportunity.dart';
import '../providers/sales_goal_provider.dart';
import '../utils/sales_goal_action.dart';
import '../utils/sales_goal_format.dart';

class SalesPipelineScreen extends StatelessWidget {
  const SalesPipelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SalesGoalProvider>();
    final opportunities = provider.opportunities;
    return Scaffold(
      appBar: AppBar(title: const Text('Cơ hội bán hàng')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/sales-goal/pipeline/form'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm cơ hội'),
      ),
      body: opportunities.isEmpty
          ? const Center(child: Text('Chưa có cơ hội bán hàng.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: opportunities.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = opportunities[index];
                return _OpportunityCard(
                  opportunity: item,
                  onEdit: () =>
                      context.push('/sales-goal/pipeline/form', extra: item),
                  onDelete: () => _delete(context, item),
                  onConvert: () => _convert(context, item),
                );
              },
            ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    SalesOpportunity opportunity,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa cơ hội?'),
        content: Text('Xóa "${opportunity.customerOrProject}"?'),
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
      () => provider.deleteOpportunity(opportunity.id!),
      errorMessage: 'Không thể xóa cơ hội. Vui lòng thử lại.',
    );
  }

  Future<void> _convert(
    BuildContext context,
    SalesOpportunity opportunity,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ghi nhận thành doanh số?'),
        content: Text(
          'Tạo một khoản doanh số ${formatSalesMoney(opportunity.estimatedValue)} và chuyển cơ hội sang “Đã thắng”. Thao tác này không diễn ra tự động.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ghi nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final provider = context.read<SalesGoalProvider>();
    await runSalesGoalAction(
      context,
      () => provider.convertOpportunityToEntry(opportunity),
      errorMessage: 'Không thể ghi nhận doanh số. Vui lòng thử lại.',
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.opportunity,
    required this.onEdit,
    required this.onDelete,
    required this.onConvert,
  });

  final SalesOpportunity opportunity;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onConvert;

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
                    opportunity.customerOrProject,
                    style: TextStyle(
                      color: palette.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                _StatusChip(status: opportunity.status),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                    if (value == 'convert') onConvert();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Chỉnh sửa'),
                    ),
                    if (opportunity.status.isOpen)
                      const PopupMenuItem(
                        value: 'convert',
                        child: Text('Ghi nhận thành doanh số'),
                      ),
                    const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ),
              ],
            ),
            if (opportunity.productOrMachine.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(opportunity.productOrMachine),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                Text(
                  formatSalesMoney(opportunity.estimatedValue),
                  style: TextStyle(
                    color: palette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text('Xác suất ${opportunity.probability}%'),
                Text('Chốt ${formatSalesDate(opportunity.expectedCloseDate)}'),
              ],
            ),
            if (opportunity.status.isOpen) ...[
              const SizedBox(height: 8),
              Text(
                'Dự báo có trọng số: ${formatSalesMoney(opportunity.estimatedValue * opportunity.probability / 100)}',
                style: TextStyle(color: palette.muted, fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final SalesOpportunityStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SalesOpportunityStatus.tracking => Colors.blue,
      SalesOpportunityStatus.negotiating => Colors.orange,
      SalesOpportunityStatus.won => Colors.green,
      SalesOpportunityStatus.lost => Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
