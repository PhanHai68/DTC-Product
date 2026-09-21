/// Mức nhắc trước khi tới giờ hẹn, dùng cho tính năng "Nhắc tôi".
enum ReminderLeadTime {
  onTime(0, 'Đúng giờ'),
  min10(10, '10 phút'),
  min30(30, '30 phút'),
  hour1(60, '1 giờ'),
  day1(1440, '1 ngày');

  const ReminderLeadTime(this.minutes, this.label);

  final int minutes;
  final String label;

  static ReminderLeadTime fromMinutes(int minutes) => ReminderLeadTime.values
      .firstWhere((e) => e.minutes == minutes, orElse: () => ReminderLeadTime.onTime);
}

/// Một mục trong checklist bên trong ghi chú.
class ChecklistItem {
  final int? id;
  final int? noteId;
  final String text;
  final bool isCompleted;
  final int sortOrder;

  const ChecklistItem({
    this.id,
    this.noteId,
    required this.text,
    this.isCompleted = false,
    this.sortOrder = 0,
  });

  ChecklistItem copyWith({
    int? id,
    int? noteId,
    String? text,
    bool? isCompleted,
    int? sortOrder,
  }) {
    return ChecklistItem(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'noteId': noteId,
      'text': text,
      'isCompleted': isCompleted ? 1 : 0,
      'sortOrder': sortOrder,
    };
  }

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      id: map['id'] as int?,
      noteId: map['noteId'] as int?,
      text: map['text'] as String? ?? '',
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }
}

/// Ghi chú cá nhân, có thể kèm nhắc hẹn theo ngày giờ và checklist.
class Note {
  final int? id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  final bool isPinned;

  final bool reminderEnabled;
  final DateTime? reminderDateTime;
  final int reminderBeforeMinutes;

  /// ID dùng để lên lịch/huỷ local notification — luôn khớp với [id] khi
  /// ghi chú đã được lưu, để tránh trùng lặp notification giữa các ghi chú.
  final int? notificationId;

  final List<ChecklistItem> checklistItems;

  const Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.reminderEnabled = false,
    this.reminderDateTime,
    this.reminderBeforeMinutes = 0,
    this.notificationId,
    this.checklistItems = const [],
  });

  ReminderLeadTime get reminderLeadTime =>
      ReminderLeadTime.fromMinutes(reminderBeforeMinutes);

  /// Thời điểm thực tế cần bắn notification (giờ hẹn - thời gian nhắc trước).
  DateTime? get notifyAt {
    if (!reminderEnabled || reminderDateTime == null) return null;
    return reminderDateTime!.subtract(
      Duration(minutes: reminderBeforeMinutes),
    );
  }

  bool get hasChecklist => checklistItems.isNotEmpty;

  int get completedChecklistCount =>
      checklistItems.where((e) => e.isCompleted).length;

  Note copyWith({
    int? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    bool? reminderEnabled,
    DateTime? reminderDateTime,
    bool clearReminderDateTime = false,
    int? reminderBeforeMinutes,
    int? notificationId,
    List<ChecklistItem>? checklistItems,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDateTime: clearReminderDateTime
          ? null
          : (reminderDateTime ?? this.reminderDateTime),
      reminderBeforeMinutes:
          reminderBeforeMinutes ?? this.reminderBeforeMinutes,
      notificationId: notificationId ?? this.notificationId,
      checklistItems: checklistItems ?? this.checklistItems,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isPinned': isPinned ? 1 : 0,
      'reminderEnabled': reminderEnabled ? 1 : 0,
      'reminderDateTime': reminderDateTime?.toIso8601String(),
      'reminderBeforeMinutes': reminderBeforeMinutes,
      'notificationId': notificationId,
    };
  }

  factory Note.fromMap(
    Map<String, dynamic> map, {
    List<ChecklistItem> checklistItems = const [],
  }) {
    return Note(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      isPinned: (map['isPinned'] as int? ?? 0) == 1,
      reminderEnabled: (map['reminderEnabled'] as int? ?? 0) == 1,
      reminderDateTime: map['reminderDateTime'] == null
          ? null
          : DateTime.tryParse(map['reminderDateTime'] as String),
      reminderBeforeMinutes: map['reminderBeforeMinutes'] as int? ?? 0,
      notificationId: map['notificationId'] as int?,
      checklistItems: checklistItems,
    );
  }
}
