// Local notification service — plugin nền dùng CHUNG cho toàn app (Ghi chú &
// Nhắc hẹn, và Hạn giai đoạn dự án ở project_notification_service.dart).
// Dùng chung 1 FlutterLocalNotificationsPlugin/1 lần initialize() vì plugin
// này chỉ cho đăng ký MỘT callback xử lý khi bấm vào thông báo — nếu mỗi
// tính năng tự tạo plugin/instance riêng, initialize() gọi sau sẽ ghi đè mất
// callback của tính năng gọi trước. _onNotificationTapped bên dưới phân loại
// theo tiền tố payload để điều hướng đúng tính năng.
//
// - Notification ID của ghi chú luôn trùng với id trong SQLite nên 1 ghi chú
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

import '../features/projects/services/project_notification_service.dart';
import '../routes/app_routes.dart';

abstract final class NoteNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'note_reminders';
  static const _channelName = 'Nhắc hẹn ghi chú';
  static const _channelDescription =
      'Thông báo nhắc hẹn từ chức năng Ghi chú & Nhắc hẹn';

  /// Cho phép các service khác (VD: ProjectNotificationService) dùng chung
  /// plugin/trạng thái khởi tạo thay vì tự tạo instance riêng.
  static FlutterLocalNotificationsPlugin get sharedPlugin => _plugin;
  static bool get isReady => _pluginReady;
  static Future<void> ensureInitialized() => init();

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
      // Không xin quyền ngay lúc khởi tạo — chỉ xin khi người dùng thật sự
      // bật "Nhắc tôi" cho 1 ghi chú (xem [requestPermission]), giống hành vi
      // trên Android (permission cũng được xin riêng, không phải lúc init).
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

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
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          ProjectNotificationService.channelId,
          ProjectNotificationService.channelName,
          description: ProjectNotificationService.channelDescription,
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
    final payload = response.payload;
    if (payload == null) return;
    if (payload.startsWith(ProjectNotificationService.payloadPrefix)) {
      ProjectNotificationService.handleTap(
        payload.substring(ProjectNotificationService.payloadPrefix.length),
      );
      return;
    }
    final noteId = int.tryParse(payload);
    if (noteId == null) return;
    appRouter.push('/notes/edit', extra: {'noteId': noteId});
  }

  /// Yêu cầu quyền hiển thị thông báo — Android 13+ (POST_NOTIFICATIONS) và
  /// iOS (alert/badge/sound). Trả về `true` nếu được cấp quyền hoặc không
  /// cần xin (Android cũ hơn, hoặc nền tảng không yêu cầu xin quyền).
  static Future<bool> requestPermission() async {
    if (!_initialized) await init();
    if (!_pluginReady) return false;

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? true;
    }

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? true;
    }

    return true;
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
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
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
