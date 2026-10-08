import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../engine/grain_analyzer.dart';
import '../engine/image_decode.dart';
import '../engine/tray_layout.dart';

/// Chạy giải mã + phân tích ảnh trong isolate riêng để giao diện không bị
/// đứng, có báo tiến trình (NFR-01).
class GrainAnalysisRunner {
  const GrainAnalysisRunner();

  Future<GrainImageAnalysis> analyzeFile(
    String path, {
    required TrayLayout layout,
    int imageIndex = 0,
    double? minPixelsPerMm,
    AnalysisProgress? onProgress,
  }) async {
    final port = ReceivePort();
    final errors = ReceivePort();
    final completer = Completer<GrainImageAnalysis>();
    final isolate = await Isolate.spawn(
      _entry,
      _Job(port.sendPort, path, layout, imageIndex, minPixelsPerMm),
      onError: errors.sendPort,
    );
    final errorSub = errors.listen((message) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception(message is List ? message.first : message),
        );
      }
    });
    final sub = port.listen((message) {
      if (message is _Progress) {
        onProgress?.call(message.fraction, message.stage);
      } else if (message is GrainImageAnalysis) {
        if (!completer.isCompleted) completer.complete(message);
      } else if (message is _Failure) {
        if (!completer.isCompleted) {
          completer.completeError(FormatException(message.message));
        }
      }
    });
    try {
      return await completer.future;
    } finally {
      await sub.cancel();
      await errorSub.cancel();
      port.close();
      errors.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }

  static void _entry(_Job job) {
    try {
      void onProgress(double f, String s) => job.port.send(_Progress(f, s));
      onProgress(0, 'Đọc ảnh');
      final raster = decodeImageToRaster(File(job.path).readAsBytesSync());
      GrainImageAnalysis run(TrayLayout layout) =>
          GrainAnalyzer(layout: layout).analyze(
            raster,
            imageIndex: job.imageIndex,
            minPixelsPerMm: job.minPixelsPerMm,
            onProgress: onProgress,
          );
      var result = run(job.layout);
      // Chọn tấm nền in mà ảnh không có mốc: có thể đang chụp khay thật
      // (quên đổi ô "Khay chuẩn") — thử nhận khay theo viền.
      if (!result.markersFound && job.layout.hasMarkers) {
        final plain = findPlainTray(raster);
        if (plain != null) result = run(plain);
      }
      job.port.send(result);
    } on FormatException {
      job.port.send(
        const _Failure(
          'Không đọc được ảnh. Hãy chụp lại bằng nút "Chụp ảnh" hoặc chọn '
          'ảnh định dạng JPG/PNG.',
        ),
      );
    } catch (error) {
      job.port.send(_Failure('Lỗi khi phân tích ảnh: $error'));
    }
  }
}

class _Job {
  const _Job(
    this.port,
    this.path,
    this.layout,
    this.imageIndex,
    this.minPixelsPerMm,
  );
  final SendPort port;
  final String path;
  final TrayLayout layout;
  final int imageIndex;
  final double? minPixelsPerMm;
}

class _Progress {
  const _Progress(this.fraction, this.stage);
  final double fraction;
  final String stage;
}

class _Failure {
  const _Failure(this.message);
  final String message;
}
