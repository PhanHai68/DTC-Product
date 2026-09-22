import 'package:dtc_product/models/daily_goal.dart';
import 'package:dtc_product/providers/daily_goals_provider.dart';
import 'package:dtc_product/repositories/daily_goal_repository.dart';
import 'package:dtc_product/screens/daily_goals/daily_goals_calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class _FakeDailyGoalRepository extends DailyGoalRepository {
  final List<DailyGoal> _store = [];
  int _nextId = 1;

  @override
  Future<List<DailyGoal>> getGoalsForDate(DateTime date) async {
    return _store
        .where((g) => DailyGoal.isSameDate(g.goalDate, date))
        .toList();
  }

  @override
  Future<List<DailyGoal>> getGoalsForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final s = DailyGoal.normalizeDate(start);
    final e = DailyGoal.normalizeDate(end);
    return _store
        .where(
          (g) =>
              !g.goalDate.isBefore(s) && !g.goalDate.isAfter(e),
        )
        .toList();
  }

  @override
  Future<DailyGoal> insertGoal(DailyGoal goal) async {
    final saved = goal.copyWith(
      id: _nextId++,
      goalDate: DailyGoal.normalizeDate(goal.goalDate),
    );
    _store.add(saved);
    return saved;
  }
}

Widget _buildApp(DailyGoalsProvider provider) {
  final router = GoRouter(
    initialLocation: '/daily_goals/calendar',
    routes: [
      GoRoute(
        path: '/daily_goals/calendar',
        builder: (context, state) => const DailyGoalsCalendarScreen(),
      ),
      GoRoute(
        path: '/daily_goals/day',
        builder: (context, state) => const Scaffold(body: Text('DayScreen')),
      ),
    ],
  );

  return ChangeNotifierProvider<DailyGoalsProvider>.value(
    value: provider,
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Lưới lịch + biểu đồ dài hơn khung hình mặc định trong test — phóng to bề
/// mặt test để mọi phần tử (kể cả các ô ngày cuối tháng) đều được build.
Future<void> _pumpApp(WidgetTester tester, DailyGoalsProvider provider) async {
  await tester.binding.setSurfaceSize(const Size(390, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_buildApp(provider));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tháng hiện tại chưa có mục tiêu hiện thông báo trống', (
    tester,
  ) async {
    final provider = DailyGoalsProvider(
      repository: _FakeDailyGoalRepository(),
    );

    await _pumpApp(tester, provider);

    expect(find.text('0/0 hoàn thành'), findsOneWidget);
    expect(
      find.text('Chưa có mục tiêu nào trong tháng này.'),
      findsOneWidget,
    );
  });

  testWidgets('có dữ liệu trong tháng hiện thị đúng tiến độ tháng', (
    tester,
  ) async {
    final repository = _FakeDailyGoalRepository();
    final now = DateTime.now();
    final today = DailyGoal.normalizeDate(now);
    await repository.insertGoal(
      DailyGoal(
        title: 'Việc đã xong',
        goalDate: today,
        isCompleted: true,
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.insertGoal(
      DailyGoal(
        title: 'Việc chưa xong',
        goalDate: today,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final provider = DailyGoalsProvider(repository: repository);

    await _pumpApp(tester, provider);

    expect(find.text('1/2 hoàn thành'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('nút tháng sau bị khóa ở tháng hiện tại, mở được tháng trước', (
    tester,
  ) async {
    final provider = DailyGoalsProvider(
      repository: _FakeDailyGoalRepository(),
    );
    final now = DateTime.now();

    await _pumpApp(tester, provider);

    expect(find.text('Tháng ${now.month}/${now.year}'), findsOneWidget);
    final nextButton = tester.widget<IconButton>(
      find.byKey(const Key('daily_goals_calendar_next')),
    );
    expect(nextButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('daily_goals_calendar_prev')));
    await tester.pumpAndSettle();

    final previousMonth = DateTime(now.year, now.month - 1);
    expect(
      find.text('Tháng ${previousMonth.month}/${previousMonth.year}'),
      findsOneWidget,
    );
    final nextButtonAfter = tester.widget<IconButton>(
      find.byKey(const Key('daily_goals_calendar_next')),
    );
    expect(nextButtonAfter.onPressed, isNotNull);
  });

  testWidgets('chạm vào 1 ngày điều hướng sang màn xem chi tiết ngày đó', (
    tester,
  ) async {
    final repository = _FakeDailyGoalRepository();
    final now = DateTime.now();
    await repository.insertGoal(
      DailyGoal(
        title: 'Việc hôm nay',
        goalDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final provider = DailyGoalsProvider(repository: repository);

    await _pumpApp(tester, provider);

    await tester.tap(find.byKey(Key('daily_goals_calendar_day_${now.day}')));
    await tester.pumpAndSettle();

    expect(find.text('DayScreen'), findsOneWidget);
  });
}
