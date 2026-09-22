import 'package:dtc_product/models/daily_goal.dart';
import 'package:dtc_product/providers/daily_goals_provider.dart';
import 'package:dtc_product/providers/settings_provider.dart';
import 'package:dtc_product/repositories/daily_goal_repository.dart';
import 'package:dtc_product/widgets/daily_goals/daily_goal_home_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // goalDate luôn qua toMap/fromMap (chuẩn hóa chỉ-ngày) trong repository
    // thật khi ghi SQLite — chuẩn hóa ở đây để fake mô phỏng đúng hành vi.
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
}

Widget _buildApp(SettingsProvider settings, DailyGoalsProvider goals) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: DailyGoalHomeCard()),
      ),
      GoRoute(
        path: '/daily_goals',
        builder: (context, state) =>
            const Scaffold(body: Text('DailyGoalsScreen')),
      ),
      GoRoute(
        path: '/daily_goals/form',
        builder: (context, state) =>
            const Scaffold(body: Text('DailyGoalFormScreen')),
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<DailyGoalsProvider>.value(value: goals),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('không hiển thị gì khi "Mục tiêu hôm nay" đang tắt', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);
    final goals = DailyGoalsProvider(repository: _FakeDailyGoalRepository());

    await tester.pumpWidget(_buildApp(settings, goals));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily_goal_home_card')), findsNothing);
  });

  testWidgets('trạng thái rỗng hiện thông báo và nút thêm mục tiêu', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);
    await settings.saveHomePersonalization(
      enabled: false,
      displayName: '',
      shortText: '',
      nameFontSize: SettingsProvider.defaultHomeNameFontSize,
      nameColor: null,
      nameItalic: false,
      shortTextFontSize: SettingsProvider.defaultHomeShortTextFontSize,
      shortTextColor: null,
      shortTextItalic: false,
      dailyGoalsEnabled: true,
      dailyGoalsTitle: 'Mục tiêu hôm nay',
    );
    final goals = DailyGoalsProvider(repository: _FakeDailyGoalRepository());

    await tester.pumpWidget(_buildApp(settings, goals));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily_goal_home_card')), findsOneWidget);
    expect(find.text('MỤC TIÊU HÔM NAY'), findsOneWidget);
    expect(
      find.textContaining('Hôm nay chưa có mục tiêu nào.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('daily_goal_add_button')), findsOneWidget);
  });

  testWidgets('hiện danh sách, tiến độ và tối đa 3 mục tiêu + "Xem thêm"', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);
    await settings.saveHomePersonalization(
      enabled: false,
      displayName: '',
      shortText: '',
      nameFontSize: SettingsProvider.defaultHomeNameFontSize,
      nameColor: null,
      nameItalic: false,
      shortTextFontSize: SettingsProvider.defaultHomeShortTextFontSize,
      shortTextColor: null,
      shortTextItalic: false,
      dailyGoalsEnabled: true,
      dailyGoalsTitle: 'Công việc hôm nay',
    );
    final repository = _FakeDailyGoalRepository();
    final now = DateTime.now();
    for (final title in ['A', 'B', 'C', 'D']) {
      await repository.insertGoal(
        DailyGoal(
          title: title,
          goalDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    final goals = DailyGoalsProvider(repository: repository);

    await tester.pumpWidget(_buildApp(settings, goals));
    await tester.pumpAndSettle();

    expect(find.text('CÔNG VIỆC HÔM NAY'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('D'), findsNothing);
    expect(find.text('Xem thêm 1 mục tiêu'), findsOneWidget);
    expect(find.text('0/4'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('chạm vào 1 mục tiêu để tick hoàn thành cập nhật tiến độ ngay', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsProvider(prefs);
    await settings.saveHomePersonalization(
      enabled: false,
      displayName: '',
      shortText: '',
      nameFontSize: SettingsProvider.defaultHomeNameFontSize,
      nameColor: null,
      nameItalic: false,
      shortTextFontSize: SettingsProvider.defaultHomeShortTextFontSize,
      shortTextColor: null,
      shortTextItalic: false,
      dailyGoalsEnabled: true,
      dailyGoalsTitle: 'Mục tiêu hôm nay',
    );
    final repository = _FakeDailyGoalRepository();
    final now = DateTime.now();
    await repository.insertGoal(
      DailyGoal(
        title: 'Hoàn thành báo cáo test',
        goalDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final goals = DailyGoalsProvider(repository: repository);

    await tester.pumpWidget(_buildApp(settings, goals));
    await tester.pumpAndSettle();

    expect(find.text('0/1'), findsOneWidget);

    await tester.tap(find.text('Hoàn thành báo cáo test'));
    await tester.pumpAndSettle();

    // Yêu cầu xác nhận trước khi tick, tránh bấm nhầm.
    expect(find.text('Hoàn thành mục tiêu?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
    await tester.pumpAndSettle();

    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });
}
