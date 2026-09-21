// Local notification service cho chức năng "Ghi chú & Nhắc hẹn".
//
// - Notification ID luôn trùng với id của ghi chú trong SQLite nên 1 ghi chú
//   chỉ bao giờ có tối đa 1 notification đang chờ, tránh trùng lặp.
// - Dùng AndroidScheduleMode.inexactAllowWhileIdle: đủ chính xác cho nhắc
//   việc cá nhân và không cần xin quyền "Báo thức & lời nhắc" đặc biệt trên
//   Android 12+ (SCHEDULE_EXACT_ALARM), giảm ma sát khi dùng lần đầu.
// - Giờ hẹn được hiểu theo múi giờ Việt Nam (Asia/Ho_Chi_Minh) vì app chỉ
//   phục vụ người dùng trong nước (locale vi_VN duy nhất).
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../routes/app_routes.dart';

abstract final class NoteNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'note_reminders';
  static const _channelName = 'Nhắc hẹn ghi chú';
  static const _channelDescription =
      'Thông báo nhắc hẹn từ chức năng Ghi chú & Nhắc hẹn';

  static bool _initialized = false;

  /// `false` khi plugin thông báo không khởi tạo được (ví dụ nền tảng không
  /// hỗ trợ, hoặc đang chạy trong môi trường test không có platform channel).
  /// Trong trường hợp đó, [schedule]/[cancel] sẽ tự bỏ qua thay vì làm crash
  /// toàn bộ chức năng Ghi chú & Nhắc hẹn — nhắc hẹn chỉ đơn giản là không
  /// hoạt động, còn ghi chú thường vẫn dùng được bình thường.
  static bool _pluginReady = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    } catch (error) {
      developer.log(
        'Không thể đặt múi giờ Asia/Ho_Chi_Minh, dùng mặc định.',
        name: 'NoteNotificationService',
        error: error,
      );
    }

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const settings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
      _pluginReady = true;
    } catch (error, stackTrace) {
      developer.log(
        'Không thể khởi tạo plugin thông báo cục bộ.',
        name: 'NoteNotificationService',
        error: error,
        stackTrace: stackTrace,
      );
      _pluginReady = false;
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    final noteId = int.tryParse(response.payload ?? '');
    if (noteId == null) return;
    appRouter.push('/notes/edit', extra: {'noteId': noteId});
  }

  /// Yêu cầu quyền hiển thị thông báo (Android 13+). Trả về `true` nếu được
  /// cấp quyền hoặc không cần xin (Android cũ hơn).
  static Future<bool> requestPermission() async {
    if (!_initialized) await init();
    if (!_pluginReady) return false;
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return true;
    final granted = await androidPlugin.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Lên lịch (hoặc thay thế lịch cũ) thông báo cho 1 ghi chú.
  /// Không làm gì nếu ghi chú không bật nhắc hẹn, giờ nhắc đã ở quá khứ, hoặc
  /// plugin thông báo không khởi tạo được trên thiết bị này.
  static Future<void> schedule({
    required int noteId,
    required DateTime notifyAt,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    if (!_pluginReady) return;
    if (notifyAt.isBefore(DateTime.now())) {
      await cancel(noteId);
      return;
    }

    final scheduledDate = tz.TZDateTime.from(notifyAt, tz.local);

    try {
      await _plugin.zonedSchedule(
        id: noteId,
        scheduledDate: scheduledDate,
        title: title,
        body: body.isEmpty ? ' ' : body,
        payload: noteId.toString(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(''),
            largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Không thể lên lịch nhắc hẹn cho ghi chú #$noteId',
        name: 'NoteNotificationService',
        error: error,
        stackTrace: stackTrace,
      );
      if (kDebugMode) rethrow;
    }
  }

  static Future<void> cancel(int noteId) async {
    if (!_initialized) await init();
    if (!_pluginReady) return;
    try {
      await _plugin.cancel(id: noteId);
    } catch (error) {
      developer.log(
        'Không thể huỷ nhắc hẹn cho ghi chú #$noteId',
        name: 'NoteNotificationService',
        error: error,
      );
    }
  }
}
