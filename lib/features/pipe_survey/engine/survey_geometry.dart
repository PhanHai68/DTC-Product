import 'dart:math' as math;

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
