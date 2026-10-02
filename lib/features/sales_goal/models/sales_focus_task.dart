class SalesFocusTask {
  const SalesFocusTask({
    this.id,
    required this.title,
    required this.focusDate,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String title;
  final DateTime focusDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  SalesFocusTask copyWith({
    int? id,
    String? title,
    DateTime? focusDate,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
  }) => SalesFocusTask(
    id: id ?? this.id,
    title: title ?? this.title,
    focusDate: focusDate ?? this.focusDate,
    isCompleted: isCompleted ?? this.isCompleted,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'title': title,
    'focusDate': _dateOnly(focusDate),
    'isCompleted': isCompleted ? 1 : 0,
    'completedAt': completedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SalesFocusTask.fromMap(Map<String, Object?> map) => SalesFocusTask(
    id: map['id'] as int?,
    title: map['title'] as String,
    focusDate: DateTime.parse(map['focusDate'] as String),
    isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
    completedAt: map['completedAt'] == null
        ? null
        : DateTime.parse(map['completedAt'] as String),
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
