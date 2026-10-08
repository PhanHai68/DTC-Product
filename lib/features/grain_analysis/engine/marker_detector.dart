import 'dart:math' as math;
import 'dart:typed_data';

import 'binary_ops.dart';
import 'grain_analysis_config.dart';
import 'raster.dart';
import 'tray_layout.dart';

/// Kết quả tìm 4 mốc góc khay. [imagePoints] là tâm mốc trên ảnh gốc
/// (pixel, gốc ở mép trên-trái) theo đúng thứ tự [TrayLayout.markerCenters]
/// — đã xét trường hợp khay bị xoay 90°.
class MarkerDetection {
  const MarkerDetection(this.imagePoints, {required this.candidateCount});

  final List<List<double>> imagePoints;
  final int candidateCount;
}

class _Candidate {
  _Candidate(this.x, this.y, this.area);
  final double x;
  final double y;
  final int area;
}

/// Tìm 4 mốc vuông đen có ô trắng ở giữa (xem [TrayLayout]). Trả về null
/// nếu không thấy đủ 4 mốc.
MarkerDetection? detectTrayMarkers(
  RgbRaster image,
  GrainAnalysisConfig config,
  TrayLayout layout,
) {
  final small = image.downscaleTo(config.markerDetectMaxEdge);
  final scale = image.width / small.width;
  final gray = small.toGray();
  final histogram = List<int>.filled(256, 0);
  for (final v in gray) {
    histogram[v]++;
  }
  final otsu = otsuThreshold(histogram);

  var best = <_Candidate>[];
  for (final factor in const [1.0, 0.7, 1.25, 0.5]) {
    final threshold = (otsu * factor).round().clamp(10, 245);
    final dark = Uint8List(gray.length);
    for (var i = 0; i < gray.length; i++) {
      if (gray[i] <= threshold) dark[i] = 1;
    }
    final found = _findCandidates(dark, small.width, small.height, config);
    if (found.length >= 4) {
      best = found;
      break;
    }
    if (found.length > best.length) best = found;
  }
  if (best.length < 4) return null;

  final chosen = _chooseFour(best);
  if (chosen == null) return null;
  final ordered = _orderClockwise(chosen);
  final points = [
    for (final c in ordered) [c.x * scale, c.y * scale],
  ];
  return MarkerDetection(
    _matchOrientation(points, layout),
    candidateCount: best.length,
  );
}

List<_Candidate> _findCandidates(
  Uint8List dark,
  int width,
  int height,
  GrainAnalysisConfig config,
) {
  final components = labelComponents(dark, width, height);
  final total = width * height;
  final out = <_Candidate>[];
  for (final s in components.stats) {
    final frac = s.area / total;
    if (frac < config.markerMinAreaFraction ||
        frac > config.markerMaxAreaFraction) {
      continue;
    }
    final bw = s.bboxWidth, bh = s.bboxHeight;
    final aspect = math.max(bw, bh) / math.min(bw, bh);
    if (aspect > config.markerMaxAspect) continue;
    final fill = s.area / (bw * bh);
    if (fill < config.markerMinFill || fill > config.markerMaxFill) continue;

    // Ô trắng giữa mốc: pixel không thuộc mốc, không thông ra mép hình bao.
    final local = Uint8List(bw * bh);
    for (var y = 0; y < bh; y++) {
      for (var x = 0; x < bw; x++) {
        final l = components.labels[(s.minY + y) * width + s.minX + x];
        if (l == s.label) local[y * bw + x] = 1;
      }
    }
    final outside = Uint8List(bw * bh);
    final stack = <int>[];
    void seed(int i) {
      if (local[i] == 0 && outside[i] == 0) {
        outside[i] = 1;
        stack.add(i);
      }
    }

    for (var x = 0; x < bw; x++) {
      seed(x);
      seed((bh - 1) * bw + x);
    }
    for (var y = 0; y < bh; y++) {
      seed(y * bw);
      seed(y * bw + bw - 1);
    }
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      final x = i % bw;
      if (x > 0) seed(i - 1);
      if (x < bw - 1) seed(i + 1);
      if (i >= bw) seed(i - bw);
      if (i < local.length - bw) seed(i + bw);
    }
    var holeArea = 0;
    var hx = 0.0, hy = 0.0;
    for (var i = 0; i < local.length; i++) {
      if (local[i] == 0 && outside[i] == 0) {
        holeArea++;
        hx += i % bw;
        hy += i ~/ bw;
      }
    }
    if (holeArea == 0) continue;
    final holeRatio = holeArea / (holeArea + s.area);
    if (holeRatio < config.markerMinHoleRatio ||
        holeRatio > config.markerMaxHoleRatio) {
      continue;
    }
    final cx = s.minX + hx / holeArea + 0.5;
    final cy = s.minY + hy / holeArea + 0.5;
    final offset = math.sqrt(
      math.pow(cx - s.centroidX, 2) + math.pow(cy - s.centroidY, 2),
    );
    if (offset > 0.2 * math.max(bw, bh)) continue;
    // Tâm của cả mốc (gồm ô trắng) — hình vuông đối xứng nên trùng tâm.
    final fullArea = s.area + holeArea;
    out.add(
      _Candidate(
        (s.centroidX * s.area + cx * holeArea) / fullArea,
        (s.centroidY * s.area + cy * holeArea) / fullArea,
        s.area,
      ),
    );
  }
  return out;
}

/// Chọn 4 ứng viên tạo tứ giác lồi lớn nhất, ưu tiên các mốc cùng cỡ.
List<_Candidate>? _chooseFour(List<_Candidate> all) {
  if (all.length == 4) return all;
  final pool = List<_Candidate>.of(all)
    ..sort((a, b) => b.area.compareTo(a.area));
  final c = pool.take(10).toList();
  List<_Candidate>? best;
  var bestScore = 0.0;
  for (var a = 0; a < c.length; a++) {
    for (var b = a + 1; b < c.length; b++) {
      for (var d = b + 1; d < c.length; d++) {
        for (var e = d + 1; e < c.length; e++) {
          final set = [c[a], c[b], c[d], c[e]];
          final ordered = _orderClockwise(set);
          final area = _quadArea(ordered);
          final areas = set.map((s) => s.area);
          final similarity = areas.reduce(math.min) / areas.reduce(math.max);
          final score = area * similarity;
          if (score > bestScore) {
            bestScore = score;
            best = set;
          }
        }
      }
    }
  }
  return best;
}

/// Sắp theo chiều kim đồng hồ trên ảnh, bắt đầu từ điểm trên-trái.
List<_Candidate> _orderClockwise(List<_Candidate> pts) {
  final cx = pts.map((p) => p.x).reduce((a, b) => a + b) / pts.length;
  final cy = pts.map((p) => p.y).reduce((a, b) => a + b) / pts.length;
  final sorted = List<_Candidate>.of(pts)
    ..sort(
      (a, b) => math
          .atan2(a.y - cy, a.x - cx)
          .compareTo(math.atan2(b.y - cy, b.x - cx)),
    );
  var start = 0;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].x + sorted[i].y < sorted[start].x + sorted[start].y) {
      start = i;
    }
  }
  return [for (var i = 0; i < 4; i++) sorted[(start + i) % 4]];
}

double _quadArea(List<_Candidate> q) {
  var s = 0.0;
  for (var i = 0; i < 4; i++) {
    final a = q[i], b = q[(i + 1) % 4];
    s += a.x * b.y - b.x * a.y;
  }
  return s.abs() / 2;
}

/// Ảnh có thể chụp khay xoay ngang: nếu cạnh dài trên ảnh không cùng chiều
/// với cạnh dài của khay thì xoay thứ tự 1 bước để ảnh đã nắn luôn đúng
/// chiều khay.
List<List<double>> _matchOrientation(
  List<List<double>> pts,
  TrayLayout layout,
) {
  double dist(List<double> a, List<double> b) =>
      math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2));
  final horizontal = dist(pts[0], pts[1]) + dist(pts[3], pts[2]);
  final vertical = dist(pts[0], pts[3]) + dist(pts[1], pts[2]);
  final imageWide = horizontal > vertical;
  final trayWide = layout.markerSpacingXMm > layout.markerSpacingYMm;
  if (imageWide == trayWide) return pts;
  // Mốc trên-trái của khay đang nằm ở góc dưới-trái của ảnh.
  return [pts[3], pts[0], pts[1], pts[2]];
}
