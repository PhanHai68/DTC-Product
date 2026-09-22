// Repository cho chức năng "Mục tiêu hôm nay" (Daily Goals).
// Lưu trữ hoàn toàn offline trên SQLite (dùng chung user_data.db với module
// Ghi chú & Bảo trì) — không cần tài khoản hay đồng bộ cloud.

import '../core/database/local_database.dart';
import '../models/daily_goal.dart';

class DailyGoalRepository {
  DailyGoalRepository({LocalDatabase? database})
    : _db = database ?? LocalDatabase.instance;

  final LocalDatabase _db;

  static const _table = 'daily_goals';

  Future<List<DailyGoal>> getGoalsForDate(DateTime date) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'goalDate = ?',
      whereArgs: [DailyGoal.formatDateKey(date)],
      orderBy: 'isCompleted ASC, priority DESC, id ASC',
    );
    return rows.map(DailyGoal.fromMap).toList();
  }

  /// Dùng cho lịch sử/thống kê theo tháng — [start]/[end] là 2 đầu mút bao
  /// gồm (inclusive), chỉ so theo ngày.
  Future<List<DailyGoal>> getGoalsForDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'goalDate BETWEEN ? AND ?',
      whereArgs: [
        DailyGoal.formatDateKey(start),
        DailyGoal.formatDateKey(end),
      ],
      orderBy: 'goalDate ASC, isCompleted ASC, priority DESC, id ASC',
    );
    return rows.map(DailyGoal.fromMap).toList();
  }

  Future<List<DailyGoal>> getGoalsForMonth(int year, int month) {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1, 0);
    return getGoalsForDateRange(start, end);
  }

  /// Tìm mục tiêu theo tên/mô tả — chuẩn bị sẵn cho chức năng tìm kiếm ở
  /// DailyGoalsScreen, chưa bắt buộc dùng ở bản MVP.
  Future<List<DailyGoal>> searchGoals(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'title LIKE ? OR description LIKE ?',
      whereArgs: ['%$trimmed%', '%$trimmed%'],
      orderBy: 'goalDate DESC, id DESC',
    );
    return rows.map(DailyGoal.fromMap).toList();
  }

  Future<DailyGoal?> getGoalById(int id) async {
    final db = await _db.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return DailyGoal.fromMap(rows.first);
  }

  Future<DailyGoal> insertGoal(DailyGoal goal) async {
    final db = await _db.database;
    final id = await db.insert(_table, goal.toMap()..remove('id'));
    return (await getGoalById(id))!;
  }

  Future<DailyGoal> updateGoal(DailyGoal goal) async {
    if (goal.id == null) {
      throw ArgumentError('Không thể cập nhật mục tiêu chưa có id.');
    }
    final db = await _db.database;
    await db.update(
      _table,
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
    return (await getGoalById(goal.id!))!;
  }

  Future<void> deleteGoal(int id) async {
    final db = await _db.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Sao chép 1 mục tiêu chưa hoàn thành sang hôm nay — KHÔNG sửa/xóa mục
  /// tiêu gốc để không làm sai lệch dữ liệu lịch sử/thống kê của ngày cũ.
  Future<DailyGoal> moveToToday(DailyGoal goal) {
    final now = DateTime.now();
    return insertGoal(
      DailyGoal(
        title: goal.title,
        description: goal.description,
        goalDate: now,
        priority: goal.priority,
        projectId: goal.projectId,
        taskId: goal.taskId,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
