import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/survey_bom.dart';
import '../engine/survey_geometry.dart';
import '../models/pipe_survey.dart';
import '../providers/pipe_survey_controller.dart';
import 'survey_sheets.dart';

/// Công cụ trên màn vẽ sơ đồ.
enum SurveyTool {
  select('Chọn', Icons.touch_app_outlined),
  pipe('Vẽ ống', Icons.timeline_rounded),
  usePoint('Điểm dùng', Icons.precision_manufacturing_outlined),
  compressor('Cụm máy', Icons.ac_unit_rounded);

  const SurveyTool(this.label, this.icon);
  final String label;
  final IconData icon;

  String get hint => switch (this) {
    SurveyTool.select => 'Chạm vào đoạn ống hoặc điểm để sửa / xoá.',
    SurveyTool.pipe => 'Chạm điểm bắt đầu rồi chạm lần lượt các điểm tiếp theo (ống đi ngang / dọc). Chạm lại điểm cuối hoặc "Kết thúc" để dừng.',
    SurveyTool.usePoint =>
      'Chạm lên ống hoặc chỗ trống để đặt điểm sử dụng khí (máy tách màu…).',
    SurveyTool.compressor => 'Chạm để đặt cụm máy (điểm xuất phát).',
  };
}

/// Sơ đồ tuyến ống trên lưới 1 m (bắt điểm 0,5 m): phóng to / kéo bằng hai
/// ngón, vẽ bằng một ngón theo công cụ đang chọn.
class SurveyCanvas extends StatefulWidget {
  const SurveyCanvas({super.key, required this.ctrl});
  final PipeSurveyController ctrl;

  @override
  State<SurveyCanvas> createState() => _SurveyCanvasState();
}

class _SurveyCanvasState extends State<SurveyCanvas> {
  static const _ppm = 24.0;
  SurveyTool _tool = SurveyTool.pipe;

  /// Điểm đang vẽ ống tiếp (công cụ Vẽ ống).
  String? _drawFrom;

  PipeSurveyController get ctrl => widget.ctrl;
  PipeSurvey get s => ctrl.survey;

  void _setTool(SurveyTool t) => setState(() {
    _tool = t;
    _drawFrom = null;
  });

  Future<void> _tap(Offset local) async {
    final x = local.dx / _ppm, y = local.dy / _ppm;
    switch (_tool) {
      case SurveyTool.select:
        final node = surveyNodeAt(s, x, y);
        if (node != null) {
          await showSurveyNodeSheet(context, ctrl, node.id);
          return;
        }
        final seg = surveySegmentAt(s, x, y);
        if (seg != null) await showSurveySegmentSheet(context, ctrl, seg.$1.id);
      case SurveyTool.pipe:
        final from = _drawFrom == null ? null : s.node(_drawFrom!);
        if (from == null) {
          String? id;
          ctrl.edit((s) => id = surveyNodeForTap(s, x, y).id);
          setState(() => _drawFrom = id);
          return;
        }
        // Chạm lại điểm đang vẽ: kết thúc.
        if (surveyNodeAt(s, x, y)?.id == from.id) {
          setState(() => _drawFrom = null);
          return;
        }
        final (ox, oy) = surveyOrthogonal(from, x, y);
        if ((ox - from.x).abs() < 1e-6 && (oy - from.y).abs() < 1e-6) return;
        String? next;
        ctrl.edit((s) {
          final end = surveyNodeForTap(s, ox, oy);
          surveyAddPipe(s, s.node(from.id)!, end);
          next = end.id;
        });
        setState(() => _drawFrom = next);
      case SurveyTool.usePoint:
        String? id;
        ctrl.edit((s) {
          final n = surveyNodeForTap(s, x, y);
          if (n.kind != SurveyNodeKind.usePoint) {
            n.kind = SurveyNodeKind.usePoint;
            n.name = 'Điểm sử dụng ${s.usePoints.length}';
          }
          id = n.id;
        });
        if (id != null && mounted) {
          await showSurveyNodeSheet(context, ctrl, id!);
        }
      case SurveyTool.compressor:
        ctrl.edit((s) {
          for (final n in s.nodes) {
            if (n.kind == SurveyNodeKind.compressor) {
              n.kind = SurveyNodeKind.junction;
              n.name = '';
            }
          }
          final n = surveyNodeForTap(s, x, y);
          n
            ..kind = SurveyNodeKind.compressor
            ..name = n.name.isEmpty ? 'Cụm máy' : n.name;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxX = s.nodes.fold(0.0, (m, n) => math.max(m, n.x));
    final maxY = s.nodes.fold(0.0, (m, n) => math.max(m, n.y));
    final w = [s.buildingLengthM ?? 0, maxX + 10, 40.0].reduce(math.max);
    final h = [s.buildingWidthM ?? 0, maxY + 10, 30.0].reduce(math.max);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SegmentedButton<SurveyTool>(
                  key: const Key('survey_tools'),
                  showSelectedIcon: false,
                  segments: [
                    for (final t in SurveyTool.values)
                      ButtonSegment(
                        value: t,
                        icon: Icon(t.icon, size: 18),
                        label: Text(t.label),
                      ),
                  ],
                  selected: {_tool},
                  onSelectionChanged: (v) => _setTool(v.first),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const Key('survey_undo'),
                  tooltip: 'Hoàn tác',
                  onPressed: ctrl.canUndo
                      ? () {
                          ctrl.undo();
                          setState(() => _drawFrom = null);
                        }
                      : null,
                  icon: const Icon(Icons.undo_rounded),
                ),
              ],
            ),
          ),
        ),
        // Chiều cao cố định: vùng vẽ không bị đẩy xuống khi hiện "Kết thúc"
        // hay đổi công cụ (chạm tiếp vẫn đúng chỗ).
        Container(
          height: 52,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _tool.hint,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ),
              if (_drawFrom != null)
                TextButton(
                  key: const Key('survey_finish'),
                  onPressed: () => setState(() => _drawFrom = null),
                  child: const Text('Kết thúc'),
                ),
            ],
          ),
        ),
        Expanded(
          child: ClipRect(
            child: ColoredBox(
              color: const Color(0xFFF8FAFC),
              child: InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(120),
                minScale: 0.2,
                maxScale: 5,
                child: GestureDetector(
                  key: const Key('survey_canvas'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _tap(d.localPosition),
                  child: CustomPaint(
                    size: Size(w * _ppm, h * _ppm),
                    painter: SurveyPainter(
                      survey: s,
                      ppm: _ppm,
                      widthM: w,
                      heightM: h,
                      drawFrom: _drawFrom,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Vẽ lưới, tường bao, đoạn ống (chiều dài, cỡ khác mặc định), cụm máy và
/// điểm sử dụng. Dùng chung cho màn hình và ảnh xuất PDF.
class SurveyPainter extends CustomPainter {
  SurveyPainter({
    required this.survey,
    required this.ppm,
    required this.widthM,
    required this.heightM,
    this.drawFrom,
    this.showGrid = true,
  });

  final PipeSurvey survey;
  final double ppm;
  final double widthM;
  final double heightM;
  final String? drawFrom;
  final bool showGrid;

  static const _pipe = Color(0xFF1F4E9D);
  static const _point = Color(0xFFEA580C);
  static const _compressor = Color(0xFF15803D);

  @override
  void paint(Canvas canvas, Size size) {
    final s = survey;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    if (showGrid) {
      final minor = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..strokeWidth = 0.6;
      final major = Paint()
        ..color = const Color(0xFFCBD5E1)
        ..strokeWidth = 1.1;
      for (var i = 0; i <= widthM.ceil(); i++) {
        canvas.drawLine(
          Offset(i * ppm, 0),
          Offset(i * ppm, size.height),
          i % 5 == 0 ? major : minor,
        );
        if (i % 5 == 0 && i > 0) {
          _text(
            canvas,
            '$i m',
            Offset(i * ppm + 2, 2),
            9,
            const Color(0xFF94A3B8),
          );
        }
      }
      for (var j = 0; j <= heightM.ceil(); j++) {
        canvas.drawLine(
          Offset(0, j * ppm),
          Offset(size.width, j * ppm),
          j % 5 == 0 ? major : minor,
        );
        if (j % 5 == 0 && j > 0) {
          _text(
            canvas,
            '$j m',
            Offset(2, j * ppm + 2),
            9,
            const Color(0xFF94A3B8),
          );
        }
      }
    }
    // Tường bao nhà xưởng.
    final bl = s.buildingLengthM, bw = s.buildingWidthM;
    if (bl != null && bw != null && bl > 0 && bw > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, bl * ppm, bw * ppm),
        Paint()
          ..color = const Color(0xFF334155)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    // Đoạn ống.
    for (final seg in s.segments) {
      final a = s.node(seg.a), b = s.node(seg.b);
      if (a == null || b == null) continue;
      final dn = seg.dn ?? s.defaultDn;
      final pa = Offset(a.x * ppm, a.y * ppm),
          pb = Offset(b.x * ppm, b.y * ppm);
      canvas.drawLine(
        pa,
        pb,
        Paint()
          ..color = _pipe
          ..strokeWidth = (2 + dn / 20).clamp(2.5, 6.0)
          ..strokeCap = StrokeCap.round,
      );
      final len = seg.measuredM ?? surveySegmentDrawnLength(a, b);
      final label = [
        '${_num(len)} m${seg.measuredM != null ? '*' : ''}',
        if (seg.dn != null && seg.dn != s.defaultDn) 'DN${seg.dn}',
      ].join(' · ');
      final mid = (pa + pb) / 2;
      final vertical = (a.x - b.x).abs() < 1e-6;
      _text(
        canvas,
        label,
        vertical ? mid.translate(6, -7) : mid.translate(-14, -17),
        10,
        _pipe,
        bold: true,
        background: true,
      );
    }
    // Điểm.
    for (final n in s.nodes) {
      final p = Offset(n.x * ppm, n.y * ppm);
      switch (n.kind) {
        case SurveyNodeKind.junction:
          canvas.drawCircle(p, 3.5, Paint()..color = _pipe);
        case SurveyNodeKind.compressor:
          final r = RRect.fromRectAndRadius(
            Rect.fromCenter(center: p, width: 26, height: 20),
            const Radius.circular(4),
          );
          canvas.drawRRect(r, Paint()..color = _compressor);
          _text(
            canvas,
            'MN',
            p.translate(-8, -6),
            10,
            Colors.white,
            bold: true,
          );
          _text(
            canvas,
            n.name.isEmpty ? 'Cụm máy' : n.name,
            p.translate(15, 4),
            11,
            _compressor,
            bold: true,
            background: true,
          );
        case SurveyNodeKind.usePoint:
          canvas.drawCircle(p, 8, Paint()..color = _point);
          canvas.drawCircle(p, 3, Paint()..color = Colors.white);
          _text(
            canvas,
            n.name,
            p.translate(11, 4),
            11,
            _point,
            bold: true,
            background: true,
          );
          if (n.photos.isNotEmpty) {
            _text(canvas, '📷', p.translate(-7, -24), 11, _point);
          }
      }
      if (n.id == drawFrom) {
        canvas.drawCircle(
          p,
          12,
          Paint()
            ..color = const Color(0xFFF59E0B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
    }
  }

  static String _num(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble()
        ? '${r.round()}'
        : r.toStringAsFixed(1).replaceAll('.', ',');
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    double size,
    Color color, {
    bool bold = false,
    bool background = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (background) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(at.dx - 2, at.dy - 1, tp.width + 4, tp.height + 2),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(SurveyPainter old) => true;
}
