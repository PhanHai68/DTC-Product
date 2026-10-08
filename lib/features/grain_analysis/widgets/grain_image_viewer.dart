import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/homography.dart';
import '../models/analysis_session.dart';
import '../models/grain.dart';

/// Màu và ký hiệu đánh dấu. Mỗi loại có ký hiệu riêng (chấm, số, ✕, +) để
/// không chỉ phân biệt bằng màu (NFR-10).
abstract final class GrainMarkStyle {
  static const grain = Color(0xFF2EE87A);
  static const cluster = Color(0xFFFFA726);
  static const removed = Color(0xFFFF5252);
  static const manual = Color(0xFF40C4FF);
}

/// Ảnh gốc + viền từng hạt vẽ lại từ dữ liệu [Grain] (NFR-06). Phóng to bằng
/// hai ngón; chạm một lần gọi [onTapImage] với tọa độ trên KHUNG ĐÃ NẮN.
class GrainImageViewer extends StatefulWidget {
  const GrainImageViewer({
    super.key,
    required this.imagePath,
    required this.image,
    required this.grains,
    this.onTapImage,
  });

  final String imagePath;
  final SessionImage image;
  final List<Grain> grains;
  final ValueChanged<Offset>? onTapImage;

  @override
  State<GrainImageViewer> createState() => _GrainImageViewerState();
}

class _GrainImageViewerState extends State<GrainImageViewer> {
  final _transform = TransformationController();
  late Homography _toImage;
  Homography? _toFrame;
  List<_Shape> _shapes = const [];

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(GrainImageViewer old) {
    super.didUpdateWidget(old);
    if (!identical(old.grains, widget.grains) ||
        !identical(old.image, widget.image)) {
      _rebuild();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// Đổi viền hạt sang tọa độ ảnh gốc một lần, không làm trong paint().
  void _rebuild() {
    _toImage = Homography(widget.image.frameToImage);
    _toFrame = _toImage.inverse();
    _shapes = [for (final g in widget.grains) _Shape.from(g, _toImage)];
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.image;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.maxWidth / img.width,
          constraints.maxHeight / img.height,
        );
        final w = img.width * scale, h = img.height * scale;
        return ClipRect(
          child: InteractiveViewer(
            transformationController: _transform,
            maxScale: 12,
            child: Center(
              child: SizedBox(
                width: w,
                height: h,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: widget.onTapImage == null || _toFrame == null
                      ? null
                      : (d) {
                          final p = _toFrame!.apply(
                            d.localPosition.dx / scale,
                            d.localPosition.dy / scale,
                          );
                          widget.onTapImage!(Offset(p[0], p[1]));
                        },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: Colors.black12,
                          child: Center(child: Text('Không mở được ảnh')),
                        ),
                      ),
                      CustomPaint(
                        painter: _OverlayPainter(_shapes, scale, _transform),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Shape {
  _Shape(this.grain, this.path, this.center, this.radius);

  factory _Shape.from(Grain g, Homography toImage) {
    final path = Path();
    final c = g.contour;
    for (var i = 0; i + 1 < c.length; i += 2) {
      final p = toImage.apply(c[i], c[i + 1]);
      if (i == 0) {
        path.moveTo(p[0], p[1]);
      } else {
        path.lineTo(p[0], p[1]);
      }
    }
    path.close();
    final center = toImage.apply(g.centroidX, g.centroidY);
    final bounds = path.getBounds();
    return _Shape(
      g,
      path,
      Offset(center[0], center[1]),
      math.max(2, math.min(bounds.width, bounds.height) / 2),
    );
  }

  final Grain grain;
  final Path path;
  final Offset center;
  final double radius;
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.shapes, this.scale, this.transform)
    : super(repaint: transform);

  final List<_Shape> shapes;
  final double scale;
  final TransformationController transform;

  @override
  void paint(Canvas canvas, Size size) {
    // Nét vẽ giữ độ dày ~1,5 px trên màn hình ở mọi mức phóng.
    final zoom = transform.value.getMaxScaleOnAxis();
    final unit = 1 / (scale * zoom);
    canvas.save();
    canvas.scale(scale);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * unit;
    final fill = Paint()..style = PaintingStyle.fill;
    for (final s in shapes) {
      final g = s.grain;
      final color = g.removed
          ? GrainMarkStyle.removed
          : g.source == GrainSource.manual
          ? GrainMarkStyle.manual
          : g.isCluster
          ? GrainMarkStyle.cluster
          : GrainMarkStyle.grain;
      stroke.color = color.withValues(alpha: g.removed ? 0.7 : 0.95);
      if (g.source != GrainSource.manual) canvas.drawPath(s.path, stroke);
      if (g.removed) {
        // Dấu ✕
        final r = s.radius * 0.8;
        final x = Paint()
          ..color = GrainMarkStyle.removed
          ..strokeWidth = 2.5 * unit;
        canvas
          ..drawLine(s.center + Offset(-r, -r), s.center + Offset(r, r), x)
          ..drawLine(s.center + Offset(-r, r), s.center + Offset(r, -r), x);
      } else if (g.source == GrainSource.manual) {
        // Dấu + trong vòng tròn
        final r = s.radius;
        canvas.drawCircle(s.center, r, stroke);
        final plus = Paint()
          ..color = GrainMarkStyle.manual
          ..strokeWidth = 2 * unit;
        canvas
          ..drawLine(
            s.center + Offset(-r * 0.6, 0),
            s.center + Offset(r * 0.6, 0),
            plus,
          )
          ..drawLine(
            s.center + Offset(0, -r * 0.6),
            s.center + Offset(0, r * 0.6),
            plus,
          );
      } else if (g.isCluster) {
        // Số hạt ước tính của cụm
        final tp = TextPainter(
          text: TextSpan(
            text: '${g.estimatedCount}',
            style: TextStyle(
              color: Colors.black,
              fontSize: 12 * unit,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final r = math.max(tp.width, tp.height) * 0.65;
        fill.color = GrainMarkStyle.cluster;
        canvas.drawCircle(s.center, r, fill);
        tp.paint(canvas, s.center - Offset(tp.width / 2, tp.height / 2));
      } else {
        // Chấm đánh dấu hạt đã đếm
        fill.color = color;
        canvas.drawCircle(s.center, 2.2 * unit, fill);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      !identical(old.shapes, shapes) || old.scale != scale;
}

/// Chú thích ký hiệu dưới ảnh.
class GrainLegend extends StatelessWidget {
  const GrainLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    Widget item(Widget mark, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 4),
        Text(text, style: style),
      ],
    );
    Widget dot(Color c, {String? label}) => Container(
      width: label == null ? 10 : 18,
      height: label == null ? 10 : 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      child: label == null
          ? null
          : Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
    );
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        item(dot(GrainMarkStyle.grain), 'Hạt đã đếm'),
        item(dot(GrainMarkStyle.cluster, label: '3'), 'Cụm (số hạt ước tính)'),
        item(
          const Icon(
            Icons.close_rounded,
            size: 16,
            color: GrainMarkStyle.removed,
          ),
          'Đã xóa',
        ),
        item(
          const Icon(
            Icons.add_circle_outline_rounded,
            size: 16,
            color: GrainMarkStyle.manual,
          ),
          'Thêm tay',
        ),
      ],
    );
  }
}
