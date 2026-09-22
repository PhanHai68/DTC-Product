import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/daily_goal.dart';
import '../../providers/daily_goals_provider.dart';
import '../../theme/dtc_palette.dart';
import '../../widgets/daily_goals/goal_toggle_confirm.dart';

/// Màn hình chi tiết "Mục tiêu công việc" — mặc định quản lý mục tiêu của
/// hôm nay, hoặc của 1 ngày cụ thể trong quá khứ khi mở từ màn Lịch sử/Lịch
/// theo tháng (Phase 2) qua [date]. Khi rời màn xem ngày quá khứ, tự khôi
/// phục [DailyGoalsProvider] về "hôm nay" để HomeScreen luôn hiển thị đúng.
class DailyGoalsScreen extends StatefulWidget {
  const DailyGoalsScreen({super.key, this.date});

  final DateTime? date;

  @override
  State<DailyGoalsScreen> createState() => _DailyGoalsScreenState();
}

class _DailyGoalsScreenState extends State<DailyGoalsScreen> {
  late final DailyGoalsProvider _provider;

  bool get _isHistoryView =>
      widget.date != null && !DailyGoal.isSameDate(widget.date!, DateTime.now());

  @override
  void initState() {
    super.initState();
    _provider = context.read<DailyGoalsProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.date != null) {
        _provider.loadDate(widget.date!);
      } else if (_provider.goals.isEmpty && !_provider.isLoading) {
        _provider.loadToday();
      }
    });
  }

  @override
  void dispose() {
    if (_isHistoryView) {
      // Không await được trong dispose — chỉ cần bắn yêu cầu tải lại "hôm
      // nay" để HomeCard/lần mở tiếp theo không còn kẹt ở ngày quá khứ.
      _provider.loadToday();
    }
    super.dispose();
  }

  Future<void> _confirmDelete(DailyGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa mục tiêu?'),
        content: const Text('Mục tiêu này sẽ bị xóa khỏi lịch sử.'),
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
    if (confirmed != true || !mounted) return;
    await context.read<DailyGoalsProvider>().deleteGoal(goal.id!);
  }

  Future<void> _handleToggle(DailyGoal goal) async {
    if (await confirmToggleGoal(context, goal)) {
      if (!mounted) return;
      await context.read<DailyGoalsProvider>().toggleCompleted(goal);
    }
  }

  String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DailyGoalsProvider>();
    final palette = DtcPalette.of(context);
    final goals = provider.goals;
    final progress = provider.progress;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isHistoryView
              ? _formatDate(provider.selectedDate)
              : 'Mục tiêu công việc',
        ),
        actions: [
          if (widget.date == null)
            IconButton(
              key: const Key('daily_goals_calendar_button'),
              tooltip: 'Lịch sử & thống kê',
              onPressed: () => context.push('/daily_goals/calendar'),
              icon: const Icon(Icons.calendar_month_outlined),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadDate(provider.selectedDate),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _SummaryCard(selectedDate: provider.selectedDate, progress: progress),
            const SizedBox(height: 16),
            if (provider.isLoading && goals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (goals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 48,
                      color: palette.muted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có mục tiêu nào.',
                      style: TextStyle(color: palette.muted, fontSize: 14.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thêm mục tiêu đầu tiên để bắt đầu ngày làm việc.',
                      style: TextStyle(color: palette.muted, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...goals.map(
                (goal) => _GoalTile(
                  goal: goal,
                  onToggle: () => _handleToggle(goal),
                  onEdit: () => context.push(
                    '/daily_goals/form',
                    extra: {'goal': goal},
                  ),
                  onDelete: () => _confirmDelete(goal),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/daily_goals/form'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm mục tiêu'),
      ),
    );
  }
}

const _weekdayNames = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.selectedDate, required this.progress});

  final DateTime selectedDate;
  final GoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    // Tự tính tên thứ bằng tiếng Việt thay vì DateFormat(locale: 'vi_VN') —
    // app chưa initializeDateFormatting cho locale này nên dùng sẽ ném lỗi.
    final weekday = _weekdayNames[selectedDate.weekday - 1];
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$weekday, ${dateFormat.format(selectedDate)}',
              style: TextStyle(
                color: palette.navy,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.ratio,
                      minHeight: 8,
                      backgroundColor: palette.border,
                      valueColor: AlwaysStoppedAnimation(palette.cyan),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${progress.percent}%',
                  style: TextStyle(
                    color: palette.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${progress.completed}/${progress.total} hoàn thành',
              style: TextStyle(color: palette.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final DailyGoal goal;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color _priorityColor(DtcPaletteData palette) => switch (goal.priority) {
    GoalPriority.low => palette.muted,
    GoalPriority.medium => palette.cyan,
    GoalPriority.high => const Color(0xFFEA580C),
    GoalPriority.critical => const Color(0xFFDC2626),
  };

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onEdit,
        leading: IconButton(
          onPressed: onToggle,
          icon: Icon(
            goal.isCompleted
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: goal.isCompleted ? palette.cyan : palette.muted,
          ),
        ),
        title: Text(
          goal.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: goal.isCompleted ? palette.muted : palette.ink,
            decoration: goal.isCompleted ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: _priorityColor(palette),
                shape: BoxShape.circle,
              ),
            ),
            Text(
              goal.priority.label,
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
            if (goal.description.trim().isNotEmpty) ...[
              Text(' · ', style: TextStyle(color: palette.muted)),
              Expanded(
                child: Text(
                  goal.description.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                onEdit();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Sửa'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Xóa', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
