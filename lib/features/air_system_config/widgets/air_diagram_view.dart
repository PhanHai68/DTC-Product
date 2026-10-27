import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../diagram/air_diagram.dart';
import '../diagram/air_diagram_render.dart';
import '../providers/air_config_editor_controller.dart';

/// Sơ đồ toàn màn hình (mở từ tab Kết quả): cuộn/phóng to được; mở ra vừa
/// khít chiều ngang.
class AirDiagramView extends StatefulWidget {
  const AirDiagramView({super.key, this.select});

  /// Bản vẽ cần xem; mặc định sơ đồ lắp đặt.
  final AirDiagram? Function(AirConfigEditorController ctrl)? select;

  @override
  State<AirDiagramView> createState() => _AirDiagramViewState();
}

class _AirDiagramViewState extends State<AirDiagramView> {
  final _transform = TransformationController();
  double? _fittedFor;

  @override
  void initState() {
    super.initState();
    // Ảnh thiết bị nạp lần đầu; xong thì vẽ lại (trước đó là ô xám tạm).
    if (!AirDiagramImages.isLoaded) {
      AirDiagramImages.load().then((_) {
        if (mounted) setState(() {});
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _fit(double viewWidth, double diagramWidth) {
    final scale = (viewWidth / diagramWidth).clamp(0.2, 1.5);
    _transform.value = Matrix4.identity()..scaleByDouble(scale, scale, 1, 1);
    _fittedFor = viewWidth * 100000 + diagramWidth;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AirConfigEditorController>();
    final diagram = widget.select?.call(ctrl) ?? ctrl.diagram;
    return LayoutBuilder(
      builder: (context, constraints) {
        final key = constraints.maxWidth * 100000 + diagram.width;
        if (_fittedFor != key) _fit(constraints.maxWidth, diagram.width);
        return Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xFFF1F5F9),
                child: InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  minScale: 0.15,
                  maxScale: 5,
                  boundaryMargin: const EdgeInsets.all(400),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const Key('air_diagram_zoom'),
                      size: Size(diagram.width, diagram.height),
                      painter: AirDiagramPainter(diagram),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'air_diagram_fit',
                tooltip: 'Fit',
                onPressed: () =>
                    setState(() => _fit(constraints.maxWidth, diagram.width)),
                child: const Icon(Icons.fit_screen_rounded),
              ),
            ),
          ],
        );
      },
    );
  }
}
