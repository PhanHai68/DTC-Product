import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/daily_goal.dart';
import '../../providers/daily_goals_provider.dart';
import '../../theme/dtc_palette.dart';

const _weekdayHeaders = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// Màn hình "Lịch sử & Thống kê" (Phase 2) — xem tiến độ mục tiêu theo từng
/// ngày trong 1 tháng dưới dạng lưới lịch + biểu đồ cột số mục tiêu hoàn
/// thành mỗi ngày. Đọc dữ liệu trực tiếp qua [DailyGoalsProvider.loadMonth]
/// (không đụng tới trạng thái "hôm nay" đang dùng ở HomeScreen).
class DailyGoalsCalendarScreen extends StatefulWidget {
  const DailyGoalsCalendarScreen({super.key});

  @override
  State<DailyGoalsCalendarScreen> createState() =>
      _DailyGoalsCalendarScreenState();
}

class _DailyGoalsCalendarScreenState extends State<DailyGoalsCalendarScreen> {
  late DateTime _month;
  bool _isLoading = true;
  List<DailyGoal> _goals = const [];

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final goals = await context.read<DailyGoalsProvider>().loadMonth(_month);
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _isLoading = false;
    });
  }

  void _changeMonth(int offset) {
    setState(() => _month = DateTime(_month.year, _month.month + offset));
    _load();
  }

  Map<int, GoalProgress> get _progressByDay {
    final map = <int, List<DailyGoal>>{};
    for (final goal in _goals) {
      map.putIfAbsent(goal.goalDate.day, () => []).add(goal);
    }
    return map.map(
      (day, goals) => MapEntry(
        day,
        GoalProgress(
          completed: goals.where((g) => g.isCompleted).length,
          total: goals.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final progressByDay = _progressByDay;
    final monthProgress = GoalProgress(
      completed: _goals.where((g) => g.isCompleted).length,
      total: _goals.length,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử & Thống kê')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _MonthSelector(
                  month: _month,
                  canGoNext: !_isCurrentMonth,
                  onPrevious: () => _changeMonth(-1),
                  onNext: () => _changeMonth(1),
                ),
                const SizedBox(height: 16),
                _MonthSummaryCard(progress: monthProgress),
                const SizedBox(height: 16),
                if (_goals.isNotEmpty) ...[
                  _DailyBarChart(month: _month, progressByDay: progressByDay),
                  const SizedBox(height: 16),
                ],
                _CalendarGrid(
                  month: _month,
                  progressByDay: progressByDay,
                  onSelectDay: (date) => context.push(
                    '/daily_goals/day',
                    extra: {'date': date},
                  ),
                ),
                if (_goals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(
                      child: Text(
                        'Chưa có mục tiêu nào trong tháng này.',
                        style: TextStyle(color: palette.muted, fontSize: 13.5),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: const Key('daily_goals_calendar_prev'),
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        SizedBox(
          width: 130,
          child: Text(
            'Tháng ${month.month}/${month.year}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.navy,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        IconButton(
          key: const Key('daily_goals_calendar_next'),
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({required this.progress});

  final GoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${progress.completed}/${progress.total} hoàn thành',
                    style: TextStyle(
                      color: palette.navy,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.ratio,
                      minHeight: 8,
                      backgroundColor: palette.border,
                      valueColor: AlwaysStoppedAnimation(palette.cyan),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${progress.percent}%',
              style: TextStyle(
                color: palette.navy,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({required this.month, required this.progressByDay});

  final DateTime month;
  final Map<int, GoalProgress> progressByDay;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final maxCompleted = progressByDay.values
        .map((p) => p.total)
        .fold<int>(1, (a, b) => a > b ? a : b);
    // Trục ngày chỉ đủ chỗ cho vài nhãn — nhét đủ 1..daysInMonth sẽ đè chữ
    // lên nhau (fl_chart gọi getTitlesWidget cho từng cột chứ không tự giãn
    // theo interval như biểu đồ đường), nên chỉ hiện nhãn cách đều + ngày
    // đầu/cuối tháng, các cột còn lại vẫn có cột nhưng không hiện số.
    final labelStep = daysInMonth > 20 ? 5 : (daysInMonth > 10 ? 3 : 1);
    final labelDays = <int>{
      1,
      for (var d = labelStep; d < daysInMonth; d += labelStep) d,
      daysInMonth,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mục tiêu hoàn thành theo ngày',
              style: TextStyle(
                color: palette.muted,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  maxY: maxCompleted.toDouble(),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 20,
                        getTitlesWidget: (value, meta) {
                          final day = value.toInt();
                          if (!labelDays.contains(day)) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(daysInMonth, (index) {
                    final day = index + 1;
                    final progress = progressByDay[day];
                    return BarChartGroupData(
                      x: day,
                      barRods: [
                        BarChartRodData(
                          toY: (progress?.completed ?? 0).toDouble(),
                          color: progress == null
                              ? palette.border
                              : (progress.percent == 100
                                    ? palette.cyan
                                    : const Color(0xFFEA580C)),
                          width: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.progressByDay,
    required this.onSelectDay,
  });

  final DateTime month;
  final Map<int, GoalProgress> progressByDay;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    final today = DailyGoal.normalizeDate(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: _weekdayHeaders
                  .map(
                    (label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
                for (var day = 1; day <= daysInMonth; day++)
                  _DayCell(
                    date: DateTime(month.year, month.month, day),
                    progress: progressByDay[day],
                    isToday: DailyGoal.isSameDate(
                      DateTime(month.year, month.month, day),
                      today,
                    ),
                    onTap: () =>
                        onSelectDay(DateTime(month.year, month.month, day)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.progress,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final GoalProgress? progress;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final hasGoals = progress != null && progress!.total > 0;
    final dotColor = !hasGoals
        ? null
        : progress!.percent == 100
        ? palette.cyan
        : (progress!.completed > 0
              ? const Color(0xFFEA580C)
              : const Color(0xFFDC2626));

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        key: Key('daily_goals_calendar_day_${date.day}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isToday ? Border.all(color: palette.cyan, width: 1.4) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  color: hasGoals ? palette.ink : palette.muted,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: 6,
                height: 6,
                child: dotColor == null
                    ? null
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
