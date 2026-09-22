// Nhắc hạn giai đoạn dự án ("Schedule Project") — dùng CHUNG plugin/kênh khởi
// tạo bởi NoteNotificationService (xem comment đầu file đó) để tránh xung đột
// callback khi người dùng bấm vào thông báo. File này chỉ định nghĩa những gì
// riêng của tính năng dự án: tên kênh Android, cách sinh notification id từ
// stageId (String) không trùng với id ghi chú (int nhỏ), thời điểm nhắc, và
// điều hướng khi bấm vào thông báo.
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../routes/app_routes.dart';
import '../../../services/note_notification_service.dart';
import '../models/project_stage.dart';

abstract final class ProjectNotificationService {
  static const channelId = 'project_deadlines';
  static const channelName = 'Hạn giai đoạn dự án';
  static const channelDescription =
      'Nhắc trước khi đến hạn kế hoạch của một giai đoạn dự án';

  /// Tiền tố payload để NoteNotificationService phân biệt và chuyển tiếp tap
  /// thông báo đúng cho tính năng dự án.
  static const payloadPrefix = 'project_stage:';

  /// Dải notification ID riêng cho giai đoạn dự án — stageId là String nên
  /// băm ra int, cộng offset lớn để không bao giờ trùng với id ghi chú (vốn
  /// là số nguyên nhỏ tăng dần từ SQLite autoincrement).
  static int _notificationIdFor(String stageId) =>
      900000000 + (stageId.hashCode.abs() % 1000000);

  /// Nhắc lúc 08:00 sáng, trước 1 ngày so với hạn kế hoạch (plannedEndDate).
  static DateTime _reminderTimeFor(DateTime plannedEndDate) {
    final dayBefore = plannedEndDate.subtract(const Duration(days: 1));
    return DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 8);
  }

  static void handleTap(String payload) {
    final parts = payload.split('|');
    if (parts.length != 2) return;
    final projectId = parts[0];
    final stageId = parts[1];
    if (projectId.isEmpty || stageId.isEmpty) return;
    appRouter.push('/projects/$projectId/stages/$stageId');
  }

  /// Lên lịch (hoặc thay thế lịch cũ) nhắc hạn cho 1 giai đoạn. Không làm gì
  /// nếu giai đoạn đã hoàn thành, không có hạn kế hoạch, hoặc thời điểm nhắc
  /// đã ở quá khứ.
  static Future<void> scheduleStageReminder({
    required String projectId,
    required String projectName,
    required ProjectStage stage,
  }) async {
    if (stage.status == ProjectStageStatus.completed ||
        stage.plannedEndDate == null) {
      await cancelStageReminder(stage.id);
      return;
    }

    await NoteNotificationService.ensureInitialized();
    if (!NoteNotificationService.isReady) return;

    final notifyAt = _reminderTimeFor(stage.plannedEndDate!);
    if (notifyAt.isBefore(DateTime.now())) {
      await cancelStageReminder(stage.id);
      return;
    }

    final id = _notificationIdFor(stage.id);
    final scheduledDate = tz.TZDateTime.from(notifyAt, tz.local);

    try {
      await NoteNotificationService.sharedPlugin.zonedSchedule(
        id: id,
        scheduledDate: scheduledDate,
        title: 'Sắp đến hạn: ${stage.stageName}',
        body: '$projectName — hạn kế hoạch vào ngày mai.',
        payload: '$payloadPrefix$projectId|${stage.id}',
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: NotificationDetails(
          android: const AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(''),
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Không thể lên lịch nhắc hạn cho giai đoạn #${stage.id}',
        name: 'ProjectNotificationService',
        error: error,
        stackTrace: stackTrace,
      );
      if (kDebugMode) rethrow;
    }
  }

  static Future<void> cancelStageReminder(String stageId) async {
    await NoteNotificationService.ensureInitialized();
    if (!NoteNotificationService.isReady) return;
    try {
      await NoteNotificationService.sharedPlugin.cancel(
        id: _notificationIdFor(stageId),
      );
    } catch (error) {
      developer.log(
        'Không thể huỷ nhắc hạn cho giai đoạn #$stageId',
        name: 'ProjectNotificationService',
        error: error,
      );
    }
  }
}
