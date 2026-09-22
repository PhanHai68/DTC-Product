// Nhắc nhở cuối ngày cho "Mục tiêu hôm nay" (Daily Goals — Phase 3). Dùng
// CHUNG plugin/kênh khởi tạo bởi NoteNotificationService (xem comment đầu
// file đó) để tránh xung đột callback khi người dùng bấm vào thông báo.
//
// Đây là 1 lời nhắc LẶP LẠI HÀNG NGÀY vào 1 giờ cố định do người dùng chọn
// (VD: 20:00), không phải nhắc riêng theo từng mục tiêu — nội dung thông báo
// vì vậy cố định (không truy vấn số mục tiêu còn dở tại thời điểm bắn thông
// báo), giống đúng cách NoteNotificationService xử lý nhắc hẹn ghi chú.
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../routes/app_routes.dart';
import 'note_notification_service.dart';

abstract final class DailyGoalNotificationService {
  static const channelId = 'daily_goals_reminder';
  static const channelName = 'Nhắc mục tiêu hôm nay';
  static const channelDescription =
      'Nhắc nhở cuối ngày nếu còn mục tiêu công việc chưa hoàn thành';

  /// Tiền tố payload để NoteNotificationService phân biệt và chuyển tiếp tap
  /// thông báo đúng cho tính năng Mục tiêu hôm nay.
  static const payloadPrefix = 'daily_goals_reminder:';

  /// Chỉ 1 lời nhắc lặp lại duy nhất (không theo từng mục tiêu) nên dùng 1 ID
  /// cố định — id nằm ngoài dải id ghi chú (int nhỏ) và dải hạn giai đoạn dự
  /// án (900000000+).
  static const _notificationId = 850000001;

  static void handleTap(String payload) {
    appRouter.push('/daily_goals');
  }

  /// Lên lịch (hoặc thay thế lịch cũ) nhắc nhở lặp lại mỗi ngày vào [hour]:
  /// [minute]. Không làm gì nếu plugin thông báo không khởi tạo được trên
  /// thiết bị này.
  static Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    await NoteNotificationService.ensureInitialized();
    if (!NoteNotificationService.isReady) return;

    final now = DateTime.now();
    var notifyAt = DateTime(now.year, now.month, now.day, hour, minute);
    if (notifyAt.isBefore(now)) {
      notifyAt = notifyAt.add(const Duration(days: 1));
    }
    final scheduledDate = tz.TZDateTime.from(notifyAt, tz.local);

    try {
      await NoteNotificationService.sharedPlugin.zonedSchedule(
        id: _notificationId,
        scheduledDate: scheduledDate,
        title: 'Mục tiêu hôm nay',
        body: 'Kiểm tra lại các mục tiêu công việc hôm nay của bạn nhé.',
        payload: payloadPrefix,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(''),
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Không thể lên lịch nhắc mục tiêu hôm nay',
        name: 'DailyGoalNotificationService',
        error: error,
        stackTrace: stackTrace,
      );
      if (kDebugMode) rethrow;
    }
  }

  static Future<void> cancelDailyReminder() async {
    await NoteNotificationService.ensureInitialized();
    if (!NoteNotificationService.isReady) return;
    try {
      await NoteNotificationService.sharedPlugin.cancel(id: _notificationId);
    } catch (error) {
      developer.log(
        'Không thể huỷ nhắc mục tiêu hôm nay',
        name: 'DailyGoalNotificationService',
        error: error,
      );
    }
  }
}
