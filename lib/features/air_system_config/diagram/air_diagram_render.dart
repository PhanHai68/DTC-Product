import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'air_diagram.dart';

/// Ảnh thiết bị của sơ đồ: nạp một lần, dùng chung cho màn hình, PNG, PDF
/// (ảnh đã giải mã) và SVG (byte PNG gốc).
abstract final class AirDiagramImages {
  static final _images = <String, ui.Image>{};
  static final _bytes = <String, Uint8List>{};
  static Future<void>? _loading;

  static bool get isLoaded => _images.length == AirDiagramAssets.all.length;

  static ui.Image? image(String asset) => _images[asset];

  static Future<void> load([AssetBundle? bundle]) =>
      _loading ??= _load(bundle ?? rootBundle).catchError((Object error) {
        _loading = null; // cho phép thử lại lần sau
        throw error;
      });

  /// Byte PNG gốc theo asset (nhúng vào SVG).
  static Future<Map<String, Uint8List>> bytes() async {
    await load();
    return Map.unmodifiable(_bytes);
  }

  static Future<void> _load(AssetBundle bundle) async {
    for (final asset in AirDiagramAssets.all) {
      final data = Uint8List.sublistView(await bundle.load(asset));
      final codec = await ui.instantiateImageCodec(data);
      _bytes[asset] = data;
      _images[asset] = (await codec.getNextFrame()).image;
    }
  }
}

/// Vẽ [AirDiagram] lên Canvas (màn hình, PNG).
class AirDiagramPainter extends CustomPainter {
  AirDiagramPainter(this.diagram) : _imagesLoaded = AirDiagramImages.isLoaded;
  final AirDiagram diagram;
  final bool _imagesLoaded;

  @override
  void paint(Canvas canvas, Size size) => paintAirDiagram(canvas, diagram);

  @override
  bool shouldRepaint(AirDiagramPainter old) =>
      old.diagram != diagram || old._imagesLoaded != _imagesLoaded;
}

void paintAirDiagram(Canvas canvas, AirDiagram diagram) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, diagram.width, diagram.height),
    Paint()..color = Colors.white,
  );
  for (final shape in diagram.shapes) {
    switch (shape) {
      case DRect():
        final rrect = RRect.fromRectAndRadius(
          shape.rect,
          Radius.circular(shape.radius),
        );
        if (shape.fill != null) {
          canvas.drawRRect(rrect, Paint()..color = shape.fill!);
        }
        if (shape.stroke != null) {
          final paint = _stroke(shape.stroke!, shape.strokeWidth);
          final path = Path()..addRRect(rrect);
          canvas.drawPath(shape.dashed ? _dash(path) : path, paint);
        }
      case DCircle():
        if (shape.fill != null) {
          canvas.drawCircle(
            shape.center,
            shape.radius,
            Paint()..color = shape.fill!,
          );
        }
        if (shape.stroke != null) {
          canvas.drawCircle(
            shape.center,
            shape.radius,
            _stroke(shape.stroke!, shape.strokeWidth),
          );
        }
      case DPath():
        final path = Path()..addPolygon(shape.points, shape.closed);
        if (shape.fill != null) {
          canvas.drawPath(path, Paint()..color = shape.fill!);
        }
        if (shape.stroke != null) {
          canvas.drawPath(
            shape.dashed ? _dash(path) : path,
            _stroke(shape.stroke!, shape.strokeWidth)
              ..strokeCap = StrokeCap.butt
              ..strokeJoin = StrokeJoin.round,
          );
        }
      case DText():
        final painter = TextPainter(
          text: TextSpan(
            text: shape.text,
            style: TextStyle(
              fontFamily: 'AirDiagram',
              fontSize: shape.size,
              color: shape.color,
              fontWeight: shape.bold ? FontWeight.bold : FontWeight.normal,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final baseline = painter.computeDistanceToActualBaseline(
          TextBaseline.alphabetic,
        );
        final dx = switch (shape.anchor) {
          DAnchor.start => 0.0,
          DAnchor.middle => painter.width / 2,
          DAnchor.end => painter.width,
        };
        painter.paint(
          canvas,
          Offset(shape.baseline.dx - dx, shape.baseline.dy - baseline),
        );
      case DImage():
        final image = AirDiagramImages.image(shape.asset);
        if (image == null) {
          // Ảnh chưa nạp xong: ô xám tạm.
          canvas.drawRRect(
            RRect.fromRectAndRadius(shape.rect, const Radius.circular(4)),
            Paint()..color = const Color(0xFFE2E8F0),
          );
        } else {
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(
              0,
              0,
              image.width.toDouble(),
              image.height.toDouble(),
            ),
            shape.rect,
            Paint()
              ..filterQuality = FilterQuality.high
              ..isAntiAlias = true,
          );
        }
    }
  }
}

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width;

Path _dash(Path source, {double dash = 7, double gap = 5}) {
  final out = Path();
  for (final metric in source.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      out.addPath(
        metric.extractPath(d, math.min(d + dash, metric.length)),
        Offset.zero,
      );
      d += dash + gap;
    }
  }
  return out;
}

/// Ảnh PNG của sơ đồ ở tỉ lệ [scale] (≥ 2 theo yêu cầu).
Future<Uint8List> airDiagramPng(AirDiagram diagram, {double scale = 2}) async {
  await AirDiagramImages.load();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(scale);
  paintAirDiagram(canvas, diagram);
  final image = await recorder.endRecording().toImage(
    (diagram.width * scale).ceil(),
    (diagram.height * scale).ceil(),
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
