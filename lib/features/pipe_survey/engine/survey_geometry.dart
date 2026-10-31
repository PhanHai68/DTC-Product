import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../models/pipe_survey.dart';
import 'survey_bom.dart';

/// Thao tác hình học trên sơ đồ khảo sát (toạ độ m). Hàm thuần, sửa trực
/// tiếp [PipeSurvey].

/// Bước bắt điểm theo lưới (m).
const surveySnapStep = 0.5;

double surveySnap(double v) =>
    (v / surveySnapStep).round() * surveySnapStep + 0.0;

/// Điểm gần ([tolerance] m) vị trí chạm.
SurveyNode? surveyNodeAt(
  PipeSurvey s,
  double x,
  double y, {
  double tolerance = 0.8,
}) {
  SurveyNode? best;
  var bestD = tolerance;
  for (final n in s.nodes) {
    final d = math.sqrt(math.pow(n.x - x, 2) + math.pow(n.y - y, 2));
    if (d <= bestD) {
      best = n;
      bestD = d;
    }
  }
  return best;
}

/// Đoạn ống gần vị trí chạm và điểm chiếu (đã bắt lưới) lên đoạn.
(SurveySegment, double, double)? surveySegmentAt(
  PipeSurvey s,
  double x,
  double y, {
  double tolerance = 0.6,
}) {
  (SurveySegment, double, double)? best;
  var bestD = tolerance;
  for (final seg in s.segments) {
    final a = s.node(seg.a);
    final b = s.node(seg.b);
    if (a == null || b == null) continue;
    final dx = b.x - a.x, dy = b.y - a.y;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) continue;
    final t = (((x - a.x) * dx + (y - a.y) * dy) / len2).clamp(0.0, 1.0);
    final px = a.x + t * dx, py = a.y + t * dy;
    final d = math.sqrt(math.pow(px - x, 2) + math.pow(py - y, 2));
    if (d <= bestD) {
      bestD = d;
      // Bắt lưới theo phương của đoạn (đoạn ngang / dọc giữ toạ độ còn lại).
      final sx = dx.abs() < 1e-9 ? a.x : surveySnap(px);
      final sy = dy.abs() < 1e-9 ? a.y : surveySnap(py);
      best = (seg, sx, sy);
    }
  }
  return best;
}

/// Chèn điểm vào đoạn tại (x, y): tách thành hai đoạn cùng cỡ; chiều dài đo
/// thực tế (nếu có) chia theo tỉ lệ hình vẽ. Trùng đầu đoạn thì trả đầu đó.
SurveyNode surveySplitSegment(
  PipeSurvey s,
  SurveySegment seg,
  double x,
  double y,
) {
  final a = s.node(seg.a)!;
  final b = s.node(seg.b)!;
  for (final end in [a, b]) {
    if ((end.x - x).abs() < 1e-6 && (end.y - y).abs() < 1e-6) return end;
  }
  final mid = SurveyNode(x: x, y: y);
  s.nodes.add(mid);
  final total = surveySegmentDrawnLength(a, b);
  final first = surveySegmentDrawnLength(a, mid);
  final measured = seg.measuredM;
  s.segments.remove(seg);
  s.segments.addAll([
    SurveySegment(
      a: a.id,
      b: mid.id,
      dn: seg.dn,
      measuredM: measured == null || total == 0
          ? null
          : measured * first / total,
      note: seg.note,
    ),
    SurveySegment(
      a: mid.id,
      b: b.id,
      dn: seg.dn,
      measuredM: measured == null || total == 0
          ? null
          : measured * (total - first) / total,
    ),
  ]);
  return mid;
}

/// Điểm tại vị trí chạm: điểm có sẵn, hoặc chèn vào đoạn ống, hoặc điểm mới
/// (bắt lưới).
SurveyNode surveyNodeForTap(PipeSurvey s, double x, double y) {
  final hit = surveyNodeAt(s, x, y);
  if (hit != null) return hit;
  final onSeg = surveySegmentAt(s, x, y);
  if (onSeg != null) {
    return surveySplitSegment(s, onSeg.$1, onSeg.$2, onSeg.$3);
  }
  final node = SurveyNode(x: surveySnap(x), y: surveySnap(y));
  s.nodes.add(node);
  return node;
}

/// Điểm cuối khi vẽ ống từ [from]: chỉ ngang hoặc dọc (theo phương dịch
/// chuyển nhiều hơn), bắt lưới.
(double, double) surveyOrthogonal(SurveyNode from, double x, double y) {
  final sx = surveySnap(x), sy = surveySnap(y);
  return (sx - from.x).abs() >= (sy - from.y).abs()
      ? (sx, from.y)
      : (from.x, sy);
}

/// Thêm đoạn ống [a] – [b] (bỏ qua nếu trùng điểm hoặc đã có).
SurveySegment? surveyAddPipe(
  PipeSurvey s,
  SurveyNode a,
  SurveyNode b, {
  int? dn,
}) {
  if (a.id == b.id) return null;
  final exists = s.segments.any(
    (g) => (g.a == a.id && g.b == b.id) || (g.a == b.id && g.b == a.id),
  );
  if (exists) return null;
  final seg = SurveySegment(a: a.id, b: b.id, dn: dn);
  s.segments.add(seg);
  return seg;
}

/// Xoá điểm và các đoạn nối vào nó; điểm nối còn lại không nối gì cũng xoá.
void surveyDeleteNode(PipeSurvey s, String id) {
  s.segments.removeWhere((g) => g.a == id || g.b == id);
  s.nodes.removeWhere((n) => n.id == id);
  _dropOrphans(s);
}

void surveyDeleteSegment(PipeSurvey s, String id) {
  s.segments.removeWhere((g) => g.id == id);
  _dropOrphans(s);
}

void _dropOrphans(PipeSurvey s) => s.nodes.removeWhere(
  (n) => n.kind == SurveyNodeKind.junction && s.segmentsAt(n.id).isEmpty,
);

/// Chiều rộng mặc định của cột (m), độ dày mặc định của tường (m).
const surveyColumnSizeM = 0.4;
const surveyWallThicknessM = 0.2;

/// Chiều cao chữ mặc định của tên vùng (m).
const surveyAreaTextM = 1.0;

/// Khung chữ ước lượng (m): rộng ~0,3 m mỗi ký tự, cao 0,6 m, góc trên trái
/// tại (x, y).
bool _inText(String text, double tx, double ty, double x, double y) {
  final w = math.max(1.0, text.length * 0.3);
  return x >= tx - 0.3 && x <= tx + w && y >= ty - 0.3 && y <= ty + 0.8;
}

/// Khoảng cách từ (x, y) tới đoạn (ax, ay) – (bx, by).
double _distToSegment(
  double x,
  double y,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0
      ? 0.0
      : (((x - ax) * dx + (y - ay) * dy) / len2).clamp(0.0, 1.0);
  final px = ax + t * dx, py = ay + t * dy;
  return math.sqrt(math.pow(px - x, 2) + math.pow(py - y, 2));
}

/// Hình nền ở vị trí chạm (ưu tiên hình vẽ sau, nằm trên).
SurveyShape? surveyShapeAt(PipeSurvey s, double x, double y) {
  for (final shape in s.shapes.reversed) {
    switch (shape.kind) {
      case SurveyShapeKind.wall:
        final dx = shape.x2 - shape.x1, dy = shape.y2 - shape.y1;
        final len2 = dx * dx + dy * dy;
        final t = len2 == 0
            ? 0.0
            : (((x - shape.x1) * dx + (y - shape.y1) * dy) / len2).clamp(
                0.0,
                1.0,
              );
        final px = shape.x1 + t * dx, py = shape.y1 + t * dy;
        final d = math.sqrt(math.pow(px - x, 2) + math.pow(py - y, 2));
        if (d <= math.max(0.4, (shape.sizeM ?? surveyWallThicknessM) / 2)) {
          return shape;
        }
      case SurveyShapeKind.column:
        final w = (shape.sizeM ?? surveyColumnSizeM) / 2 + 0.3;
        final h = (shape.size2M ?? shape.sizeM ?? surveyColumnSizeM) / 2 + 0.3;
        if ((x - shape.x1).abs() <= w && (y - shape.y1).abs() <= h) {
          return shape;
        }
      case SurveyShapeKind.obstacle:
        final l = math.min(shape.x1, shape.x2),
            r = math.max(shape.x1, shape.x2);
        final t = math.min(shape.y1, shape.y2),
            b = math.max(shape.y1, shape.y2);
        if (x >= l && x <= r && y >= t && y <= b) return shape;
      case SurveyShapeKind.note:
        if (_inText(shape.label, shape.x1, shape.y1, x, y)) return shape;
      case SurveyShapeKind.leader:
        if (_inText(shape.label, shape.x2, shape.y2, x, y) ||
            _distToSegment(x, y, shape.x1, shape.y1, shape.x2, shape.y2) <=
                0.4) {
          return shape;
        }
      case SurveyShapeKind.area:
        final h = shape.sizeM ?? surveyAreaTextM;
        final w = math.max(h, shape.label.length * 0.62 * h);
        if ((x - shape.x1).abs() <= w / 2 + 0.3 &&
            (y - shape.y1).abs() <= h / 2 + 0.3) {
          return shape;
        }
    }
  }
  return null;
}

/// Dời hình nền một khoảng (dx, dy) m.
void surveyMoveShape(SurveyShape h, double dx, double dy) {
  h
    ..x1 += dx
    ..y1 += dy
    ..x2 += dx
    ..y2 += dy;
}

/// Các cạnh của hình chữ nhật.
Iterable<(Offset, Offset)> _edges(Rect r) => [
  (r.topLeft, r.topRight),
  (r.topRight, r.bottomRight),
  (r.bottomRight, r.bottomLeft),
  (r.bottomLeft, r.topLeft),
];

/// Cắt tường như lệnh Trim: bỏ phần tường quanh vị trí chạm, giới hạn bởi
/// hai giao điểm gần nhất với các cạnh cắt (tường khác, cột, chướng ngại và
/// [rects] — phòng cụm máy, tường bao nhà xưởng). Phía không có giao điểm
/// thì cắt tới đầu tường. Không có giao điểm nào: không cắt, trả `false`.
bool surveyTrimWall(
  PipeSurvey s,
  SurveyShape wall,
  double x,
  double y, {
  Iterable<Rect> rects = const [],
}) {
  final a = Offset(wall.x1, wall.y1), b = Offset(wall.x2, wall.y2);
  final d = b - a;
  final len2 = d.dx * d.dx + d.dy * d.dy;
  if (len2 == 0) return false;
  final cutters = <(Offset, Offset)>[
    for (final h in s.shapes)
      if (h.id != wall.id)
        ...switch (h.kind) {
          SurveyShapeKind.wall => [(Offset(h.x1, h.y1), Offset(h.x2, h.y2))],
          SurveyShapeKind.column => _edges(
            Rect.fromCenter(
              center: Offset(h.x1, h.y1),
              width: h.sizeM ?? surveyColumnSizeM,
              height: h.size2M ?? h.sizeM ?? surveyColumnSizeM,
            ),
          ),
          SurveyShapeKind.obstacle => _edges(
            Rect.fromPoints(Offset(h.x1, h.y1), Offset(h.x2, h.y2)),
          ),
          _ => const <(Offset, Offset)>[],
        },
    for (final r in rects) ..._edges(r),
  ];
  // Tham số t (0..1 dọc tường) của các giao điểm.
  final cuts = <double>[];
  for (final (p, q) in cutters) {
    final e = q - p;
    final den = d.dx * e.dy - d.dy * e.dx;
    if (den.abs() < 1e-12) continue; // song song
    final w = p - a;
    final t = (w.dx * e.dy - w.dy * e.dx) / den;
    final u = (w.dx * d.dy - w.dy * d.dx) / den;
    if (t > 1e-6 && t < 1 - 1e-6 && u >= -1e-9 && u <= 1 + 1e-9) cuts.add(t);
  }
  if (cuts.isEmpty) return false;
  final t0 = (((x - a.dx) * d.dx + (y - a.dy) * d.dy) / len2).clamp(0.0, 1.0);
  final lower = cuts.where((t) => t < t0).fold(0.0, math.max);
  final upper = cuts.where((t) => t > t0).fold(1.0, math.min);
  final index = s.shapes.indexOf(wall);
  s.shapes.remove(wall);
  // Làm tròn 1 mm (bỏ sai số dấu phẩy động).
  double mm(double v) => (v * 1000).round() / 1000;
  SurveyShape piece(double from, double to, String label) => SurveyShape(
    kind: SurveyShapeKind.wall,
    x1: mm(a.dx + d.dx * from),
    y1: mm(a.dy + d.dy * from),
    x2: mm(a.dx + d.dx * to),
    y2: mm(a.dy + d.dy * to),
    label: label,
    sizeM: wall.sizeM,
  );
  s.shapes.insertAll(index, [
    if (lower > 0) piece(0, lower, wall.label),
    if (upper < 1) piece(upper, 1, lower > 0 ? '' : wall.label),
  ]);
  return true;
}

/// Xoá điểm như lệnh Erase: điểm giữa hai đoạn thẳng hàng thì nối hai đoạn
/// thành một (cộng chiều dài đo); điểm dùng / cụm máy còn ống nối thì chỉ
/// thành điểm nối (giữ ống); điểm nối khác xoá cùng các đoạn nối vào.
void surveyEraseNode(PipeSurvey s, SurveyNode n) {
  final segs = s.segmentsAt(n.id);
  if (segs.isEmpty) {
    s.nodes.remove(n);
    return;
  }
  if (segs.length == 2) {
    final (g1, g2) = (segs[0], segs[1]);
    final a = s.node(g1.a == n.id ? g1.b : g1.a);
    final b = s.node(g2.a == n.id ? g2.b : g2.a);
    if (a != null && b != null) {
      final cross = (a.x - n.x) * (b.y - n.y) - (a.y - n.y) * (b.x - n.x);
      if (cross.abs() < 1e-9) {
        final m1 = g1.measuredM, m2 = g2.measuredM;
        s.segments
          ..remove(g1)
          ..remove(g2)
          ..add(
            SurveySegment(
              a: a.id,
              b: b.id,
              dn: g1.dn ?? g2.dn,
              measuredM: m1 != null && m2 != null ? m1 + m2 : null,
              note: g1.note.isNotEmpty ? g1.note : g2.note,
              obstacles: g1.obstacles + g2.obstacles,
              obstacleRiseM: g1.obstacleRiseM ?? g2.obstacleRiseM,
            ),
          );
        s.nodes.remove(n);
        return;
      }
    }
  }
  if (n.kind != SurveyNodeKind.junction) {
    n
      ..kind = SurveyNodeKind.junction
      ..name = ''
      ..plant = null
      ..connectionHeightM = null
      ..dropDn = null;
    return;
  }
  surveyDeleteNode(s, n.id);
}

/// Khung bao (m) của hình nền — để tô sáng khi chọn.
Rect surveyShapeBounds(SurveyShape h) {
  switch (h.kind) {
    case SurveyShapeKind.wall:
    case SurveyShapeKind.obstacle:
      return Rect.fromPoints(Offset(h.x1, h.y1), Offset(h.x2, h.y2));
    case SurveyShapeKind.column:
      return Rect.fromCenter(
        center: Offset(h.x1, h.y1),
        width: h.sizeM ?? surveyColumnSizeM,
        height: h.size2M ?? h.sizeM ?? surveyColumnSizeM,
      );
    case SurveyShapeKind.note:
      return Rect.fromLTWH(
        h.x1,
        h.y1,
        math.max(1.0, h.label.length * 0.3),
        0.6,
      );
    case SurveyShapeKind.leader:
      return Rect.fromPoints(
        Offset(h.x1, h.y1),
        Offset(h.x2, h.y2),
      ).expandToInclude(
        Rect.fromLTWH(h.x2, h.y2, math.max(1.0, h.label.length * 0.3), 0.6),
      );
    case SurveyShapeKind.area:
      final t = h.sizeM ?? surveyAreaTextM;
      return Rect.fromCenter(
        center: Offset(h.x1, h.y1),
        width: math.max(t, h.label.length * 0.62 * t),
        height: t,
      );
  }
}
