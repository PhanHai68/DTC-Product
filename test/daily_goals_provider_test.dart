import 'package:dtc_product/models/daily_goal.dart';
import 'package:dtc_product/providers/daily_goals_provider.dart';
import 'package:dtc_product/repositories/daily_goal_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository giả lưu trong bộ nhớ, tránh phụ thuộc SQLite thật khi test —
/// DailyGoalsProvider chỉ thao tác qua DailyGoalRepository nên có thể thay
/// thế an toàn (giống mẫu _FakeNoteRepository của Ghi chú & Nhắc hẹn).
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
    return _store.where((g) {
      final d = DailyGoal.normalizeDate(g.goalDate);
      return !d.isBefore(s) && !d.isAfter(e);
    }).toList();
  }

  @override
  Future<List<DailyGoal>> searchGoals(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _store
        .where(
          (g) =>
              g.title.toLowerCase().contains(q) ||
              g.description.toLowerCase().contains(q),
        )
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

  @override
  Future<void> deleteGoal(int id) async {
    _store.removeWhere((g) => g.id == id);
  }
}

void main() {
  group('DailyGoalsProvider', () {
    test('loadToday chỉ tải mục tiêu của hôm nay, bỏ qua ngày khác', () async {
      final repository = _FakeDailyGoalRepository();
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      await repository.insertGoal(
        DailyGoal(
          title: 'Việc hôm nay',
          goalDate: today,
          createdAt: today,
          updatedAt: today,
        ),
      );
      await repository.insertGoal(
        DailyGoal(
          title: 'Việc hôm qua',
          goalDate: yesterday,
          createdAt: yesterday,
          updatedAt: yesterday,
        ),
      );

      final provider = DailyGoalsProvider(repository: repository);
      await provider.loadToday();

      expect(provider.goals, hasLength(1));
      expect(provider.goals.single.title, 'Việc hôm nay');
      expect(provider.isToday, isTrue);
    });

    test('addGoal thêm mục tiêu mới và tự refresh danh sách', () async {
      final provider = DailyGoalsProvider(
        repository: _FakeDailyGoalRepository(),
      );
      await provider.loadToday();

      await provider.addGoal(title: 'Gửi báo giá cho khách hàng');

      expect(provider.goals, hasLength(1));
      expect(provider.goals.single.title, 'Gửi báo giá cho khách hàng');
      expect(provider.goals.single.isCompleted, isFalse);
      expect(provider.goals.single.priority, GoalPriority.medium);
    });

    test('toggleCompleted bật/tắt isCompleted và completedAt đúng', () async {
      final provider = DailyGoalsProvider(
        repository: _FakeDailyGoalRepository(),
      );
      await provider.loadToday();
      final goal = await provider.addGoal(title: 'Kiểm tra máy nén khí');

      await provider.toggleCompleted(goal);
      final completed = provider.goals.single;
      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, isNotNull);

      await provider.toggleCompleted(completed);
      final reverted = provider.goals.single;
      expect(reverted.isCompleted, isFalse);
      expect(reverted.completedAt, isNull);
    });

    test('progress tính đúng theo số hoàn thành/tổng, không lỗi chia 0', () async {
      final provider = DailyGoalsProvider(
        repository: _FakeDailyGoalRepository(),
      );
      await provider.loadToday();
      expect(provider.progress.total, 0);
      expect(provider.progress.percent, 0);

      final a = await provider.addGoal(title: 'A');
      await provider.addGoal(title: 'B');
      await provider.addGoal(title: 'C');
      await provider.toggleCompleted(a);

      expect(provider.progress.completed, 1);
      expect(provider.progress.total, 3);
      expect(provider.progress.percent, 33);
    });

    test('deleteGoal xóa khỏi danh sách', () async {
      final provider = DailyGoalsProvider(
        repository: _FakeDailyGoalRepository(),
      );
      await provider.loadToday();
      final goal = await provider.addGoal(title: 'Việc cần xóa');

      await provider.deleteGoal(goal.id!);

      expect(provider.goals, isEmpty);
    });

    test('editGoal cập nhật đúng và giữ nguyên id', () async {
      final provider = DailyGoalsProvider(
        repository: _FakeDailyGoalRepository(),
      );
      await provider.loadToday();
      final goal = await provider.addGoal(
        title: 'Tên cũ',
        priority: GoalPriority.low,
      );

      await provider.editGoal(
        goal.copyWith(title: 'Tên mới', priority: GoalPriority.critical),
      );

      final updated = provider.goals.single;
      expect(updated.id, goal.id);
      expect(updated.title, 'Tên mới');
      expect(updated.priority, GoalPriority.critical);
    });

    test('moveToToday tạo bản sao cho hôm nay, giữ nguyên bản gốc trong lịch sử', () async {
      final repository = _FakeDailyGoalRepository();
      final provider = DailyGoalsProvider(repository: repository);
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final original = await repository.insertGoal(
        DailyGoal(
          title: 'Việc chưa xong hôm qua',
          goalDate: yesterday,
          priority: GoalPriority.high,
          createdAt: yesterday,
          updatedAt: yesterday,
        ),
      );
      await provider.loadToday();

      await provider.moveToToday(original);

      // Bản gốc vẫn còn nguyên, đúng ngày cũ, không bị sửa.
      final storedOriginal = await repository.getGoalById(original.id!);
      expect(storedOriginal!.goalDate, DailyGoal.normalizeDate(yesterday));
      expect(storedOriginal.title, 'Việc chưa xong hôm qua');

      // Có thêm 1 mục tiêu mới cho hôm nay với cùng nội dung.
      expect(provider.goals, hasLength(1));
      final copy = provider.goals.single;
      expect(copy.id, isNot(original.id));
      expect(copy.title, original.title);
      expect(copy.priority, original.priority);
      expect(DailyGoal.isSameDate(copy.goalDate, DateTime.now()), isTrue);
    });
  });
}
