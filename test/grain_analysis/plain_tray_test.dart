import 'dart:math' as math;

import 'package:dtc_product/features/grain_analysis/engine/grain_analyzer.dart';
import 'package:dtc_product/features/grain_analysis/engine/image_decode.dart';
import 'package:dtc_product/features/grain_analysis/engine/tray_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../tool/grain_analysis/synthetic_tray.dart';

const layout = TrayLayout.anysort;
const analyzer = GrainAnalyzer(layout: layout);

/// Số pixel / mm của mặt viền khay trên ảnh giả lập, và lề bàn quanh khay.
const rimPpm = 11.0;
const tablePx = 60;

/// Ảnh giả lập máy chụp thẳng xuống khay AnySort trên mặt bàn sẫm: viền
/// cao hơn đáy [TrayLayout.rimHeightMm] nên đáy (và hạt) trông nhỏ hơn viền
/// theo đúng mô hình máy ảnh lỗ kim mà app dùng. [rotated] = khay xoay 180°
/// (logo ở đầu kia). [liner] = lót tấm nền xanh đậm che logo, rải gạo
/// trắng. Tọa độ hạt tính bằng mm trên đáy khay, khổ đứng.
({img.Image image, double floorPpm}) renderPlainTray({
  required List<SynthGrain> grains,
  bool rotated = false,
  bool liner = false,
  bool black = false,
  List<({int x1, int y1, int x2, int y2})> brightObjects = const [],
}) {
  final w = (layout.pageWidthMm * rimPpm).round() + 2 * tablePx;
  final h = (layout.pageHeightMm * rimPpm).round() + 2 * tablePx;
  final cx = w / 2, cy = h / 2;
  final focal = 0.75 * math.max(w, h);
  final distance = focal / rimPpm;
  final s = distance / (distance + layout.rimHeightMm);
  final image = img.Image(width: w, height: h);
  // Khay đen đặt trên bàn xanh sáng hơn khay; khay trắng trên bàn sẫm.
  img.fill(
    image,
    color: black ? img.ColorRgb8(125, 140, 115) : img.ColorRgb8(46, 60, 46),
  );
  for (final o in brightObjects) {
    img.fillRect(
      image,
      x1: o.x1,
      y1: o.y1,
      x2: o.x2,
      y2: o.y2,
      color: img.ColorRgb8(225, 225, 222),
    );
  }

  const wMm = 150.0, hMm = 210.0;
  // Tô từng pixel: đổi tâm pixel về mm trên mặt viền (onRim) hoặc mặt đáy
  // rồi hỏi [inside].
  void paint(
    bool Function(double x, double y) inside,
    img.Color color, {
    bool onRim = false,
    (double, double, double, double)? box,
  }) {
    // [box] = (trái, trên, phải, dưới) mm trên đáy: chỉ tô trong khung đó.
    var (x0, y0, x1, y1) = (0, 0, w, h);
    if (box != null) {
      final xs = [box.$1, box.$3], ys = [box.$2, box.$4];
      if (rotated) {
        xs.setAll(0, [wMm - box.$3, wMm - box.$1]);
        ys.setAll(0, [hMm - box.$4, hMm - box.$2]);
      }
      int toPx(double mm, double c) =>
          (c + s * (tablePx + mm * rimPpm - c)).floor();
      x0 = math.max(0, toPx(xs[0], cx));
      y0 = math.max(0, toPx(ys[0], cy));
      x1 = math.min(w, toPx(xs[1], cx) + 2);
      y1 = math.min(h, toPx(ys[1], cy) + 2);
    }
    for (var py = y0; py < y1; py++) {
      for (var px = x0; px < x1; px++) {
        var x = px + 0.5, y = py + 0.5;
        if (!onRim) {
          x = cx + (x - cx) / s;
          y = cy + (y - cy) / s;
        }
        x = (x - tablePx) / rimPpm;
        y = (y - tablePx) / rimPpm;
        if (rotated && !onRim) {
          x = wMm - x;
          y = hMm - y;
        }
        if (inside(x, y)) image.setPixel(px, py, color);
      }
    }
  }

  // Logo in theo đúng hình logo mẫu của khay (ô 2 mm, '#' là nét).
  final zone = layout.excludedRects.first;
  bool logo(double x, double y) {
    final i = ((x - zone.left) / TrayLayout.logoCellMm).floor();
    final j = ((y - zone.top) / TrayLayout.logoCellMm).floor();
    final rows = layout.logoTemplate;
    if (j < 0 || j >= rows.length || i < 0 || i >= rows[j].length) return false;
    return rows[j][i] == '#';
  }

  final gray = black ? (172, 174, 176) : (140, 142, 145);
  paint(
    (x, y) => x >= 0 && x <= wMm && y >= 0 && y <= hMm,
    black ? img.ColorRgb8(76, 76, 80) : img.ColorRgb8(250, 250, 248),
    onRim: true,
  );
  paint(
    (x, y) => true,
    black ? img.ColorRgb8(32, 32, 34) : img.ColorRgb8(240, 240, 236),
    box: (2, 2, wMm - 2, hMm - 2),
  );
  if (liner) {
    paint(
      (x, y) => true,
      img.ColorRgb8(22, 42, 112),
      box: (4, 4, wMm - 4, hMm - 4),
    );
  }
  // Logo in xám (khay đen: xám sáng).
  if (!liner) {
    paint(
      logo,
      img.ColorRgb8(gray.$1, gray.$2, gray.$3),
      box: (zone.left, zone.top, zone.right, zone.bottom),
    );
  }
  for (final g in grains) {
    final half = g.length / 2 + 1;
    paint(
      (x, y) {
        final dx = x - g.x, dy = y - g.y;
        final u = dx * math.cos(g.angle) + dy * math.sin(g.angle);
        final v = -dx * math.sin(g.angle) + dy * math.cos(g.angle);
        return math.pow(u / (g.length / 2), 2) +
                math.pow(v / (g.width / 2), 2) <=
            1;
      },
      liner || black
          ? img.ColorRgb8(236, 232, 218)
          : img.ColorRgb8(176, 128, 74),
      box: (g.x - half, g.y - half, g.x + half, g.y + half),
    );
  }
  return (image: image, floorPpm: rimPpm * s);
}

/// Hạt trên lưới trong vùng phân tích, tránh vùng logo ở cả hai đầu.
List<SynthGrain> plainGrains(int count, {int seed = 3}) {
  final rnd = math.Random(seed);
  final out = <SynthGrain>[];
  bool nearLogo(double x, double y) =>
      (x < 56 && y < 77) || (x > 94 && y > 133);
  for (var y = 14.0; y < 200 && out.length < count; y += 12) {
    for (var x = 14.0; x < 140 && out.length < count; x += 12) {
      if (nearLogo(x, y)) continue;
      out.add(
        SynthGrain(
          x + (rnd.nextDouble() - 0.5),
          y + (rnd.nextDouble() - 0.5),
          6.5,
          2.4,
          rnd.nextDouble() * math.pi,
        ),
      );
    }
  }
  return out;
}

void main() {
  test('nhận khay AnySort theo viền, đếm đúng, bỏ logo, đo mm trên đáy', () {
    final tray = renderPlainTray(grains: plainGrains(60));
    final r = analyzer.analyze(rasterFromImage(tray.image));

    expect(r.markersFound, isTrue);
    expect(r.totalCount, 60, reason: '${r.metrics}');
    expect(r.pixelsPerMm, closeTo(tray.floorPpm, 0.05));
    expect(r.tiltDegrees, lessThan(2));
    expect(r.excludedRegions, hasLength(1));
    expect(r.metrics['excludedBothEnds'], isNull);
    for (final g in r.grains) {
      expect(g.lengthMm, closeTo(6.5, 0.4));
      expect(g.widthMm, closeTo(2.4, 0.4));
    }
  });

  test('khay xoay 180°: tự nhận ra logo ở đầu kia', () {
    final tray = renderPlainTray(grains: plainGrains(50), rotated: true);
    final r = analyzer.analyze(rasterFromImage(tray.image));

    expect(r.markersFound, isTrue);
    expect(r.totalCount, 50, reason: '${r.metrics}');
    expect(r.metrics['excludedBothEnds'], isNull);
    expect(
      r.metrics['logoScoreRotated']!,
      greaterThan(r.metrics['logoScore']!),
    );
  });

  test('hạt nằm đè lên logo không được đếm', () {
    final grains = [...plainGrains(30), const SynthGrain(25, 40, 6.5, 2.4, 0)];
    final r = analyzer.analyze(
      rasterFromImage(renderPlainTray(grains: grains).image),
    );
    expect(r.totalCount, 30);
  });

  test('lót nền tối che logo: gạo trắng, phân tích cả đáy khay', () {
    // Có cả hạt ở hai góc logo — không còn bị bỏ khi logo đã bị che.
    final grains = [
      ...plainGrains(40),
      const SynthGrain(25, 40, 6.5, 2.4, 0),
      const SynthGrain(125, 170, 6.5, 2.4, 1),
    ];
    final r = analyzer.analyze(
      rasterFromImage(renderPlainTray(grains: grains, liner: true).image),
    );
    expect(r.markersFound, isTrue);
    expect(r.metrics['logoCovered'], 1, reason: '${r.metrics}');
    expect(r.excludedRegions, isEmpty);
    expect(r.totalCount, 42, reason: '${r.metrics}');
  });

  test('khay đen trên bàn sáng hơn: nhận viền, logo sáng, đếm gạo trắng', () {
    for (final rotated in [false, true]) {
      final tray = renderPlainTray(
        grains: plainGrains(50),
        black: true,
        rotated: rotated,
      );
      final r = analyzer.analyze(rasterFromImage(tray.image));
      expect(r.markersFound, isTrue);
      expect(r.metrics['trayFloorLuma']!, lessThan(160));
      expect(r.metrics['excludedBothEnds'], isNull, reason: '${r.metrics}');
      expect(r.excludedRegions, hasLength(1));
      expect(r.totalCount, 50, reason: '${r.metrics}');
      expect(r.pixelsPerMm, closeTo(tray.floorPpm, 0.05));
    }
  });

  test('vật sáng chạm cạnh khay (ổ cắm, dây điện) không làm lệch viền', () {
    final tray = renderPlainTray(
      grains: plainGrains(40),
      brightObjects: [
        (x1: 1500, y1: 1900, x2: 1769, y2: 2429),
        (x1: 0, y1: 700, x2: 140, y2: 730),
      ],
    );
    final r = analyzer.analyze(rasterFromImage(tray.image));
    expect(r.markersFound, isTrue);
    expect(r.totalCount, 40, reason: '${r.metrics}');
    expect(r.pixelsPerMm, closeTo(tray.floorPpm, 0.05));
  });
}
