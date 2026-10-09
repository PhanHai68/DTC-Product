/// Đồng hồ bấm giờ tính theo giờ thực (thời điểm bắt đầu), không đếm tick.
///
/// `Stopwatch` của Dart dùng đồng hồ monotonic — trên điện thoại đồng hồ này
/// ngừng chạy khi máy ngủ (tắt màn hình) và app bị tạm dừng khi chạy nền, nên
/// thời gian đo bị hụt. Ở đây thời gian trôi = tích luỹ các lần chạy trước +
/// (bây giờ − lúc bấm chạy), nên tắt màn hình/chuyển app vẫn đúng. Trạng thái
/// lưu được ra JSON để khôi phục cả khi hệ điều hành đóng hẳn app.
class WallClockStopwatch {
  WallClockStopwatch({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  Duration _accumulated = Duration.zero;
  DateTime? _runningSince;

  bool get isRunning => _runningSince != null;

  Duration get elapsed {
    final since = _runningSince;
    if (since == null) return _accumulated;
    final running = _clock().difference(since);
    // Giờ máy bị chỉnh lùi → không để thời gian âm.
    return _accumulated + (running.isNegative ? Duration.zero : running);
  }

  void start() {
    _runningSince ??= _clock();
  }

  void pause() {
    if (_runningSince == null) return;
    _accumulated = elapsed;
    _runningSince = null;
  }

  void reset() {
    _accumulated = Duration.zero;
    _runningSince = null;
  }

  Map<String, Object?> toJson() => {
    'accumulatedMs': _accumulated.inMilliseconds,
    'runningSinceMs': _runningSince?.millisecondsSinceEpoch,
  };

  void restore(Map<String, Object?> json) {
    final accumulated = json['accumulatedMs'];
    final since = json['runningSinceMs'];
    _accumulated = Duration(
      milliseconds: accumulated is int && accumulated > 0 ? accumulated : 0,
    );
    _runningSince = since is int
        ? DateTime.fromMillisecondsSinceEpoch(since)
        : null;
  }
}
