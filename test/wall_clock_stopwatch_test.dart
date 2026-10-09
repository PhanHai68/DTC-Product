import 'package:dtc_product/core/utils/wall_clock_stopwatch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  WallClockStopwatch create() => WallClockStopwatch(clock: () => now);

  setUp(() => now = DateTime(2026, 10, 9, 8));

  test('tính theo giờ thực: tắt màn hình 10 phút vẫn cộng đủ', () {
    final stopwatch = create()..start();
    // Không có tick nào trong lúc máy ngủ — chỉ đồng hồ thực trôi.
    now = now.add(const Duration(minutes: 10, seconds: 5));

    expect(stopwatch.isRunning, isTrue);
    expect(stopwatch.elapsed, const Duration(minutes: 10, seconds: 5));
  });

  test('tạm dừng rồi tiếp tục cộng dồn, không tính lúc dừng', () {
    final stopwatch = create()..start();
    now = now.add(const Duration(seconds: 30));
    stopwatch.pause();
    now = now.add(const Duration(minutes: 5)); // đang dừng
    expect(stopwatch.elapsed, const Duration(seconds: 30));

    stopwatch.start();
    now = now.add(const Duration(seconds: 15));
    expect(stopwatch.elapsed, const Duration(seconds: 45));
  });

  test('bấm bắt đầu 2 lần không làm mất thời gian đã chạy', () {
    final stopwatch = create()..start();
    now = now.add(const Duration(seconds: 20));
    stopwatch.start();
    now = now.add(const Duration(seconds: 10));
    expect(stopwatch.elapsed, const Duration(seconds: 30));
  });

  test('khôi phục sau khi app bị đóng: đồng hồ đang chạy vẫn tính tiếp', () {
    final stopwatch = create()..start();
    now = now.add(const Duration(seconds: 40));
    stopwatch.pause();
    stopwatch.start();
    final saved = stopwatch.toJson();

    // App bị hệ điều hành đóng, 2 phút sau mở lại.
    now = now.add(const Duration(minutes: 2));
    final restored = create()..restore(saved);

    expect(restored.isRunning, isTrue);
    expect(restored.elapsed, const Duration(minutes: 2, seconds: 40));
  });

  test('khôi phục đồng hồ đang dừng giữ nguyên thời gian', () {
    final stopwatch = create()..start();
    now = now.add(const Duration(seconds: 75));
    stopwatch.pause();
    final restored = create()..restore(stopwatch.toJson());
    now = now.add(const Duration(hours: 1));

    expect(restored.isRunning, isFalse);
    expect(restored.elapsed, const Duration(seconds: 75));
  });

  test('đặt lại về 0 và giờ máy bị chỉnh lùi không ra số âm', () {
    final stopwatch = create()..start();
    now = now.subtract(const Duration(minutes: 1));
    expect(stopwatch.elapsed, Duration.zero);

    stopwatch.reset();
    expect(stopwatch.isRunning, isFalse);
    expect(stopwatch.elapsed, Duration.zero);
  });
}
