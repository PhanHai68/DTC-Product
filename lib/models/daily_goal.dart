/// Mức độ ưu tiên của một mục tiêu trong ngày.
enum GoalPriority {
  low(0, 'Thấp'),
  medium(1, 'Trung bình'),
  high(2, 'Cao'),
  critical(3, 'Quan trọng');

  const GoalPriority(this.level, this.label);

  final int level;
  final String label;

  static GoalPriority fromName(String? name) => GoalPriority.values
      .firstWhere((e) => e.name == name, orElse: () => GoalPriority.medium);
}

/// Một mục tiêu công việc trong ngày ("Mục tiêu hôm nay" / Daily Goals).
///
/// [goalDate] luôn được chuẩn hóa về chỉ-ngày (bỏ giờ/phút/giây) — mọi so
/// sánh "hôm nay"/theo tháng phải dựa vào [goalDate] đã chuẩn hóa này, không
/// bao giờ so sánh DateTime đầy đủ để tránh sai lệch do giờ/phút/giây.
///
/// [projectId]/[taskId] hiện chưa dùng tới, chuẩn bị sẵn cho việc liên kết
/// với Project Timeline trong tương lai (chưa có logic đồng bộ).
class DailyGoal {
  final int? id;
  final String title;
  final String description;
  final DateTime goalDate;
  final GoalPriority priority;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? projectId;
  final String? taskId;

  const DailyGoal({
    this.id,
    required this.title,
    this.description = '',
    required this.goalDate,
    this.priority = GoalPriority.medium,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.projectId,
    this.taskId,
  });

  /// Bỏ giờ/phút/giây — mốc duy nhất dùng để so sánh "cùng ngày".
  static DateTime normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool isSameDate(DateTime a, DateTime b) {
    final na = normalizeDate(a);
    final nb = normalizeDate(b);
    return na.year == nb.year && na.month == nb.month && na.day == nb.day;
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// Khóa ngày dạng 'yyyy-MM-dd' dùng để lưu DB và query theo ngày/tháng.
  static String formatDateKey(DateTime date) {
    final d = normalizeDate(date);
    return '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';
  }

  static DateTime parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  DailyGoal copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? goalDate,
    GoalPriority? priority,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? projectId,
    String? taskId,
  }) {
    return DailyGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      goalDate: goalDate ?? this.goalDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt
          ? null
          : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      projectId: projectId ?? this.projectId,
      taskId: taskId ?? this.taskId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'goalDate': formatDateKey(goalDate),
      'priority': priority.name,
      'isCompleted': isCompleted ? 1 : 0,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'projectId': projectId,
      'taskId': taskId,
    };
  }

  factory DailyGoal.fromMap(Map<String, dynamic> map) {
    return DailyGoal(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      goalDate: parseDateKey(map['goalDate'] as String),
      priority: GoalPriority.fromName(map['priority'] as String?),
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
      completedAt: map['completedAt'] == null
          ? null
          : DateTime.parse(map['completedAt'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      projectId: map['projectId'] as String?,
      taskId: map['taskId'] as String?,
    );
  }
}

/// Tiến độ hoàn thành của 1 tập mục tiêu (1 ngày, 1 tháng...).
class GoalProgress {
  const GoalProgress({required this.completed, required this.total});

  final int completed;
  final int total;

  /// 0.0–1.0, luôn 0 khi [total] = 0 (không chia cho 0).
  double get ratio => total == 0 ? 0 : completed / total;

  /// Phần trăm làm tròn, VD 67 (từ 66.7%).
  int get percent => (ratio * 100).round();
}
