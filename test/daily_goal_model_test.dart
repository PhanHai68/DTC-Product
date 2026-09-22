import 'package:dtc_product/models/daily_goal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoalPriority', () {
    test('fromName trả đúng giá trị, không khớp thì về Trung bình', () {
      expect(GoalPriority.fromName('low'), GoalPriority.low);
      expect(GoalPriority.fromName('high'), GoalPriority.high);
      expect(GoalPriority.fromName('critical'), GoalPriority.critical);
      expect(GoalPriority.fromName('không tồn tại'), GoalPriority.medium);
      expect(GoalPriority.fromName(null), GoalPriority.medium);
    });
  });

  group('DailyGoal — chuẩn hóa ngày', () {
    test('normalizeDate bỏ giờ/phút/giây', () {
      final value = DailyGoal.normalizeDate(DateTime(2026, 9, 22, 23, 59, 59));
      expect(value, DateTime(2026, 9, 22));
    });

    test('isSameDate chỉ so theo ngày, bỏ qua giờ', () {
      expect(
        DailyGoal.isSameDate(
          DateTime(2026, 9, 22, 8, 0),
          DateTime(2026, 9, 22, 23, 0),
        ),
        isTrue,
      );
      expect(
        DailyGoal.isSameDate(DateTime(2026, 9, 22), DateTime(2026, 9, 23)),
        isFalse,
      );
    });

    test('formatDateKey/parseDateKey round-trip đúng', () {
      final date = DateTime(2026, 1, 5);
      final key = DailyGoal.formatDateKey(date);
      expect(key, '2026-01-05');
      expect(DailyGoal.parseDateKey(key), date);
    });
  });

  group('DailyGoal.toMap / fromMap', () {
    test('round-trip giữ nguyên toàn bộ dữ liệu', () {
      final original = DailyGoal(
        id: 7,
        title: 'Chạy thử máy SX8',
        description: 'Kiểm tra năng suất trước khi bàn giao',
        goalDate: DateTime(2026, 9, 22),
        priority: GoalPriority.high,
        isCompleted: true,
        completedAt: DateTime(2026, 9, 22, 15, 30),
        createdAt: DateTime(2026, 9, 22, 8, 0),
        updatedAt: DateTime(2026, 9, 22, 15, 30),
        projectId: 'project_1',
        taskId: 'stage_1',
      );

      final restored = DailyGoal.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.goalDate, original.goalDate);
      expect(restored.priority, GoalPriority.high);
      expect(restored.isCompleted, isTrue);
      expect(restored.completedAt, original.completedAt);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.projectId, 'project_1');
      expect(restored.taskId, 'stage_1');
    });

    test('cờ isCompleted lưu dạng 0/1 và đọc lại đúng khi tắt', () {
      final goal = DailyGoal(
        title: 'Việc gì đó',
        goalDate: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final map = goal.toMap();
      expect(map['isCompleted'], 0);
      expect(map['completedAt'], isNull);
      expect(map['projectId'], isNull);
      expect(map['taskId'], isNull);

      final restored = DailyGoal.fromMap(map);
      expect(restored.isCompleted, isFalse);
      expect(restored.completedAt, isNull);
    });
  });

  group('DailyGoal.copyWith', () {
    test('clearCompletedAt xóa completedAt về null dù truyền completedAt khác', () {
      final goal = DailyGoal(
        title: 'A',
        goalDate: DateTime(2026, 1, 1),
        isCompleted: true,
        completedAt: DateTime(2026, 1, 1, 10),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final updated = goal.copyWith(isCompleted: false, clearCompletedAt: true);
      expect(updated.isCompleted, isFalse);
      expect(updated.completedAt, isNull);
    });
  });

  group('GoalProgress', () {
    test('tính đúng tỉ lệ và làm tròn phần trăm', () {
      const progress = GoalProgress(completed: 2, total: 3);
      expect(progress.ratio, closeTo(0.6667, 0.001));
      expect(progress.percent, 67);
    });

    test('total = 0 trả về 0%, không chia cho 0', () {
      const progress = GoalProgress(completed: 0, total: 0);
      expect(progress.ratio, 0);
      expect(progress.percent, 0);
    });
  });
}
