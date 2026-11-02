import 'package:flutter/painting.dart';

import '../engine/survey_bom.dart';
import '../models/pipe_survey.dart';

/// Một nhãn đã xếp chỗ: khung (px, gồm lề nền trắng) và chữ.
class SurveyLabel {
  const SurveyLabel(this.rect, this.text);
  final Rect rect;
  final TextPainter text;
}

/// Nhãn trên sơ đồ: chiều dài + cao độ từng đoạn ống (theo id đoạn) và chênh
/// cao ống đứng tại điểm (theo id điểm).
class SurveyLabels {
  const SurveyLabels(this.segments, this.risers);
  final Map<String, SurveyLabel> segments;
  final Map<String, SurveyLabel> risers;
}

const _pipe = Color(0xFF1F4E9D);
const _riser = Color(0xFF7C3AED);
const _unknown = Color(0xFF94A3B8);

String _num(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble()
      ? '${r.round()}'
      : r.toStringAsFixed(1).replaceAll('.', ',');
}

TextStyle _style(Color color, {bool bold = true}) => TextStyle(
  fontSize: 10,
  color: color,
  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
);

/// Xếp nhãn tránh chồng nhau (toạ độ sơ đồ × [ppm], chưa dời gốc): thử lần
/// lượt các chỗ quanh giữa đoạn (trên / dưới, phải / trái, dịch dọc đoạn),
/// chọn chỗ đầu tiên không đè lên điểm, tên điểm, ống khác hay nhãn đã xếp.
/// Dùng chung cho vẽ và chạm (mở hộp sửa đoạn).
SurveyLabels surveyLayoutLabels(PipeSurvey s, double ppm) {
  Offset at(SurveyNode n) => Offset(n.x * ppm, n.y * ppm);
  final blocked = <Rect>[];
  // Điểm và tên điểm.
  for (final n in s.nodes) {
    final p = at(n);
    blocked.add(Rect.fromCircle(center: p, radius: 10));
    final name = switch (n.kind) {
      SurveyNodeKind.usePoint => n.name,
      SurveyNodeKind.compressor when n.plant == null =>
        n.name.isEmpty ? 'Cụm máy' : n.name,
      _ => '',
    };
    if (name.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(text: name, style: _style(_pipe).copyWith(fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      blocked.add(
        Rect.fromLTWH(p.dx + 9, p.dy + 3, tp.width + 4, tp.height + 2),
      );
    }
  }
  // Đường ống (mỗi đoạn một khung mảnh).
  final lines = <String, Rect>{};
  for (final seg in s.segments) {
    final a = s.node(seg.a), b = s.node(seg.b);
    if (a == null || b == null) continue;
    lines[seg.id] = Rect.fromPoints(at(a), at(b)).inflate(3);
  }

  bool free(Rect r, {String? own}) =>
      !blocked.any((b) => b.overlaps(r)) &&
      !lines.entries.any((e) => e.key != own && e.value.overlaps(r));

  // Diện tích chồng lên vật khác (khi không còn chỗ trống: chọn chỗ ít
  // chồng nhất).
  double overlap(Rect r, String? own) {
    var sum = 0.0;
    for (final b in [
      ...blocked,
      for (final e in lines.entries)
        if (e.key != own) e.value,
    ]) {
      if (!b.overlaps(r)) continue;
      final i = b.intersect(r);
      sum += i.width * i.height;
    }
    return sum;
  }

  Rect place(List<Rect> candidates, {String? own}) {
    var pick = candidates.firstWhere(
      (r) => free(r, own: own),
      orElse: () => Rect.zero,
    );
    if (pick == Rect.zero) {
      pick = candidates.reduce(
        (x, y) => overlap(x, own) <= overlap(y, own) ? x : y,
      );
    }
    blocked.add(pick.inflate(1));
    return pick;
  }

  final segments = <String, SurveyLabel>{};
  for (final seg in s.segments) {
    final a = s.node(seg.a), b = s.node(seg.b);
    if (a == null || b == null) continue;
    final len = seg.measuredM ?? surveySegmentDrawnLength(a, b);
    final (ea, eb) = surveySegmentEnds(s, seg);
    final elev = ea == null || eb == null
        ? '▲?'
        : (ea - eb).abs() < 1e-6
        ? '▲${_num(ea)} m'
        : '▲${_num(ea)}→${_num(eb)} m';
    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: [
              '${_num(len)} m${seg.measuredM != null ? '*' : ''}',
              if (seg.dn != null && seg.dn != s.defaultDn) 'DN${seg.dn}',
            ].join(' · '),
            style: _style(_pipe),
          ),
          TextSpan(
            text: '  $elev',
            style: _style(
              ea == null ? _unknown : _riser,
              bold: seg.heightM != null,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 4, h = tp.height + 2;
    final pa = at(a), pb = at(b);
    final horizontal = (pb.dx - pa.dx).abs() >= (pb.dy - pa.dy).abs();
    // Gần ống trước, xa dần ra (tuyến dày, đoạn ngắn).
    final candidates = [
      for (final far in const [0.0, 1.0, 2.0, 3.0])
        for (final t in const [0.5, 0.3, 0.7, 0.15, 0.85])
          ...() {
            final m = Offset.lerp(pa, pb, t)!;
            final dy = 6 + far * (h + 2), dx = 8 + far * (w * 0.6);
            return horizontal
                ? [
                    Rect.fromLTWH(m.dx - w / 2, m.dy - dy - h, w, h),
                    Rect.fromLTWH(m.dx - w / 2, m.dy + dy, w, h),
                  ]
                : [
                    Rect.fromLTWH(m.dx + dx, m.dy - h / 2, w, h),
                    Rect.fromLTWH(m.dx - dx - w, m.dy - h / 2, w, h),
                  ];
          }(),
    ];
    segments[seg.id] = SurveyLabel(place(candidates, own: seg.id), tp);
  }

  final risers = <String, SurveyLabel>{};
  for (final n in s.nodes) {
    final riser = surveyNodeRiser(s, n);
    if (riser == null) continue;
    final tp = TextPainter(
      text: TextSpan(
        text: '↕${_num(riser.$2 - riser.$1)} m',
        style: _style(_riser),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = tp.width + 4, h = tp.height + 2;
    final p = at(n);
    const g = 11.0;
    risers[n.id] = SurveyLabel(
      place([
        for (final far in const [0.0, 1.0, 2.0]) ...[
          Rect.fromLTWH(p.dx + g + far * w, p.dy + 4, w, h),
          Rect.fromLTWH(p.dx - g - w - far * w, p.dy + 4, w, h),
          Rect.fromLTWH(p.dx + g + far * w, p.dy - 4 - h, w, h),
          Rect.fromLTWH(p.dx - g - w - far * w, p.dy - 4 - h, w, h),
          Rect.fromLTWH(p.dx - w / 2, p.dy + g + far * h, w, h),
          Rect.fromLTWH(p.dx - w / 2, p.dy - g - h - far * h, w, h),
        ],
      ]),
      tp,
    );
  }
  return SurveyLabels(segments, risers);
}
