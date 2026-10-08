import 'dart:math' as math;
import 'dart:typed_data';

/// Hướng 8 lân cận theo chiều kim đồng hồ (trục y hướng xuống), bắt đầu
/// từ phía đông.
const _dx = [1, 1, 0, -1, -1, -1, 0, 1];
const _dy = [0, 1, 1, 1, 0, -1, -1, -1];

int _dirOf(int dx, int dy) {
  for (var i = 0; i < 8; i++) {
    if (_dx[i] == dx && _dy[i] == dy) return i;
  }
  return 0;
}

/// Dò đường viền ngoài (Moore) của vùng [mask] (1 = thuộc vùng) kích thước
/// [width] × [height]. Trả về danh sách phẳng [x0, y0, x1, y1, ...] theo tâm
/// pixel. Vùng phải liên thông 8 hướng.
List<double> traceContour(Uint8List mask, int width, int height) {
  var start = -1;
  for (var i = 0; i < mask.length; i++) {
    if (mask[i] != 0) {
      start = i;
      break;
    }
  }
  if (start < 0) return const [];
  bool fg(int x, int y) =>
      x >= 0 && y >= 0 && x < width && y < height && mask[y * width + x] != 0;

  final sx = start % width, sy = start ~/ width;
  final out = <double>[sx + 0.5, sy + 0.5];
  var cx = sx, cy = sy;
  var back = 4; // pixel phía tây của điểm đầu chắc chắn là nền
  int? firstDir;
  final maxSteps = 4 * mask.length + 16;
  for (var step = 0; step < maxSteps; step++) {
    var found = -1;
    for (var k = 1; k <= 8; k++) {
      final d = (back + k) % 8;
      if (fg(cx + _dx[d], cy + _dy[d])) {
        found = d;
        break;
      }
    }
    if (found < 0) break; // pixel đơn lẻ
    if (cx == sx && cy == sy) {
      if (firstDir == null) {
        firstDir = found;
      } else if (found == firstDir) {
        break; // quay lại điểm đầu theo đúng hướng ban đầu
      }
    }
    final prev = (found + 7) % 8;
    final bx = cx + _dx[prev], by = cy + _dy[prev];
    cx += _dx[found];
    cy += _dy[found];
    back = _dirOf(bx - cx, by - cy);
    if (cx == sx && cy == sy) continue;
    out
      ..add(cx + 0.5)
      ..add(cy + 0.5);
  }
  return out;
}

/// Rút gọn đa giác khép kín bằng Douglas–Peucker.
List<double> simplifyClosed(List<double> pts, double epsilon) {
  final n = pts.length ~/ 2;
  if (n <= 4) return List.of(pts);
  // Tách đa giác tại điểm xa điểm đầu nhất thành hai đường hở.
  var far = 0;
  var farD = -1.0;
  for (var i = 1; i < n; i++) {
    final dx = pts[2 * i] - pts[0], dy = pts[2 * i + 1] - pts[1];
    final d = dx * dx + dy * dy;
    if (d > farD) {
      farD = d;
      far = i;
    }
  }
  final keep = List<bool>.filled(n + 1, false);
  keep[0] = keep[far] = keep[n] = true;
  double px(int i) => pts[2 * (i % n)];
  double py(int i) => pts[2 * (i % n) + 1];

  void dp(int a, int b) {
    if (b - a < 2) return;
    final ax = px(a), ay = py(a), bx = px(b), by = py(b);
    final lx = bx - ax, ly = by - ay;
    final len = math.sqrt(lx * lx + ly * ly);
    var best = -1;
    var bestD = 0.0;
    for (var i = a + 1; i < b; i++) {
      final d = len == 0
          ? math.sqrt(math.pow(px(i) - ax, 2) + math.pow(py(i) - ay, 2))
          : ((px(i) - ax) * ly - (py(i) - ay) * lx).abs() / len;
      if (d > bestD) {
        bestD = d;
        best = i;
      }
    }
    if (bestD > epsilon) {
      keep[best] = true;
      dp(a, best);
      dp(best, b);
    }
  }

  dp(0, far);
  dp(far, n);
  final out = <double>[];
  for (var i = 0; i < n; i++) {
    if (keep[i]) out.addAll([pts[2 * i], pts[2 * i + 1]]);
  }
  return out;
}

/// Bao lồi (monotone chain) của các điểm [x, y]; trả về theo chiều ngược
/// kim đồng hồ, không lặp điểm đầu.
List<List<double>> convexHull(List<List<double>> points) {
  if (points.length < 3) return List.of(points);
  final p = List<List<double>>.of(
    points,
  )..sort((a, b) => a[0] != b[0] ? a[0].compareTo(b[0]) : a[1].compareTo(b[1]));
  double cross(List<double> o, List<double> a, List<double> b) =>
      (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  final lower = <List<double>>[];
  for (final pt in p) {
    while (lower.length >= 2 &&
        cross(lower[lower.length - 2], lower.last, pt) <= 0) {
      lower.removeLast();
    }
    lower.add(pt);
  }
  final upper = <List<double>>[];
  for (final pt in p.reversed) {
    while (upper.length >= 2 &&
        cross(upper[upper.length - 2], upper.last, pt) <= 0) {
      upper.removeLast();
    }
    upper.add(pt);
  }
  lower.removeLast();
  upper.removeLast();
  return [...lower, ...upper];
}

double polygonArea(List<List<double>> poly) {
  var s = 0.0;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i], b = poly[(i + 1) % poly.length];
    s += a[0] * b[1] - b[0] * a[1];
  }
  return s.abs() / 2;
}

/// Hình chữ nhật bao nhỏ nhất (xoay tự do) của bao lồi [hull].
/// Trả về (dài, rộng, góc của cạnh dài theo radian).
({double length, double width, double angle}) minAreaRect(
  List<List<double>> hull,
) {
  if (hull.isEmpty) return (length: 0, width: 0, angle: 0);
  if (hull.length == 1) return (length: 0, width: 0, angle: 0);
  var bestArea = double.infinity;
  var result = (length: 0.0, width: 0.0, angle: 0.0);
  for (var i = 0; i < hull.length; i++) {
    final a = hull[i], b = hull[(i + 1) % hull.length];
    final ex = b[0] - a[0], ey = b[1] - a[1];
    final len = math.sqrt(ex * ex + ey * ey);
    if (len == 0) continue;
    final ux = ex / len, uy = ey / len;
    var minU = double.infinity, maxU = -double.infinity;
    var minV = double.infinity, maxV = -double.infinity;
    for (final p in hull) {
      final u = p[0] * ux + p[1] * uy;
      final v = -p[0] * uy + p[1] * ux;
      if (u < minU) minU = u;
      if (u > maxU) maxU = u;
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final w = maxU - minU, h = maxV - minV;
    final area = w * h;
    if (area < bestArea) {
      bestArea = area;
      final angle = math.atan2(uy, ux);
      result = w >= h
          ? (length: w, width: h, angle: angle)
          : (length: h, width: w, angle: angle + math.pi / 2);
    }
  }
  return result;
}

/// Điểm (x, y) có nằm trong đa giác phẳng [poly] = [x0, y0, x1, y1, ...]?
bool pointInPolygon(double x, double y, List<double> poly) {
  final n = poly.length ~/ 2;
  var inside = false;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final xi = poly[2 * i], yi = poly[2 * i + 1];
    final xj = poly[2 * j], yj = poly[2 * j + 1];
    if ((yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
      inside = !inside;
    }
  }
  return inside;
}
