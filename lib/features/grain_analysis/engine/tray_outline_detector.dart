import 'dart:math' as math;
import 'dart:typed_data';

import 'binary_ops.dart';
import 'grain_analysis_config.dart';
import 'raster.dart';
import 'tray_layout.dart';

/// Kết quả tìm viền ngoài khay không mốc. [imagePoints] là 4 góc viền
/// ngoài trên ảnh gốc theo thứ tự trên-trái, trên-phải, dưới-phải,
/// dưới-trái của khay khổ đứng ([TrayLayout.pageWidthMm] × pageHeightMm).
/// Khay đối xứng nên chưa phân biệt được xoay 180° — xem `excludedRects`.
class TrayOutlineDetection {
  const TrayOutlineDetection(this.imagePoints, {required this.support});

  final List<List<double>> imagePoints;

  /// Tỉ lệ điểm biên của vùng sáng nằm trên 4 cạnh tìm được (0..1).
  final double support;
}

class _Line {
  _Line(this.nx, this.ny, this.c, this.count);

  /// Đường thẳng nx·x + ny·y = c, (nx, ny) là véc-tơ đơn vị.
  final double nx;
  final double ny;
  double c;
  final int count;

  double get angle => math.atan2(ny, nx);
}

/// Tìm khay khác màu hẳn mặt bàn — khay trắng trên bàn sẫm, hoặc khay đen
/// trên bàn sáng hơn: lấy vùng sáng (hoặc tối) lớn nhất, dò các đoạn thẳng dài trên biên vùng (RANSAC), rồi chọn 4
/// đường tạo hình chữ nhật đúng tỉ lệ khay. Góc khay bo tròn và vật sáng
/// chạm vào khay (dây điện, ổ cắm) không ảnh hưởng vì chỉ dùng phần cạnh
/// thẳng. Trả về null nếu không thấy.
TrayOutlineDetection? detectTrayOutline(
  RgbRaster image,
  GrainAnalysisConfig config,
  TrayLayout layout,
) {
  final small = image.downscaleTo(config.outlineDetectMaxEdge);
  final w = small.width, h = small.height;
  final scale = image.width / w;
  final gray = small.toGray();
  final histogram = List<int>.filled(256, 0);
  for (final v in gray) {
    histogram[v]++;
  }
  final otsu = otsuThreshold(histogram);
  // Bóng đổ đậm trên khay làm histogram có 3 đỉnh (bàn, khay trong bóng,
  // khay ngoài sáng): Otsu có thể chỉ lấy phần sáng. Thử vài ngưỡng, cả hai
  // chiều (khay sáng hơn / tối hơn bàn), lấy kết quả khớp 4 cạnh nhất.
  ({List<List<double>> corners, double support})? best;
  for (final brightTray in const [true, false]) {
    for (final factor in const [1.0, 0.75, 1.15, 0.55]) {
      final found = _detectAt(
        gray,
        w,
        h,
        (otsu * factor).round().clamp(10, 245),
        brightTray,
        config,
        layout,
      );
      if (found != null && (best == null || found.support > best.support)) {
        best = found;
      }
    }
  }
  if (best == null) return null;
  final points = [
    for (final p in best.corners) [p[0] * scale, p[1] * scale],
  ];
  return TrayOutlineDetection(
    _matchOrientation(points, layout),
    support: best.support,
  );
}

/// Tìm khay ở một ngưỡng sáng ([brightTray]: khay là phần sáng hơn ngưỡng):
/// 4 góc theo chiều kim đồng hồ từ góc trên-trái (pixel ảnh thu nhỏ) và tỉ
/// lệ điểm biên nằm trên 4 cạnh.
({List<List<double>> corners, double support})? _detectAt(
  Uint8List gray,
  int w,
  int h,
  int threshold,
  bool brightTray,
  GrainAnalysisConfig config,
  TrayLayout layout,
) {
  var bright = Uint8List(gray.length);
  for (var i = 0; i < gray.length; i++) {
    if ((gray[i] > threshold) == brightTray) bright[i] = 1;
  }
  // Cắt các dải mảnh (dây điện) dính vào khay.
  bright = morphOpen(
    bright,
    w,
    h,
    math.max(1, (0.004 * math.max(w, h)).round()),
  );
  final components = labelComponents(bright, w, h);
  ComponentStats? tray;
  for (final s in components.stats) {
    if (tray == null || s.area > tray.area) tray = s;
  }
  if (tray == null || tray.area < config.outlineMinAreaFraction * w * h) {
    return null;
  }

  // Biên ngoài của vùng (đã lấp lỗ: logo, hạt, vết bẩn), bỏ phần nằm trên
  // mép ảnh — khay bị cắt khung thì mép ảnh không phải cạnh khay.
  final bw = tray.bboxWidth + 2, bh = tray.bboxHeight + 2;
  final local = Uint8List(bw * bh);
  for (var y = 0; y < tray.bboxHeight; y++) {
    final row = (tray.minY + y) * w + tray.minX;
    for (var x = 0; x < tray.bboxWidth; x++) {
      if (components.labels[row + x] == tray.label) {
        local[(y + 1) * bw + x + 1] = 1;
      }
    }
  }
  fillHoles(local, bw, bh);
  final xs = <double>[], ys = <double>[];
  for (var y = 1; y < bh - 1; y++) {
    for (var x = 1; x < bw - 1; x++) {
      final i = y * bw + x;
      if (local[i] == 0) continue;
      if (local[i - 1] != 0 &&
          local[i + 1] != 0 &&
          local[i - bw] != 0 &&
          local[i + bw] != 0) {
        continue;
      }
      final gx = tray.minX + x - 1, gy = tray.minY + y - 1;
      if (gx == 0 || gy == 0 || gx == w - 1 || gy == h - 1) continue;
      xs.add(gx + 0.5);
      ys.add(gy + 0.5);
    }
  }
  if (xs.length < 40) return null;

  final lines = _ransacLines(xs, ys, config, math.max(w, h).toDouble());
  final quad = _bestQuad(lines, w, h, layout);
  if (quad == null) return null;

  // Điểm biên là tâm pixel sáng ngoài cùng: cạnh thật lệch ra ngoài ½ pixel.
  final gx = quad.corners.fold<double>(0, (s, p) => s + p[0]) / 4;
  final gy = quad.corners.fold<double>(0, (s, p) => s + p[1]) / 4;
  for (final l in quad.lines) {
    l.c += (l.nx * gx + l.ny * gy < l.c) ? 0.5 : -0.5;
  }
  final corners = _corners(quad.lines);
  if (corners == null) return null;
  return (corners: _orderClockwise(corners), support: quad.support / xs.length);
}

/// Dò lần lượt các đường thẳng có nhiều điểm biên nhất; mỗi lần tìm được
/// thì bỏ các điểm thuộc đường đó rồi dò tiếp.
List<_Line> _ransacLines(
  List<double> xs,
  List<double> ys,
  GrainAnalysisConfig config,
  double longEdge,
) {
  final random = math.Random(7);
  final tol = config.outlineLineTolerancePx;
  final minSeparation = 0.05 * longEdge;
  final minCount = math.max(20, (0.04 * xs.length).round());
  var idx = List<int>.generate(xs.length, (i) => i);
  final lines = <_Line>[];
  for (var k = 0; k < config.outlineMaxLines && idx.length >= minCount; k++) {
    _Line? best;
    for (var it = 0; it < config.outlineRansacIterations; it++) {
      final a = idx[random.nextInt(idx.length)];
      final b = idx[random.nextInt(idx.length)];
      final dx = xs[b] - xs[a], dy = ys[b] - ys[a];
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < minSeparation) continue;
      final nx = -dy / len, ny = dx / len;
      final c = nx * xs[a] + ny * ys[a];
      var count = 0;
      for (final i in idx) {
        if ((nx * xs[i] + ny * ys[i] - c).abs() <= tol) count++;
      }
      if (best == null || count > best.count) best = _Line(nx, ny, c, count);
    }
    if (best == null || best.count < minCount) break;
    // Khớp lại bằng bình phương tối thiểu toàn phần trên các điểm thuộc
    // đường, để cạnh không phụ thuộc hai điểm ngẫu nhiên.
    final inliers = [
      for (final i in idx)
        if ((best.nx * xs[i] + best.ny * ys[i] - best.c).abs() <= tol) i,
    ];
    final refined = _fitLine(inliers, xs, ys) ?? best;
    lines.add(_Line(refined.nx, refined.ny, refined.c, inliers.length));
    idx = [
      for (final i in idx)
        if ((refined.nx * xs[i] + refined.ny * ys[i] - refined.c).abs() >
            2 * tol)
          i,
    ];
  }
  return lines;
}

_Line? _fitLine(List<int> pts, List<double> xs, List<double> ys) {
  if (pts.length < 2) return null;
  var mx = 0.0, my = 0.0;
  for (final i in pts) {
    mx += xs[i];
    my += ys[i];
  }
  mx /= pts.length;
  my /= pts.length;
  var sxx = 0.0, sxy = 0.0, syy = 0.0;
  for (final i in pts) {
    final dx = xs[i] - mx, dy = ys[i] - my;
    sxx += dx * dx;
    sxy += dx * dy;
    syy += dy * dy;
  }
  // Pháp tuyến = véc-tơ riêng ứng với trị riêng nhỏ của ma trận hiệp phương sai.
  final theta = 0.5 * math.atan2(2 * sxy, sxx - syy);
  final nx = -math.sin(theta), ny = math.cos(theta);
  return _Line(nx, ny, nx * mx + ny * my, pts.length);
}

class _Quad {
  _Quad(this.lines, this.corners, this.support);
  final List<_Line> lines;
  final List<List<double>> corners;
  final int support;
}

/// Chọn 4 đường gồm hai cặp gần song song, cắt nhau thành tứ giác lồi có
/// tỉ lệ cạnh gần tỉ lệ khay; ưu tiên nhiều điểm biên nhất.
_Quad? _bestQuad(List<_Line> lines, int w, int h, TrayLayout layout) {
  final ratio =
      math.max(layout.pageWidthMm, layout.pageHeightMm) /
      math.min(layout.pageWidthMm, layout.pageHeightMm);
  double angleDiff(_Line a, _Line b) {
    // Góc giữa hai đường (không phân biệt hướng), 0..90°.
    var d = (a.angle - b.angle).abs() % math.pi;
    if (d > math.pi / 2) d = math.pi - d;
    return d * 180 / math.pi;
  }

  _Quad? best;
  final n = lines.length;
  for (var a = 0; a < n; a++) {
    for (var b = a + 1; b < n; b++) {
      for (var c = b + 1; c < n; c++) {
        for (var d = c + 1; d < n; d++) {
          final set = [lines[a], lines[b], lines[c], lines[d]];
          for (final pairing in const [
            [0, 1, 2, 3],
            [0, 2, 1, 3],
            [0, 3, 1, 2],
          ]) {
            final p1 = set[pairing[0]], p2 = set[pairing[1]];
            final q1 = set[pairing[2]], q2 = set[pairing[3]];
            if (angleDiff(p1, p2) > 25 || angleDiff(q1, q2) > 25) continue;
            if (angleDiff(p1, q1) < 50) continue;
            final ordered = [p1, q1, p2, q2];
            final corners = _corners(ordered);
            if (corners == null) continue;
            var inside = true;
            for (final p in corners) {
              if (p[0] < -0.1 * w ||
                  p[0] > 1.1 * w ||
                  p[1] < -0.1 * h ||
                  p[1] > 1.1 * h) {
                inside = false;
              }
            }
            if (!inside || !_isConvex(corners)) continue;
            double dist(int i, int j) => math.sqrt(
              math.pow(corners[i][0] - corners[j][0], 2) +
                  math.pow(corners[i][1] - corners[j][1], 2),
            );
            final s1 = (dist(0, 1) + dist(2, 3)) / 2;
            final s2 = (dist(1, 2) + dist(3, 0)) / 2;
            final r = math.max(s1, s2) / math.min(s1, s2);
            if (r < ratio * 0.8 || r > ratio * 1.25) continue;
            if (s1 * s2 < 0.1 * w * h) continue;
            final support = set.fold<int>(0, (s, l) => s + l.count);
            if (best == null || support > best.support) {
              best = _Quad(ordered, corners, support);
            }
          }
        }
      }
    }
  }
  return best;
}

/// Giao điểm của các đường liên tiếp (đường i với đường i+1), theo vòng.
List<List<double>>? _corners(List<_Line> ring) {
  final out = <List<double>>[];
  for (var i = 0; i < 4; i++) {
    final a = ring[i], b = ring[(i + 1) % 4];
    final det = a.nx * b.ny - a.ny * b.nx;
    if (det.abs() < 1e-9) return null;
    out.add([(a.c * b.ny - a.ny * b.c) / det, (a.nx * b.c - a.c * b.nx) / det]);
  }
  return out;
}

bool _isConvex(List<List<double>> q) {
  var sign = 0;
  for (var i = 0; i < 4; i++) {
    final a = q[i], b = q[(i + 1) % 4], c = q[(i + 2) % 4];
    final cross = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]);
    final s = cross > 0 ? 1 : -1;
    if (sign == 0) {
      sign = s;
    } else if (s != sign) {
      return false;
    }
  }
  return true;
}

/// Sắp theo chiều kim đồng hồ trên ảnh, bắt đầu từ điểm trên-trái.
List<List<double>> _orderClockwise(List<List<double>> pts) {
  final cx = pts.fold<double>(0, (s, p) => s + p[0]) / 4;
  final cy = pts.fold<double>(0, (s, p) => s + p[1]) / 4;
  final sorted = List<List<double>>.of(pts)
    ..sort(
      (a, b) => math
          .atan2(a[1] - cy, a[0] - cx)
          .compareTo(math.atan2(b[1] - cy, b[0] - cx)),
    );
  var start = 0;
  for (var i = 1; i < 4; i++) {
    if (sorted[i][0] + sorted[i][1] < sorted[start][0] + sorted[start][1]) {
      start = i;
    }
  }
  return [for (var i = 0; i < 4; i++) sorted[(start + i) % 4]];
}

/// Khay nằm ngang trên ảnh thì xoay thứ tự góc 1 bước, để cạnh ngắn của
/// khay luôn là trục x.
List<List<double>> _matchOrientation(
  List<List<double>> pts,
  TrayLayout layout,
) {
  double dist(List<double> a, List<double> b) =>
      math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2));
  final horizontal = dist(pts[0], pts[1]) + dist(pts[3], pts[2]);
  final vertical = dist(pts[0], pts[3]) + dist(pts[1], pts[2]);
  final imageWide = horizontal > vertical;
  final trayWide = layout.pageWidthMm > layout.pageHeightMm;
  if (imageWide == trayWide) return pts;
  return [pts[3], pts[0], pts[1], pts[2]];
}
