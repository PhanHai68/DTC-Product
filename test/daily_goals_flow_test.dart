import 'package:dtc_product/models/daily_goal.dart';
import 'package:dtc_product/providers/daily_goals_provider.dart';
import 'package:dtc_product/repositories/daily_goal_repository.dart';
import 'package:dtc_product/screens/daily_goals/daily_goal_form_screen.dart';
import 'package:dtc_product/screens/daily_goals/daily_goals_screen.dart';
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
  Future<DailyGoal?> getGoalById(int id) async {
    try {
      return _store.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
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

  @override
  Future<DailyGoal> updateGoal(DailyGoal goal) async {
    final index = _store.indexWhere((g) => g.id == goal.id);
    if (index == -1) throw StateError('Không tìm thấy mục tiêu.');
    final normalized = goal.copyWith(
      goalDate: DailyGoal.normalizeDate(goal.goalDate),
    );
    _store[index] = normalized;
    return normalized;
  }

  @override
  Future<void> deleteGoal(int id) async {
    _store.removeWhere((g) => g.id == id);
  }
}

Widget _buildApp(DailyGoalsProvider provider) {
  final router = GoRouter(
    initialLocation: '/daily_goals',
    routes: [
      GoRoute(
        path: '/daily_goals',
        builder: (context, state) => const DailyGoalsScreen(),
      ),
      GoRoute(
        path: '/daily_goals/form',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return DailyGoalFormScreen(goal: extra?['goal'] as DailyGoal?);
        },
      ),
    ],
  );

  return ChangeNotifierProvider<DailyGoalsProvider>.value(
    value: provider,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('Trạng thái rỗng hiện thông báo và nút thêm mục tiêu', (
    tester,
  ) async {
    final provider = DailyGoalsProvider(
      repository: _FakeDailyGoalRepository(),
    );
    await provider.loadToday();

    await tester.pumpWidget(_buildApp(provider));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có mục tiêu nào.'), findsOneWidget);
    expect(find.text('Mục tiêu công việc'), findsOneWidget);
  });

  testWidgets('Thêm mục tiêu mới từ form quay lại hiện đúng trong danh sách', (
    tester,
  ) async {
    final provider = DailyGoalsProvider(
      repository: _FakeDailyGoalRepository(),
    );
    await provider.loadToday();

    await tester.pumpWidget(_buildApp(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm mục tiêu'));
    await tester.pumpAndSettle();

    expect(find.text('Thêm mục tiêu'), findsWidgets);

    // Chưa nhập tên -> báo lỗi bắt buộc, không cho lưu.
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm mục tiêu'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập tên mục tiêu'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('daily_goal_title_field')),
      'Gửi báo giá cho khách hàng',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm mục tiêu'));
    await tester.pumpAndSettle();

    expect(find.text('Mục tiêu công việc'), findsOneWidget);
    expect(find.text('Gửi báo giá cho khách hàng'), findsOneWidget);
    expect(provider.goals, hasLength(1));
  });

  testWidgets('Tick hoàn thành cập nhật trạng thái và tiến độ ngay', (
    tester,
  ) async {
    final repository = _FakeDailyGoalRepository();
    final now = DateTime.now();
    await repository.insertGoal(
      DailyGoal(
        title: 'Kiểm tra máy nén khí',
        goalDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final provider = DailyGoalsProvider(repository: repository);
    await provider.loadToday();

    await tester.pumpWidget(_buildApp(provider));
    await tester.pumpAndSettle();

    expect(find.text('0/1 hoàn thành'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.radio_button_unchecked_rounded));
    await tester.pumpAndSettle();

    expect(find.text('1/1 hoàn thành'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('Xóa mục tiêu yêu cầu xác nhận trước khi xóa thật', (
    tester,
  ) async {
    final repository = _FakeDailyGoalRepository();
    final now = DateTime.now();
    await repository.insertGoal(
      DailyGoal(
        title: 'Mục tiêu sẽ bị xóa',
        goalDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final provider = DailyGoalsProvider(repository: repository);
    await provider.loadToday();

    await tester.pumpWidget(_buildApp(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    // Hộp thoại xác nhận hiện ra, mục tiêu chưa mất ngay.
    expect(find.text('Xóa mục tiêu?'), findsOneWidget);
    expect(provider.goals, hasLength(1));

    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();

    expect(provider.goals, isEmpty);
    expect(find.text('Chưa có mục tiêu nào.'), findsOneWidget);
  });
}
