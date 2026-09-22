import 'package:flutter/foundation.dart';

import '../models/daily_goal.dart';
import '../repositories/daily_goal_repository.dart';

/// Quản lý mục tiêu công việc trong ngày ("Mục tiêu hôm nay").
///
/// [selectedDate] là ngày đang xem/thao tác (mặc định hôm nay) — chuẩn bị
/// sẵn cho DailyGoalsScreen chuyển qua xem ngày khác ở Phase 2 (lịch sử),
/// dù Phase 1 chỉ dùng ngày hôm nay.
class DailyGoalsProvider extends ChangeNotifier {
  DailyGoalsProvider({DailyGoalRepository? repository})
    : _repository = repository ?? DailyGoalRepository();

  final DailyGoalRepository _repository;

  DateTime _selectedDate = DailyGoal.normalizeDate(DateTime.now());
  List<DailyGoal> _goals = const [];
  bool _isLoading = false;
  String? _errorMessage;

  DateTime get selectedDate => _selectedDate;
  List<DailyGoal> get goals => _goals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isToday => DailyGoal.isSameDate(_selectedDate, DateTime.now());

  GoalProgress get progress => GoalProgress(
    completed: _goals.where((g) => g.isCompleted).length,
    total: _goals.length,
  );

  Future<void> loadToday() => loadDate(DateTime.now());

  Future<void> loadDate(DateTime date) async {
    _selectedDate = DailyGoal.normalizeDate(date);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _goals = await _repository.getGoalsForDate(_selectedDate);
    } catch (error) {
      _errorMessage = 'Không thể tải mục tiêu: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refresh() => loadDate(_selectedDate);

  Future<DailyGoal> addGoal({
    required String title,
    String description = '',
    DateTime? goalDate,
    GoalPriority priority = GoalPriority.medium,
    String? projectId,
    String? taskId,
  }) async {
    final now = DateTime.now();
    final goal = DailyGoal(
      title: title.trim(),
      description: description.trim(),
      goalDate: goalDate ?? _selectedDate,
      priority: priority,
      projectId: projectId,
      taskId: taskId,
      createdAt: now,
      updatedAt: now,
    );
    final saved = await _repository.insertGoal(goal);
    await _refresh();
    return saved;
  }

  Future<void> editGoal(DailyGoal goal) async {
    await _repository.updateGoal(goal.copyWith(updatedAt: DateTime.now()));
    await _refresh();
  }

  Future<void> deleteGoal(int id) async {
    await _repository.deleteGoal(id);
    await _refresh();
  }

  Future<void> toggleCompleted(DailyGoal goal) async {
    final now = DateTime.now();
    final updated = goal.isCompleted
        ? goal.copyWith(
            isCompleted: false,
            clearCompletedAt: true,
            updatedAt: now,
          )
        : goal.copyWith(isCompleted: true, completedAt: now, updatedAt: now);
    await _repository.updateGoal(updated);
    await _refresh();
  }

  /// Sao chép mục tiêu chưa hoàn thành sang hôm nay, giữ nguyên bản gốc
  /// trong lịch sử.
  Future<void> moveToToday(DailyGoal goal) async {
    await _repository.moveToToday(goal);
    if (isToday) await _refresh();
  }

  Future<List<DailyGoal>> searchGoals(String query) =>
      _repository.searchGoals(query);

  /// Đọc thuần túy toàn bộ mục tiêu trong 1 tháng — dùng cho màn hình Lịch
  /// sử/Thống kê (Phase 2). KHÔNG đụng tới [selectedDate]/[goals] để không
  /// làm lệch dữ liệu "hôm nay" mà HomeScreen đang hiển thị.
  Future<List<DailyGoal>> loadMonth(DateTime month) =>
      _repository.getGoalsForMonth(month.year, month.month);
}
