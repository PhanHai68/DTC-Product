import 'package:dtc_product/models/note.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReminderLeadTime', () {
    test('fromMinutes trả đúng lựa chọn tương ứng', () {
      expect(ReminderLeadTime.fromMinutes(0), ReminderLeadTime.onTime);
      expect(ReminderLeadTime.fromMinutes(10), ReminderLeadTime.min10);
      expect(ReminderLeadTime.fromMinutes(30), ReminderLeadTime.min30);
      expect(ReminderLeadTime.fromMinutes(60), ReminderLeadTime.hour1);
      expect(ReminderLeadTime.fromMinutes(1440), ReminderLeadTime.day1);
    });

    test('giá trị không khớp sẽ rơi về "Đúng giờ"', () {
      expect(ReminderLeadTime.fromMinutes(999), ReminderLeadTime.onTime);
    });
  });

  group('Note.notifyAt', () {
    final reminderTime = DateTime(2026, 9, 25, 9, 0);

    test('null khi không bật nhắc hẹn', () {
      final note = Note(
        title: 'Gọi khách',
        content: '',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
        reminderEnabled: false,
        reminderDateTime: reminderTime,
      );
      expect(note.notifyAt, isNull);
    });

    test('bằng đúng giờ hẹn khi nhắc trước = 0 (Đúng giờ)', () {
      final note = Note(
        title: 'Gọi khách',
        content: '',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
        reminderEnabled: true,
        reminderDateTime: reminderTime,
        reminderBeforeMinutes: 0,
      );
      expect(note.notifyAt, reminderTime);
    });

    test('trừ đúng số phút khi chọn nhắc trước 30 phút', () {
      final note = Note(
        title: 'Gọi khách',
        content: '',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
        reminderEnabled: true,
        reminderDateTime: reminderTime,
        reminderBeforeMinutes: 30,
      );
      expect(note.notifyAt, DateTime(2026, 9, 25, 8, 30));
    });

    test('trừ đúng 1 ngày khi chọn nhắc trước 1 ngày', () {
      final note = Note(
        title: 'Gọi khách',
        content: '',
        createdAt: DateTime(2026, 9, 20),
        updatedAt: DateTime(2026, 9, 20),
        reminderEnabled: true,
        reminderDateTime: reminderTime,
        reminderBeforeMinutes: 1440,
      );
      expect(note.notifyAt, DateTime(2026, 9, 24, 9, 0));
    });
  });

  group('Note.toMap / fromMap', () {
    test('round-trip giữ nguyên toàn bộ dữ liệu', () {
      final original = Note(
        id: 7,
        title: 'Thông số máy DF53S',
        content: 'Lưu thông số máy để tra cứu.',
        createdAt: DateTime(2026, 9, 20, 10, 30),
        updatedAt: DateTime(2026, 9, 21, 8, 0),
        isPinned: true,
        reminderEnabled: true,
        reminderDateTime: DateTime(2026, 9, 25, 9, 0),
        reminderBeforeMinutes: 30,
        notificationId: 7,
      );

      final restored = Note.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.content, original.content);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.isPinned, isTrue);
      expect(restored.reminderEnabled, isTrue);
      expect(restored.reminderDateTime, original.reminderDateTime);
      expect(restored.reminderBeforeMinutes, 30);
      expect(restored.notificationId, 7);
    });

    test('cờ boolean lưu dạng 0/1 và đọc lại đúng khi tắt', () {
      final note = Note(
        title: '',
        content: '',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        isPinned: false,
        reminderEnabled: false,
      );
      final map = note.toMap();
      expect(map['isPinned'], 0);
      expect(map['reminderEnabled'], 0);

      final restored = Note.fromMap(map);
      expect(restored.isPinned, isFalse);
      expect(restored.reminderEnabled, isFalse);
    });
  });

  group('ChecklistItem.toMap / fromMap', () {
    test('round-trip giữ nguyên dữ liệu', () {
      const item = ChecklistItem(
        id: 3,
        noteId: 7,
        text: 'Gửi báo giá',
        isCompleted: true,
        sortOrder: 2,
      );
      final restored = ChecklistItem.fromMap(item.toMap());
      expect(restored.id, 3);
      expect(restored.noteId, 7);
      expect(restored.text, 'Gửi báo giá');
      expect(restored.isCompleted, isTrue);
      expect(restored.sortOrder, 2);
    });
  });
}
