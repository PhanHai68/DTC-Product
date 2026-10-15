import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Một lỗi đã ghi nhận.
class AppErrorEntry {
  final DateTime time;

  /// `flutter` (lỗi khi vẽ giao diện) hoặc `async` (lỗi trong tác vụ nền).
  final String source;
  final String message;
  final String stack;

  const AppErrorEntry({
    required this.time,
    required this.source,
    required this.message,
    required this.stack,
  });

  factory AppErrorEntry.fromJson(Map<String, dynamic> json) => AppErrorEntry(
    time: DateTime.parse(json['time'] as String),
    source: json['source'] as String,
    message: json['message'] as String,
    stack: json['stack'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'source': source,
    'message': message,
    'stack': stack,
  };
}

/// Nhật ký lỗi lưu trên máy (chưa dùng dịch vụ báo crash bên ngoài): bắt lỗi
/// giao diện và lỗi trong `Future` chưa được xử lý, giữ [maxEntries] lỗi gần
/// nhất để người dùng gửi lại từ Cài đặt → Nhật ký lỗi.
class AppErrorLog extends ChangeNotifier {
  AppErrorLog._();

  static final instance = AppErrorLog._();

  static const maxEntries = 50;
  static const _prefsKey = 'app_error_log';
  static const _maxMessageLength = 600;
  static const _maxStackLines = 15;

  /// Gắn vào [MaterialApp.scaffoldMessengerKey] để báo lỗi cho người dùng.
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  SharedPreferences? _prefs;
  List<AppErrorEntry> _entries = [];
  DateTime? _lastNotice;

  /// Mới nhất trước.
  List<AppErrorEntry> get entries => List.unmodifiable(_entries.reversed);

  /// Đọc nhật ký đã lưu và bắt lỗi toàn cục. Gọi một lần trong `main()`.
  void install(SharedPreferences prefs) {
    _prefs = prefs;
    _entries = _load(prefs);

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      record(details.exception, details.stack, source: 'flutter');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Lỗi chưa được xử lý: $error\n$stack');
      record(error, stack, source: 'async');
      _notifyUser();
      // Đã xử lý: không để lỗi làm dừng app.
      return true;
    };
  }

  static List<AppErrorEntry> _load(SharedPreferences prefs) {
    try {
      return [
        for (final raw in prefs.getStringList(_prefsKey) ?? const <String>[])
          AppErrorEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>),
      ];
    } catch (_) {
      // Nhật ký hỏng thì bỏ, không để chính nó gây lỗi.
      return [];
    }
  }

  void record(Object error, StackTrace? stack, {required String source}) {
    final message = error.toString();
    _entries.add(
      AppErrorEntry(
        time: DateTime.now(),
        source: source,
        message: message.length > _maxMessageLength
            ? '${message.substring(0, _maxMessageLength)}…'
            : message,
        stack: (stack?.toString() ?? '')
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .take(_maxStackLines)
            .join('\n'),
      ),
    );
    if (_entries.length > maxEntries) {
      _entries = _entries.sublist(_entries.length - maxEntries);
    }
    _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _entries = [];
    notifyListeners();
    await _prefs?.remove(_prefsKey);
  }

  void _save() {
    _prefs?.setStringList(_prefsKey, [
      for (final entry in _entries) jsonEncode(entry.toJson()),
    ]);
  }

  /// Báo ngắn cho người dùng, tối đa một lần mỗi 5 giây.
  void _notifyUser() {
    final now = DateTime.now();
    if (_lastNotice != null &&
        now.difference(_lastNotice!) < const Duration(seconds: 5)) {
      return;
    }
    _lastNotice = now;
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text(
          'Đã xảy ra lỗi. Nếu lặp lại, vào Cài đặt → Nhật ký lỗi để gửi cho DTC.',
        ),
      ),
    );
  }

  /// Nội dung để sao chép hoặc chia sẻ.
  String exportText({String? appVersion}) {
    final buffer = StringBuffer('Nhật ký lỗi DTC Product');
    if (appVersion != null) buffer.write(' — phiên bản $appVersion');
    buffer.writeln();
    buffer.writeln(
      'Nền tảng: ${kIsWeb ? 'web' : defaultTargetPlatform.name} · '
      '${entries.length} lỗi',
    );
    for (final entry in entries) {
      buffer
        ..writeln()
        ..writeln('[${entry.time.toIso8601String()}] (${entry.source})')
        ..writeln(entry.message);
      if (entry.stack.isNotEmpty) buffer.writeln(entry.stack);
    }
    return buffer.toString();
  }
}
