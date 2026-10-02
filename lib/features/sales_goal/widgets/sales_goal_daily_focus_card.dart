import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/sales_focus_task.dart';
import '../providers/sales_goal_provider.dart';
import '../utils/sales_goal_action.dart';
import '../utils/sales_goal_format.dart';

class SalesGoalDailyFocusCard extends StatelessWidget {
  const SalesGoalDailyFocusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final provider = context.watch<SalesGoalProvider>();
    final summary = provider.summary;
    final now = DateTime.now();
    final nearClosing = provider.opportunities.where((item) {
      final days = item.expectedCloseDate
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
      return item.status.isOpen && days >= 0 && days <= 7;
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Tập trung hôm nay',
                    style: TextStyle(
                      color: palette.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('sales_focus_add'),
                  tooltip: 'Thêm việc cần làm',
                  onPressed: () => _addTask(context),
                  icon: Icon(Icons.add_circle_rounded, color: palette.cyan),
                ),
              ],
            ),
            if (summary != null)
              _Suggestion(
                icon: Icons.trending_up_rounded,
                text:
                    'Cần đạt trung bình ${formatSalesMoney(summary.requiredPerDay)} mỗi ngày.',
              ),
            _Suggestion(
              icon: Icons.handshake_outlined,
              text:
                  '${provider.opportunities.where((item) => item.status.isOpen).length} cơ hội cần theo dõi.',
            ),
            if (nearClosing.isNotEmpty)
              _Suggestion(
                icon: Icons.event_available_outlined,
                text: '${nearClosing.length} cơ hội dự kiến chốt trong 7 ngày.',
              ),
            if (provider.focusTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Chưa có công việc cá nhân cho hôm nay.',
                  style: TextStyle(color: palette.muted),
                ),
              )
            else
              ...provider.focusTasks.map(
                (task) => Dismissible(
                  key: ValueKey('sales_focus_${task.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    color: Colors.red.shade600,
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                    ),
                  ),
                  confirmDismiss: (_) => runSalesGoalAction(
                    context,
                    () => provider.deleteFocusTask(task.id!),
                    errorMessage: 'Không thể xóa công việc.',
                  ),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: task.isCompleted,
                    onChanged: (_) => runSalesGoalAction(
                      context,
                      () => provider.toggleFocusTask(task),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: PopupMenuButton<String>(
                      tooltip: 'Tùy chọn',
                      onSelected: (value) => value == 'edit'
                          ? _editTask(context, task)
                          : runSalesGoalAction(
                              context,
                              () => provider.deleteFocusTask(task.id!),
                              errorMessage: 'Không thể xóa công việc.',
                            ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                        PopupMenuItem(value: 'delete', child: Text('Xóa')),
                      ],
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted ? palette.muted : palette.ink,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTask(BuildContext context, SalesFocusTask task) async {
    final value = await _promptTitle(
      context,
      title: 'Chỉnh sửa công việc',
      confirmLabel: 'Lưu',
      initialText: task.title,
    );
    if (!context.mounted || value == null || value.trim().isEmpty) return;
    final provider = context.read<SalesGoalProvider>();
    await runSalesGoalAction(
      context,
      () => provider.renameFocusTask(task, value),
    );
  }

  Future<void> _addTask(BuildContext context) async {
    final value = await _promptTitle(
      context,
      title: 'Thêm việc cần làm',
      confirmLabel: 'Thêm',
    );
    if (!context.mounted || value == null || value.trim().isEmpty) return;
    final provider = context.read<SalesGoalProvider>();
    await runSalesGoalAction(context, () => provider.addFocusTask(value));
  }

  Future<String?> _promptTitle(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String initialText = '',
  }) async {
    final controller = TextEditingController(text: initialText);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(hintText: 'Nội dung công việc'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: palette.cyan),
          const SizedBox(width: 9),
          Expanded(
            child: Text(text, style: TextStyle(color: palette.ink)),
          ),
        ],
      ),
    );
  }
}
