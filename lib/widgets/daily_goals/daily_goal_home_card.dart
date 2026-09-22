import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/daily_goal.dart';
import '../../providers/daily_goals_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/dtc_palette.dart';
import 'goal_toggle_confirm.dart';

const _maxVisibleGoals = 3;

/// Card "Mục tiêu hôm nay" hiển thị trên HomeScreen — tự ẩn khi người dùng
/// chưa bật trong Cá nhân hóa trang chủ. Chỉ đọc/thao tác dữ liệu của HÔM
/// NAY, không tải toàn bộ lịch sử (đúng yêu cầu hiệu năng).
class DailyGoalHomeCard extends StatefulWidget {
  const DailyGoalHomeCard({super.key});

  @override
  State<DailyGoalHomeCard> createState() => _DailyGoalHomeCardState();
}

class _DailyGoalHomeCardState extends State<DailyGoalHomeCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<DailyGoalsProvider>().loadToday(),
    );
  }

  Future<void> _handleToggle(
    DailyGoalsProvider goalsProvider,
    DailyGoal goal,
  ) async {
    if (await confirmToggleGoal(context, goal)) {
      goalsProvider.toggleCompleted(goal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (!settings.homeDailyGoalsEnabled) return const SizedBox.shrink();

    final goalsProvider = context.watch<DailyGoalsProvider>();
    final palette = DtcPalette.of(context);
    final goals = goalsProvider.goals;
    final progress = goalsProvider.progress;
    final visible = goals.take(_maxVisibleGoals).toList();
    final remaining = goals.length - visible.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: palette.border),
            ),
            child: Padding(
              key: const Key('daily_goal_home_card'),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    title: settings.homeDailyGoalsTitle,
                    progress: progress,
                    fontSize: settings.homeDailyGoalsFontSize,
                    color: settings.homeDailyGoalsColor,
                    italic: settings.homeDailyGoalsItalic,
                    onTap: () => context.push('/daily_goals'),
                    onAdd: () => context.push('/daily_goals/form'),
                  ),
                  const SizedBox(height: 12),
                  if (goalsProvider.isLoading && goals.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (goals.isEmpty)
                    const _EmptyState()
                  else ...[
                    ...visible.map(
                      (goal) => _GoalRow(
                        goal: goal,
                        onToggle: () => _handleToggle(goalsProvider, goal),
                      ),
                    ),
                    if (remaining > 0)
                      InkWell(
                        onTap: () => context.push('/daily_goals'),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Text(
                            'Xem thêm $remaining mục tiêu',
                            style: TextStyle(
                              color: palette.cyan,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    _ProgressBar(progress: progress),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.progress,
    required this.fontSize,
    required this.color,
    required this.italic,
    required this.onTap,
    required this.onAdd,
  });

  final String title;
  final GoalProgress progress;
  final double fontSize;
  final Color? color;
  final bool italic;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color ?? palette.navy,
                    fontWeight: FontWeight.w800,
                    fontSize: fontSize,
                    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  today,
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (progress.total > 0) ...[
          Text(
            '${progress.completed}/${progress.total}',
            style: TextStyle(
              color: palette.navy,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 4),
        ],
        IconButton(
          key: const Key('daily_goal_add_button'),
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle_rounded),
          color: palette.cyan,
          tooltip: 'Thêm mục tiêu',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal, required this.onToggle});

  final DailyGoal goal;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              goal.isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: goal.isCompleted ? palette.cyan : palette.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                goal.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  color: goal.isCompleted ? palette.muted : palette.ink,
                  decoration: goal.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final GoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Row(
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
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Text(
      'Hôm nay chưa có mục tiêu nào. Bấm "+" để thêm.',
      style: TextStyle(color: palette.muted, fontSize: 13.5),
    );
  }
}
