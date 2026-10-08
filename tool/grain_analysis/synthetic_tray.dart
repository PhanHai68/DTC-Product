import 'dart:math' as math;

import 'package:dtc_product/features/grain_analysis/engine/homography.dart';
import 'package:dtc_product/features/grain_analysis/engine/image_decode.dart';
import 'package:dtc_product/features/grain_analysis/engine/raster.dart';
import 'package:dtc_product/features/grain_analysis/engine/rectifier.dart';
import 'package:dtc_product/features/grain_analysis/engine/tray_layout.dart';
import 'package:image/image.dart' as img;

/// Khay nhỏ để test chạy nhanh (cùng cấu trúc với khay A4/A3 thật).
const testLayout = TrayLayout(
  id: 'test',
  name: 'Test',
  pageWidthMm: 100,
  pageHeightMm: 140,
  marginMm: 5,
  markerSizeMm: 12,
  gapMm: 4,
  roiInsetMm: 4,
);

/// Một hạt giả lập: elip tâm (x, y) mm, dài/rộng mm, góc radian.
class SynthGrain {
  const SynthGrain(this.x, this.y, this.length, this.width, this.angle);
  final double x;
  final double y;
  final double length;
  final double width;
  final double angle;
}

/// Vẽ ảnh chụp khay [layout] ở [ppm] pixel/mm, có viền bàn [tablePx] quanh
/// tờ giấy. [drawMarkers] = false giả lập khay không có mốc.
img.Image renderTray({
  TrayLayout layout = testLayout,
  required List<SynthGrain> grains,
  double ppm = 12,
  int tablePx = 40,
  bool drawMarkers = true,
  List<({double x, double y, double r})> dust = const [],
  int grainR = 236,
  int grainG = 232,
  int grainB = 218,
  ({int r, int g, int b}) background = (r: 22, g: 42, b: 112),
}) {
  final w = (layout.pageWidthMm * ppm).round() + 2 * tablePx;
  final h = (layout.pageHeightMm * ppm).round() + 2 * tablePx;
  final image = img.Image(width: w, height: h);
  int px(double mm) => (mm * ppm).round() + tablePx;

  img.fill(image, color: img.ColorRgb8(120, 110, 100)); // mặt bàn
  img.fillRect(
    image,
    x1: tablePx,
    y1: tablePx,
    x2: w - tablePx - 1,
    y2: h - tablePx - 1,
    color: img.ColorRgb8(246, 246, 244),
  );
  final bg = layout.backgroundRect;
  img.fillRect(
    image,
    x1: px(bg.left),
    y1: px(bg.top),
    x2: px(bg.right) - 1,
    y2: px(bg.bottom) - 1,
    color: img.ColorRgb8(background.r, background.g, background.b),
  );
  if (drawMarkers) {
    for (final r in layout.markerRects) {
      img.fillRect(
        image,
        x1: px(r.left),
        y1: px(r.top),
        x2: px(r.right) - 1,
        y2: px(r.bottom) - 1,
        color: img.ColorRgb8(15, 15, 15),
      );
      final hole = layout.markerHoleMm / 2;
      img.fillRect(
        image,
        x1: px(r.centerX - hole),
        y1: px(r.centerY - hole),
        x2: px(r.centerX + hole) - 1,
        y2: px(r.centerY + hole) - 1,
        color: img.ColorRgb8(246, 246, 244),
      );
    }
  }
  for (final g in grains) {
    final pts = <img.Point>[];
    for (var k = 0; k < 48; k++) {
      final t = 2 * math.pi * k / 48;
      final ex = g.length / 2 * math.cos(t), ey = g.width / 2 * math.sin(t);
      final x = g.x + ex * math.cos(g.angle) - ey * math.sin(g.angle);
      final y = g.y + ex * math.sin(g.angle) + ey * math.cos(g.angle);
      pts.add(img.Point(x * ppm + tablePx, y * ppm + tablePx));
    }
    img.fillPolygon(
      image,
      vertices: pts,
      color: img.ColorRgb8(grainR, grainG, grainB),
    );
  }
  for (final d in dust) {
    img.fillCircle(
      image,
      x: px(d.x),
      y: px(d.y),
      radius: math.max(1, (d.r * ppm).round()),
      color: img.ColorRgb8(grainR, grainG, grainB),
    );
  }
  return image;
}

/// Hạt rải đều trên lưới trong vùng rải mẫu, lệch ngẫu nhiên, không chạm nhau.
List<SynthGrain> gridGrains({
  TrayLayout layout = testLayout,
  required int count,
  double length = 6.5,
  double width = 2.2,
  int seed = 1,
}) {
  final rnd = math.Random(seed);
  final roi = layout.roiRect.inflate(-4);
  const cell = 9.0;
  final cols = (roi.width / cell).floor();
  final out = <SynthGrain>[];
  for (var i = 0; i < count; i++) {
    final cx = roi.left + cell / 2 + (i % cols) * cell;
    final cy = roi.top + cell / 2 + (i ~/ cols) * cell;
    out.add(
      SynthGrain(
        cx + (rnd.nextDouble() - 0.5) * 1.2,
        cy + (rnd.nextDouble() - 0.5) * 1.2,
        length * (0.92 + rnd.nextDouble() * 0.16),
        width * (0.92 + rnd.nextDouble() * 0.16),
        rnd.nextDouble() * math.pi,
      ),
    );
  }
  return out;
}

/// Giả lập chụp nghiêng: ép cạnh trên của ảnh còn [topScale] bề rộng.
img.Image perspective(img.Image source, double topScale) {
  final raster = rasterFromImage(source);
  final w = source.width.toDouble(), h = source.height.toDouble();
  final inset = w * (1 - topScale) / 2;
  // Ảnh đích (camera) → ảnh nguồn (tờ giấy phẳng).
  final cameraToPage = Homography.fromPoints(
    [
      [inset, 0],
      [w - inset, 0],
      [w, h],
      [0, h],
    ],
    [
      [0, 0],
      [w, 0],
      [w, h],
      [0, h],
    ],
  )!;
  final warped = warpPerspective(
    raster,
    cameraToPage,
    source.width,
    source.height,
  );
  return toImage(warped);
}

img.Image toImage(RgbRaster raster) => img.Image.fromBytes(
  width: raster.width,
  height: raster.height,
  bytes: raster.data.buffer,
  numChannels: 3,
);
