import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/site_layout_models.dart';
import '../services/layout_geometry_service.dart';

class LayoutCanvas extends StatefulWidget {
  const LayoutCanvas({
    super.key,
    required this.bundle,
    required this.tool,
    required this.gridMm,
    required this.snapToGrid,
    required this.showClearance,
    required this.selectedId,
    required this.warnings,
    required this.onSelect,
    required this.onAddObject,
    this.onAddLine,
    required this.onTransformStart,
    required this.onMoveUpdate,
    required this.onResizeUpdate,
    this.onRotateUpdate,
    required this.onTransformEnd,
    this.onTrimObject,
    required this.onAddMeasurement,
    required this.onAddNote,
    required this.onAddPhotoMarker,
    this.activeSnapPoint,
    this.onEditSelected,
  });

  final SiteLayoutBundle bundle;
  final EditorTool tool;
  final double gridMm;
  final bool snapToGrid;
  final bool showClearance;
  final String? selectedId;
  final List<LayoutWarning> warnings;
  final ValueChanged<String?> onSelect;
  final void Function(SiteObjectType type, double xMm, double yMm) onAddObject;
  final bool Function(String id) onTransformStart;
  final void Function(double dxMm, double dyMm) onMoveUpdate;
  final void Function(
    LayoutResizeHandle handle,
    double pointerXMm,
    double pointerYMm,
  )
  onResizeUpdate;
  final void Function(double pointerXMm, double pointerYMm)? onRotateUpdate;
  final VoidCallback onTransformEnd;
  final void Function(String id, double tapXMm, double tapYMm)? onTrimObject;
  final void Function(double x1, double y1, double x2, double y2)
  onAddMeasurement;
  final void Function(double xMm, double yMm) onAddNote;
  final Future<void> Function(double xMm, double yMm) onAddPhotoMarker;
  final void Function(double x1Mm, double y1Mm, double x2Mm, double y2Mm)?
  onAddLine;
  final math.Point<double>? activeSnapPoint;
  final VoidCallback? onEditSelected;

  @override
  State<LayoutCanvas> createState() => _LayoutCanvasState();
}

class _LayoutCanvasState extends State<LayoutCanvas> {
  static const _pixelsPerMm = 0.08;
  final TransformationController _transformation = TransformationController();
  Offset? _measureStart;
  Offset? _draftLineStart;
  Offset? _draftLineEnd;
  Offset? _draftPhotoMarker;
  Offset? _pointerDown;
  Offset? _dragStart;
  Offset? _dragCurrent;
  LayoutResizeHandle? _activeHandle;
  bool _activeRotation = false;
  double _viewScale = 1;

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_handleViewChanged);
  }

  @override
  void dispose() {
    _transformation.removeListener(_handleViewChanged);
    _transformation.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LayoutCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tool != widget.tool) {
      _draftLineStart = null;
      _draftLineEnd = null;
      _draftPhotoMarker = null;
    }
  }

  void _handleViewChanged() {
    final scale = _transformation.value.getMaxScaleOnAxis();
    if ((scale - _viewScale).abs() > 0.01 && mounted) {
      setState(() => _viewScale = scale);
    }
  }

  Size get _sceneSize => Size(
    math.max(400, widget.bundle.project.siteWidthMm * _pixelsPerMm),
    math.max(400, widget.bundle.project.siteLengthMm * _pixelsPerMm),
  );

  Offset _toMm(Offset local) =>
      Offset(local.dx / _pixelsPerMm, local.dy / _pixelsPerMm);

  @override
  Widget build(BuildContext context) {
    final sceneSize = _sceneSize;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Stack(
        children: [
          InteractiveViewer(
            transformationController: _transformation,
            constrained: false,
            minScale: 0.15,
            maxScale: 8,
            panEnabled: widget.tool == EditorTool.pan,
            scaleEnabled: widget.tool == EditorTool.pan,
            boundaryMargin: const EdgeInsets.all(600),
            child: CustomPaint(
              size: sceneSize,
              painter: SiteLayoutPainter(
                bundle: widget.bundle,
                pixelsPerMm: _pixelsPerMm,
                gridMm: widget.gridMm,
                selectedId: widget.selectedId,
                showClearance: widget.showClearance,
                warningIds: widget.warnings
                    .map((warning) => warning.subjectId)
                    .whereType<String>()
                    .toSet(),
                draftMeasurementStart: _measureStart,
                draftLineStart: _draftLineStart,
                draftLineEnd: _draftLineEnd,
                draftPhotoMarker: _draftPhotoMarker,
                viewScale: _viewScale,
                activeSnapPoint: widget.activeSnapPoint,
              ),
            ),
          ),
          if (widget.tool != EditorTool.pan)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _handleTap,
                onPanDown: switch (widget.tool) {
                  EditorTool.select => _rememberPointerDown,
                  EditorTool.line => _startDraftLine,
                  EditorTool.photoMarker => _startDraftPhotoMarker,
                  _ => null,
                },
                onPanStart: switch (widget.tool) {
                  EditorTool.select => _startDrag,
                  EditorTool.line => _startDraftLineDrag,
                  EditorTool.photoMarker => _startDraftPhotoMarkerDrag,
                  _ => null,
                },
                onPanUpdate: switch (widget.tool) {
                  EditorTool.select => _updateDrag,
                  EditorTool.line => _updateDraftLine,
                  EditorTool.photoMarker => _updateDraftPhotoMarker,
                  _ => null,
                },
                onPanEnd: switch (widget.tool) {
                  EditorTool.select => _endDrag,
                  EditorTool.line => _finishDraftLine,
                  EditorTool.photoMarker => _finishDraftPhotoMarker,
                  _ => null,
                },
                onPanCancel: switch (widget.tool) {
                  EditorTool.select => _cancelDrag,
                  EditorTool.line || EditorTool.photoMarker => _cancelDraft,
                  _ => null,
                },
              ),
            ),
          if (widget.selectedId != null && widget.onEditSelected != null)
            Positioned(
              top: 12,
              right: 12,
              child: FilledButton.tonalIcon(
                onPressed: widget.onEditSelected,
                icon: const Icon(Icons.straighten_rounded, size: 18),
                label: const Text('Nhập kích thước'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 42),
                ),
              ),
            ),
          Positioned(
            left: 12,
            bottom: 12,
            child: _ScaleLegend(
              gridMm: widget.gridMm,
              unit: widget.bundle.project.dimensionUnit,
              snapEnabled: widget.snapToGrid,
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: 'site_layout_reset_view',
              tooltip: 'Vừa toàn bộ mặt bằng',
              onPressed: () => _fitView(context, sceneSize),
              child: const Icon(Icons.fit_screen_rounded),
            ),
          ),
        ],
      ),
    );
  }

  void _fitView(BuildContext context, Size sceneSize) {
    final viewport = context.size;
    if (viewport == null) return;
    final scale = math
        .min(
          viewport.width / sceneSize.width,
          viewport.height / sceneSize.height,
        )
        .clamp(0.15, 4.0);
    final dx = (viewport.width - sceneSize.width * scale) / 2;
    final dy = (viewport.height - sceneSize.height * scale) / 2;
    _transformation.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setTranslationRaw(dx, dy, 0);
  }

  void _handleTap(TapUpDetails details) {
    final scenePosition = _toScene(details.localPosition);
    final mm = _toMm(scenePosition);
    switch (widget.tool) {
      case EditorTool.select:
        widget.onSelect(_hitTest(mm));
      case EditorTool.pan:
        break;
      case EditorTool.wall:
        widget.onAddObject(SiteObjectType.wall, mm.dx, mm.dy);
      case EditorTool.column:
        widget.onAddObject(SiteObjectType.column, mm.dx, mm.dy);
      case EditorTool.door:
        widget.onAddObject(SiteObjectType.door, mm.dx, mm.dy);
      case EditorTool.bucketElevator:
        widget.onAddObject(SiteObjectType.bucketElevator, mm.dx, mm.dy);
      case EditorTool.walkway:
        widget.onAddObject(SiteObjectType.walkway, mm.dx, mm.dy);
      case EditorTool.line:
        _cancelDraft();
      case EditorTool.restrictedArea:
        widget.onAddObject(SiteObjectType.restrictedArea, mm.dx, mm.dy);
      case EditorTool.obstacle:
        widget.onAddObject(SiteObjectType.obstacle, mm.dx, mm.dy);
      case EditorTool.existingMachine:
        widget.onAddObject(SiteObjectType.existingMachine, mm.dx, mm.dy);
      case EditorTool.trim:
        final id = _hitTest(mm);
        if (id != null) widget.onTrimObject?.call(id, mm.dx, mm.dy);
      case EditorTool.measure:
        if (_measureStart == null) {
          setState(() => _measureStart = scenePosition);
        } else {
          final first = _toMm(_measureStart!);
          widget.onAddMeasurement(first.dx, first.dy, mm.dx, mm.dy);
          setState(() => _measureStart = null);
        }
      case EditorTool.note:
        widget.onAddNote(mm.dx, mm.dy);
      case EditorTool.photoMarker:
        _commitPhotoMarker(scenePosition);
    }
  }

  void _startDraftLine(DragDownDetails details) {
    final point = _toScene(details.localPosition);
    setState(() {
      _draftLineStart = point;
      _draftLineEnd = point;
    });
  }

  void _updateDraftLine(DragUpdateDetails details) {
    setState(() => _draftLineEnd = _toScene(details.localPosition));
  }

  void _startDraftLineDrag(DragStartDetails details) {
    setState(() => _draftLineEnd = _toScene(details.localPosition));
  }

  void _finishDraftLine(DragEndDetails details) {
    final start = _draftLineStart;
    final end = _draftLineEnd;
    if (start != null && end != null && (end - start).distance >= 4) {
      final startMm = _toMm(start);
      final endMm = _toMm(end);
      widget.onAddLine?.call(startMm.dx, startMm.dy, endMm.dx, endMm.dy);
    }
    _cancelDraft();
  }

  void _startDraftPhotoMarker(DragDownDetails details) {
    setState(() => _draftPhotoMarker = _toScene(details.localPosition));
  }

  void _updateDraftPhotoMarker(DragUpdateDetails details) {
    setState(() => _draftPhotoMarker = _toScene(details.localPosition));
  }

  void _startDraftPhotoMarkerDrag(DragStartDetails details) {
    setState(() => _draftPhotoMarker = _toScene(details.localPosition));
  }

  void _finishDraftPhotoMarker(DragEndDetails details) {
    final point = _draftPhotoMarker;
    if (point != null) _commitPhotoMarker(point);
  }

  Future<void> _commitPhotoMarker(Offset scenePosition) async {
    setState(() => _draftPhotoMarker = scenePosition);
    final mm = _toMm(scenePosition);
    await widget.onAddPhotoMarker(mm.dx, mm.dy);
    if (mounted) setState(() => _draftPhotoMarker = null);
  }

  void _cancelDraft() {
    if (!mounted) return;
    setState(() {
      _draftLineStart = null;
      _draftLineEnd = null;
      _draftPhotoMarker = null;
    });
  }

  void _startDrag(DragStartDetails details) {
    final initialPosition = _toScene(_pointerDown ?? details.localPosition);
    final rotating = _hitTestRotationHandle(initialPosition);
    final handle = rotating ? null : _hitTestHandle(initialPosition);
    final id = handle == null && !rotating
        ? _hitTest(_toMm(initialPosition))
        : widget.selectedId;
    widget.onSelect(id);
    if (id != null && widget.onTransformStart(id)) {
      setState(() {
        _dragStart = initialPosition;
        _dragCurrent = initialPosition;
        _activeHandle = handle;
        _activeRotation = rotating;
      });
    }
  }

  void _rememberPointerDown(DragDownDetails details) {
    _pointerDown = details.localPosition;
  }

  void _updateDrag(DragUpdateDetails details) {
    if (_dragStart == null) return;
    _dragCurrent = _toScene(details.localPosition);
    if (_activeRotation) {
      final pointer = _toMm(_dragCurrent!);
      widget.onRotateUpdate?.call(pointer.dx, pointer.dy);
      return;
    }
    final handle = _activeHandle;
    if (handle == null) {
      final delta = (_dragCurrent! - _dragStart!) / _pixelsPerMm;
      widget.onMoveUpdate(delta.dx, delta.dy);
    } else {
      final pointer = _toMm(_dragCurrent!);
      widget.onResizeUpdate(handle, pointer.dx, pointer.dy);
    }
  }

  void _endDrag(DragEndDetails details) {
    if (_dragStart != null) widget.onTransformEnd();
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
      _pointerDown = null;
      _activeHandle = null;
      _activeRotation = false;
    });
  }

  void _cancelDrag() {
    if (_dragStart != null) widget.onTransformEnd();
    setState(() {
      _dragStart = null;
      _dragCurrent = null;
      _pointerDown = null;
      _activeHandle = null;
      _activeRotation = false;
    });
  }

  bool _hitTestRotationHandle(Offset localPosition) {
    final id = widget.selectedId;
    if (id == null) return false;
    for (final object in widget.bundle.objects) {
      if (object.id == id && !object.isLocked) {
        return (localPosition - _objectRotationHandle(object)).distance <=
            24 / math.max(0.15, _viewScale);
      }
    }
    for (final machine in widget.bundle.machines) {
      if (machine.id == id && !machine.isLocked) {
        return (localPosition - _machineRotationHandle(machine)).distance <=
            24 / math.max(0.15, _viewScale);
      }
    }
    return false;
  }

  Offset _objectRotationHandle(SiteLayoutObject object) {
    final center = LayoutGeometryService.objectCenter(object);
    final gapMm = 34 / math.max(0.15, _viewScale) / _pixelsPerMm;
    final point = LayoutGeometryService.localToWorld(
      center,
      0,
      -object.lengthMm / 2 - gapMm,
      object.rotationDeg,
    );
    return Offset(_px(point.x), _px(point.y));
  }

  Offset _machineRotationHandle(MachinePlacement machine) {
    final center = LayoutGeometryService.machineCenter(machine);
    final gapMm = 34 / math.max(0.15, _viewScale) / _pixelsPerMm;
    final point = LayoutGeometryService.localToWorld(
      center,
      0,
      -machine.lengthMm / 2 - gapMm,
      machine.rotationDeg,
    );
    return Offset(_px(point.x), _px(point.y));
  }

  LayoutResizeHandle? _hitTestHandle(Offset localPosition) {
    final id = widget.selectedId;
    if (id == null) return null;
    for (final measurement in widget.bundle.measurements) {
      if (measurement.id != id) continue;
      final radius = 24 / math.max(0.15, _viewScale);
      final start = Offset(_px(measurement.x1Mm), _px(measurement.y1Mm));
      final end = Offset(_px(measurement.x2Mm), _px(measurement.y2Mm));
      if ((localPosition - start).distance <= radius) {
        return LayoutResizeHandle.leftEnd;
      }
      if ((localPosition - end).distance <= radius) {
        return LayoutResizeHandle.rightEnd;
      }
      return null;
    }
    SiteLayoutObject? selected;
    for (final object in widget.bundle.objects) {
      if (object.id == id) selected = object;
    }
    if (selected == null || selected.isLocked) return null;
    final handles = selected.type.isLinear
        ? const [LayoutResizeHandle.leftEnd, LayoutResizeHandle.rightEnd]
        : const [
            LayoutResizeHandle.topLeft,
            LayoutResizeHandle.topRight,
            LayoutResizeHandle.bottomRight,
            LayoutResizeHandle.bottomLeft,
          ];
    final touchRadius = 24 / math.max(0.15, _viewScale);
    for (final handle in handles) {
      final point = LayoutGeometryService.objectHandlePoint(selected, handle);
      final local = Offset(_px(point.x), _px(point.y));
      if ((localPosition - local).distance <= touchRadius) return handle;
    }
    return null;
  }

  double _px(double mm) => mm * _pixelsPerMm;

  Offset _toScene(Offset viewportPosition) =>
      _transformation.toScene(viewportPosition);

  String? _hitTest(Offset mm) {
    for (final marker in widget.bundle.photoMarkers.reversed) {
      if ((Offset(marker.xMm, marker.yMm) - mm).distance <= 220) {
        return marker.id;
      }
    }
    for (final annotation in widget.bundle.annotations.reversed) {
      if ((Offset(annotation.xMm, annotation.yMm) - mm).distance <= 220) {
        return annotation.id;
      }
    }
    for (final measurement in widget.bundle.measurements.reversed) {
      if (_distanceToSegment(
            mm,
            Offset(measurement.x1Mm, measurement.y1Mm),
            Offset(measurement.x2Mm, measurement.y2Mm),
          ) <=
          140) {
        return measurement.id;
      }
    }
    for (final machine in widget.bundle.machines.reversed) {
      if (LayoutGeometryService.containsMachine(
        machine,
        math.Point(mm.dx, mm.dy),
      )) {
        return machine.id;
      }
    }
    for (final object in widget.bundle.objects.reversed) {
      final isLinear = object.type.isLinear;
      if (isLinear) {
        final start = LayoutGeometryService.objectHandlePoint(
          object,
          LayoutResizeHandle.leftEnd,
        );
        final end = LayoutGeometryService.objectHandlePoint(
          object,
          LayoutResizeHandle.rightEnd,
        );
        final minimumTouchMm = (28 / math.max(0.15, _viewScale)) / _pixelsPerMm;
        final startOffset = Offset(start.x, start.y);
        final endOffset = Offset(end.x, end.y);
        final touchDistance = math.max(object.lengthMm / 2, minimumTouchMm);
        final touchesCenterLine =
            _distanceToSegment(mm, startOffset, endOffset) <= touchDistance;
        final touchesDoorSymbol =
            object.type == SiteObjectType.door &&
            _hitDoorSymbol(mm, startOffset, endOffset, touchDistance);
        if (touchesCenterLine || touchesDoorSymbol) {
          return object.id;
        }
        continue;
      }
      if (LayoutGeometryService.containsObject(
        object,
        math.Point(mm.dx, mm.dy),
      )) {
        return object.id;
      }
    }
    return null;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared == 0) return (point - start).distance;
    final t =
        (((point.dx - start.dx) * segment.dx +
                    (point.dy - start.dy) * segment.dy) /
                lengthSquared)
            .clamp(0.0, 1.0);
    final projection = start + segment * t;
    return (point - projection).distance;
  }

  bool _hitDoorSymbol(
    Offset point,
    Offset start,
    Offset end,
    double touchDistance,
  ) {
    final vector = end - start;
    final openingWidth = vector.distance;
    if (openingWidth <= 0) return false;
    final direction = vector / openingWidth;
    final radius = openingWidth * 0.42;
    const sweepAngle = math.pi / 3;
    final leafDirection = Offset(
      direction.dx * math.cos(sweepAngle) - direction.dy * math.sin(sweepAngle),
      direction.dx * math.sin(sweepAngle) + direction.dy * math.cos(sweepAngle),
    );
    final leafEnd = start + leafDirection * radius;
    if (_distanceToSegment(point, start, leafEnd) <= touchDistance) {
      return true;
    }
    final pointVector = point - start;
    if ((pointVector.distance - radius).abs() > touchDistance) return false;
    final startAngle = math.atan2(vector.dy, vector.dx);
    final pointAngle = math.atan2(pointVector.dy, pointVector.dx);
    final sweep = (pointAngle - startAngle) % (math.pi * 2);
    return sweep >= 0 && sweep <= sweepAngle;
  }
}

class SiteLayoutPainter extends CustomPainter {
  const SiteLayoutPainter({
    required this.bundle,
    required this.pixelsPerMm,
    required this.gridMm,
    required this.selectedId,
    required this.showClearance,
    required this.warningIds,
    this.draftMeasurementStart,
    this.draftLineStart,
    this.draftLineEnd,
    this.draftPhotoMarker,
    this.viewScale = 1,
    this.forExport = false,
    this.renderScale = 1,
    this.activeSnapPoint,
  });

  final SiteLayoutBundle bundle;
  final double pixelsPerMm;
  final double gridMm;
  final String? selectedId;
  final bool showClearance;
  final Set<String> warningIds;
  final Offset? draftMeasurementStart;
  final Offset? draftLineStart;
  final Offset? draftLineEnd;
  final Offset? draftPhotoMarker;
  final double viewScale;
  final bool forExport;
  final double renderScale;
  final math.Point<double>? activeSnapPoint;

  double _px(double mm) => mm * pixelsPerMm;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFFDFEFE),
    );
    _drawGrid(canvas, size);
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        _px(bundle.project.siteWidthMm),
        _px(bundle.project.siteLengthMm),
      ),
      Paint()
        ..color = const Color(0xFF0A2740)
        ..style = PaintingStyle.stroke
        ..strokeWidth = forExport ? renderScale : 2,
    );
    _drawSiteDimensions(canvas);
    for (final object in bundle.objects) {
      _drawObject(canvas, object);
    }
    for (final machine in bundle.machines) {
      _drawMachine(canvas, machine);
    }
    for (final measurement in bundle.measurements) {
      _drawMeasurement(canvas, measurement);
    }
    for (final annotation in bundle.annotations) {
      _drawMarker(
        canvas,
        Offset(_px(annotation.xMm), _px(annotation.yMm)),
        annotation.markerNumber?.toString() ?? 'N',
        const Color(0xFF7C3AED),
      );
    }
    for (final marker in bundle.photoMarkers) {
      _drawMarker(
        canvas,
        Offset(_px(marker.xMm), _px(marker.yMm)),
        marker.markerNumber.toString(),
        const Color(0xFFEA580C),
      );
    }
    if (!forExport && activeSnapPoint != null) {
      _drawActiveSnapPoint(canvas, activeSnapPoint!);
    }
    if (draftMeasurementStart != null) {
      canvas.drawCircle(
        draftMeasurementStart!,
        7,
        Paint()..color = const Color(0xFF007F7A),
      );
    }
    if (draftLineStart != null && draftLineEnd != null) {
      canvas.drawLine(
        draftLineStart!,
        draftLineEnd!,
        Paint()
          ..color = const Color(0xFF334155)
          ..strokeWidth = math.max(1.0, _px(50) / 2)
          ..strokeCap = StrokeCap.round,
      );
    }
    if (draftPhotoMarker != null) {
      _drawMarker(canvas, draftPhotoMarker!, '+', const Color(0xFFEA580C));
    }
  }

  void _drawSiteDimensions(Canvas canvas) {
    final visualScale = forExport ? renderScale : 1 / math.max(0.4, viewScale);
    final widthText = 'Mặt bằng: ${_dimension(bundle.project.siteWidthMm)}';
    final lengthText = _dimension(bundle.project.siteLengthMm);
    _drawCenteredDimensionText(
      canvas,
      widthText,
      Offset(
        _px(bundle.project.siteWidthMm / 2),
        10 * bundle.project.dimensionTextScale * visualScale,
      ),
      color: const Color(0xFF0A2740),
      fontSize: 10 * bundle.project.dimensionTextScale * visualScale,
    );
    canvas.save();
    canvas.translate(
      12 * bundle.project.dimensionTextScale * visualScale,
      _px(bundle.project.siteLengthMm / 2),
    );
    canvas.rotate(-math.pi / 2);
    _drawCenteredDimensionText(
      canvas,
      lengthText,
      Offset.zero,
      color: const Color(0xFF0A2740),
      fontSize: 10 * bundle.project.dimensionTextScale * visualScale,
    );
    canvas.restore();
  }

  void _drawActiveSnapPoint(Canvas canvas, math.Point<double> point) {
    final scale = math.max(0.15, viewScale);
    final center = Offset(_px(point.x), _px(point.y));
    final radius = 9 / scale;
    final paint = Paint()
      ..color = const Color(0xFF00A6A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / scale;
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius, paint);
    canvas.drawLine(
      center - Offset(radius + 4 / scale, 0),
      center + Offset(radius + 4 / scale, 0),
      paint,
    );
    canvas.drawLine(
      center - Offset(0, radius + 4 / scale),
      center + Offset(0, radius + 4 / scale),
      paint,
    );
  }

  void _drawGrid(Canvas canvas, Size size) {
    final spacing = _px(gridMm);
    if (spacing < 3) return;
    final paint = Paint()
      ..color = const Color(0xFFDCE7EB)
      ..strokeWidth = forExport ? 0.25 * renderScale : 0.7;
    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawObject(Canvas canvas, SiteLayoutObject object) {
    final color = switch (object.type) {
      SiteObjectType.wall => const Color(0xFF455A64),
      SiteObjectType.column => const Color(0xFF37474F),
      SiteObjectType.door => const Color(0xFF795548),
      SiteObjectType.bucketElevator => const Color(0xFF7C3AED),
      SiteObjectType.walkway => const Color(0xFF0284C7),
      SiteObjectType.line => const Color(0xFF334155),
      SiteObjectType.restrictedArea => const Color(0xFFDC2626),
      SiteObjectType.existingMachine => const Color(0xFF64748B),
      SiteObjectType.obstacle => const Color(0xFFF59E0B),
    };
    final isLinear = object.type.isLinear;
    if (isLinear) {
      _drawLinearObject(canvas, object, color);
      return;
    }
    final center = LayoutGeometryService.objectCenter(object);
    final centerPx = Offset(_px(center.x), _px(center.y));
    final localRect = Rect.fromCenter(
      center: Offset.zero,
      width: _px(object.widthMm),
      height: _px(object.lengthMm),
    );
    canvas.save();
    canvas.translate(centerPx.dx, centerPx.dy);
    canvas.rotate(object.rotationDeg * math.pi / 180);
    canvas.drawRect(
      localRect,
      Paint()
        ..color = color.withValues(
          alpha: object.type == SiteObjectType.column ? 0.46 : 0.28,
        ),
    );
    canvas.drawRect(
      localRect,
      Paint()
        ..color = object.id == selectedId ? const Color(0xFF00A6A6) : color
        ..style = PaintingStyle.stroke
        ..strokeWidth = object.id == selectedId
            ? 3
            : object.type == SiteObjectType.column
            ? (forExport ? 1.5 * renderScale : 2.5)
            : (forExport ? renderScale : 1.5),
    );
    if (object.type == SiteObjectType.column) {
      _drawColumnSymbol(canvas, localRect, color);
    } else if (object.type == SiteObjectType.bucketElevator) {
      _drawBucketElevatorSymbol(canvas, localRect, color);
    } else {
      final visualScale = forExport
          ? renderScale
          : 1 / math.max(0.4, viewScale);
      _drawCenteredFittedLabel(
        canvas,
        object.label,
        localRect,
        (object.id == selectedId ? 12 : 11) *
            bundle.project.dimensionTextScale *
            visualScale,
        color,
      );
    }
    canvas.restore();
    _drawObjectDimension(canvas, object);
    if (object.id == selectedId && !forExport) {
      _drawObjectHandles(canvas, object);
    }
  }

  void _drawLinearObject(Canvas canvas, SiteLayoutObject object, Color color) {
    final start = LayoutGeometryService.objectHandlePoint(
      object,
      LayoutResizeHandle.leftEnd,
    );
    final end = LayoutGeometryService.objectHandlePoint(
      object,
      LayoutResizeHandle.rightEnd,
    );
    final startPx = Offset(_px(start.x), _px(start.y));
    final endPx = Offset(_px(end.x), _px(end.y));
    final baseThicknessPx = forExport
        ? _px(object.lengthMm).clamp(renderScale, 3 * renderScale)
        : math.max(1.5, _px(object.lengthMm));
    final thicknessPx = switch (object.type) {
      SiteObjectType.wall => baseThicknessPx / 2,
      SiteObjectType.line when forExport =>
        _px(150).clamp(renderScale, 3 * renderScale) / 6,
      SiteObjectType.line => baseThicknessPx / 2,
      _ => baseThicknessPx,
    };
    if (object.type == SiteObjectType.door) {
      _drawDoorSymbol(canvas, object, startPx, endPx, thicknessPx, color);
      _drawObjectDimension(canvas, object);
      if (object.id == selectedId && !forExport) {
        _drawObjectHandles(canvas, object);
      }
      return;
    }
    if (object.type == SiteObjectType.walkway) {
      _drawWalkwaySymbol(canvas, object, startPx, endPx, thicknessPx, color);
      _drawObjectDimension(canvas, object);
      if (object.id == selectedId && !forExport) {
        _drawObjectHandles(canvas, object);
      }
      return;
    }
    if (object.id == selectedId) {
      canvas.drawLine(
        startPx,
        endPx,
        Paint()
          ..color = const Color(0xFF00A6A6)
          ..strokeWidth = thicknessPx + 5 / math.max(0.15, viewScale)
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawLine(
      startPx,
      endPx,
      Paint()
        ..color = color
        ..strokeWidth = thicknessPx
        ..strokeCap = StrokeCap.square,
    );
    if (object.type == SiteObjectType.wall ||
        object.type == SiteObjectType.line) {
      _drawWallDimension(canvas, object, startPx, endPx, thicknessPx);
    } else {
      _drawObjectDimension(canvas, object);
    }
    if (object.id == selectedId && !forExport) {
      _drawObjectHandles(canvas, object);
    }
  }

  void _drawDoorSymbol(
    Canvas canvas,
    SiteLayoutObject object,
    Offset start,
    Offset end,
    double thicknessPx,
    Color color,
  ) {
    final vector = end - start;
    final openingWidth = vector.distance;
    if (openingWidth <= 0) return;
    final direction = vector / openingWidth;
    final normal = Offset(-direction.dy, direction.dx);
    final radius = openingWidth * 0.42;
    const sweepAngle = math.pi / 3;
    final leafDirection = Offset(
      direction.dx * math.cos(sweepAngle) - direction.dy * math.sin(sweepAngle),
      direction.dx * math.sin(sweepAngle) + direction.dy * math.cos(sweepAngle),
    );
    final leafEnd = start + leafDirection * radius;
    final visualScale = forExport ? 2 / renderScale : math.max(0.15, viewScale);

    if (object.id == selectedId) {
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = const Color(0xFF00A6A6).withValues(alpha: 0.32)
          ..strokeWidth = math.max(thicknessPx, 12 / visualScale)
          ..strokeCap = StrokeCap.round,
      );
    }

    final symbolPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, 2 / visualScale)
      ..strokeCap = StrokeCap.square;
    final thresholdPaint = Paint()
      ..color = color.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, 1.25 / visualScale);

    canvas.drawLine(start, end, thresholdPaint);
    canvas.drawLine(start, leafEnd, symbolPaint);
    canvas.drawArc(
      Rect.fromCircle(center: start, radius: radius),
      math.atan2(vector.dy, vector.dx),
      sweepAngle,
      false,
      thresholdPaint,
    );

    final jambHalfLength = math.max(thicknessPx / 2, 5 / visualScale);
    canvas.drawLine(
      start - normal * jambHalfLength,
      start + normal * jambHalfLength,
      symbolPaint,
    );
    canvas.drawLine(
      end - normal * jambHalfLength,
      end + normal * jambHalfLength,
      symbolPaint,
    );
    canvas.drawCircle(
      start,
      math.max(1.5, 2 / visualScale),
      Paint()..color = color,
    );
  }

  void _drawColumnSymbol(Canvas canvas, Rect rect, Color color) {
    final shortestSide = math.min(rect.width, rect.height);
    final inset = shortestSide * 0.16;
    final symbolRect = rect.deflate(inset);
    if (symbolRect.width <= 0 || symbolRect.height <= 0) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = forExport
          ? 0.8 * renderScale
          : math.max(1, 1.4 / math.max(0.15, viewScale));
    canvas.drawLine(symbolRect.topLeft, symbolRect.bottomRight, paint);
    canvas.drawLine(symbolRect.topRight, symbolRect.bottomLeft, paint);
    canvas.drawCircle(
      rect.center,
      math.max(forExport ? 1.2 * renderScale : 1.5, shortestSide * 0.06),
      Paint()..color = color,
    );
  }

  void _drawBucketElevatorSymbol(Canvas canvas, Rect rect, Color color) {
    final scale = forExport ? 2 / renderScale : math.max(0.15, viewScale);
    final inset = math.min(rect.width, rect.height) * 0.16;
    final shaft = rect.deflate(inset);
    if (shaft.width <= 0 || shaft.height <= 0) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, 1.7 / scale)
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(shaft, Radius.circular(3 / scale)),
      paint,
    );
    final arrowSize = math.min(shaft.width, shaft.height) * 0.22;
    final center = shaft.center;
    canvas.drawLine(
      Offset(center.dx, shaft.bottom - arrowSize * 0.35),
      Offset(center.dx, shaft.top + arrowSize * 0.35),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, shaft.top + arrowSize * 0.35),
      Offset(center.dx - arrowSize, shaft.top + arrowSize * 1.25),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, shaft.top + arrowSize * 0.35),
      Offset(center.dx + arrowSize, shaft.top + arrowSize * 1.25),
      paint,
    );
  }

  void _drawWalkwaySymbol(
    Canvas canvas,
    SiteLayoutObject object,
    Offset start,
    Offset end,
    double thicknessPx,
    Color color,
  ) {
    final vector = end - start;
    final distance = vector.distance;
    if (distance <= 0) return;
    final scale = forExport ? 2 / renderScale : math.max(0.15, viewScale);
    final direction = vector / distance;
    final normal = Offset(-direction.dy, direction.dx);
    final corridorWidth = math.max(thicknessPx, 12 / scale);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = (object.id == selectedId ? const Color(0xFF00A6A6) : color)
            .withValues(alpha: 0.17)
        ..strokeWidth = corridorWidth
        ..strokeCap = StrokeCap.round,
    );
    final linePaint = Paint()
      ..color = object.id == selectedId ? const Color(0xFF00A6A6) : color
      ..strokeWidth = math.max(1.5, 2 / scale)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, linePaint);
    final arrowLength = math.min(distance * 0.22, 18 / scale);
    final arrowWidth = arrowLength * 0.55;
    final arrowBase = end - direction * arrowLength;
    canvas.drawLine(end, arrowBase + normal * arrowWidth, linePaint);
    canvas.drawLine(end, arrowBase - normal * arrowWidth, linePaint);
  }

  void _drawMachine(Canvas canvas, MachinePlacement machine) {
    final center = LayoutGeometryService.machineCenter(machine);
    final centerPx = Offset(_px(center.x), _px(center.y));
    final hasClearance =
        machine.clearanceVerified ||
        machine.clearanceFrontMm > 0 ||
        machine.clearanceRearMm > 0 ||
        machine.clearanceLeftMm > 0 ||
        machine.clearanceRightMm > 0;
    if (showClearance && hasClearance) {
      final localClearance = LayoutGeometryService.localClearance(machine);
      final clearanceRect = Rect.fromLTRB(
        _px(-machine.widthMm / 2 - localClearance.left),
        _px(-machine.lengthMm / 2 - localClearance.top),
        _px(machine.widthMm / 2 + localClearance.right),
        _px(machine.lengthMm / 2 + localClearance.bottom),
      );
      canvas.save();
      canvas.translate(centerPx.dx, centerPx.dy);
      canvas.rotate(machine.rotationDeg * math.pi / 180);
      canvas.drawRect(
        clearanceRect,
        Paint()
          ..color = const Color(0xFF00A6A6).withValues(alpha: 0.08)
          ..style = PaintingStyle.fill,
      );
      final clearancePaint = Paint()
        ..color = const Color(0xFF00A6A6).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = forExport
            ? 0.8 * renderScale
            : 1.5 / math.max(0.4, viewScale);
      _drawDashedRect(canvas, clearanceRect, clearancePaint);
      final clearanceFont =
          8.5 *
          bundle.project.dimensionTextScale *
          (forExport ? renderScale : 1 / math.max(0.4, viewScale));
      _drawMachineClearanceLabels(
        canvas,
        machine,
        clearanceRect,
        clearanceFont,
        clearancePaint.color,
      );
      canvas.restore();
    }
    final hasWarning = warningIds.contains(machine.id);
    final color = hasWarning
        ? const Color(0xFFDC2626)
        : const Color(0xFF087F78);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: _px(machine.widthMm),
      height: _px(machine.lengthMm),
    );
    canvas.save();
    canvas.translate(centerPx.dx, centerPx.dy);
    canvas.rotate(machine.rotationDeg * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = color.withValues(alpha: 0.2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()
        ..color = machine.id == selectedId ? const Color(0xFF00A6A6) : color
        ..style = PaintingStyle.stroke
        ..strokeWidth = forExport
            ? 1.2 * renderScale
            : machine.id == selectedId
            ? 3
            : 2,
    );
    _drawFrontArrow(
      canvas,
      rect,
      frontOnRight: machine.lengthMm > machine.widthMm,
    );
    final visualScale = forExport ? renderScale : 1 / math.max(0.4, viewScale);
    _drawCenteredFittedLabel(
      canvas,
      machine.model,
      rect,
      (machine.id == selectedId ? 12 : 11) *
          bundle.project.dimensionTextScale *
          visualScale,
      color,
    );
    canvas.restore();
    final bounds = LayoutGeometryService.machineRect(machine);
    _drawDimensionText(
      canvas,
      '${_dimension(machine.widthMm)} × ${_dimension(machine.lengthMm)}',
      _dimensionOffset(bounds),
      selected: machine.id == selectedId,
    );
    if (machine.id == selectedId && !forExport && !machine.isLocked) {
      _drawRotationHandle(
        canvas,
        LayoutGeometryService.machineCenter(machine),
        machine.lengthMm,
        machine.rotationDeg,
      );
    }
  }

  void _drawFrontArrow(Canvas canvas, Rect rect, {required bool frontOnRight}) {
    final center = frontOnRight
        ? Offset(rect.left + rect.width * 0.28, rect.center.dy)
        : Offset(rect.center.dx, rect.top + rect.height * 0.72);
    final direction = frontOnRight ? const Offset(1, 0) : const Offset(0, -1);
    final end = center + direction * math.min(rect.width, rect.height) * 0.18;
    canvas.drawLine(
      center,
      end,
      Paint()
        ..color = const Color(0xFF0A2740)
        ..strokeWidth = forExport ? 0.9 * renderScale : 2,
    );
    canvas.drawCircle(
      end,
      forExport ? 1.5 * renderScale : 3,
      Paint()..color = const Color(0xFF0A2740),
    );
  }

  void _drawObjectDimension(Canvas canvas, SiteLayoutObject object) {
    final bounds = LayoutGeometryService.objectRect(object);
    final dimension = object.type.isLinear
        ? _dimension(object.widthMm)
        : '${_dimension(object.widthMm)} × ${_dimension(object.lengthMm)}';
    _drawDimensionText(
      canvas,
      object.isLocked ? 'Khóa · $dimension' : dimension,
      _dimensionOffset(bounds),
      selected: object.id == selectedId,
    );
  }

  void _drawWallDimension(
    Canvas canvas,
    SiteLayoutObject object,
    Offset start,
    Offset end,
    double thicknessPx,
  ) {
    final vector = end - start;
    if (vector.distance <= 0) return;
    final direction = vector / vector.distance;
    final normal = Offset(direction.dy, -direction.dx);
    final visualScale = forExport ? renderScale : 1 / math.max(0.4, viewScale);
    final fontSize =
        (object.id == selectedId ? 12 : 11) *
        bundle.project.dimensionTextScale *
        visualScale;
    _drawCenteredDimensionText(
      canvas,
      _dimension(object.widthMm),
      (start + end) / 2 + normal * (thicknessPx / 2 + 9 * visualScale),
      color: object.id == selectedId
          ? const Color(0xFF007F7A)
          : const Color(0xFF475569),
      fontSize: fontSize,
    );
  }

  Offset _dimensionOffset(math.Rectangle<double> bounds) {
    final visualScale = forExport ? renderScale : 1 / math.max(0.15, viewScale);
    final above = _px(bounds.top) - 22 * visualScale;
    return Offset(
      math.max(3 * visualScale, _px(bounds.left)),
      above >= 2 * visualScale ? above : _px(bounds.bottom) + 4 * visualScale,
    );
  }

  void _drawObjectHandles(Canvas canvas, SiteLayoutObject object) {
    if (object.isLocked) return;
    final handles = object.type.isLinear
        ? const [LayoutResizeHandle.leftEnd, LayoutResizeHandle.rightEnd]
        : const [
            LayoutResizeHandle.topLeft,
            LayoutResizeHandle.topRight,
            LayoutResizeHandle.bottomRight,
            LayoutResizeHandle.bottomLeft,
          ];
    final radius = 6 / math.max(0.15, viewScale);
    for (final handle in handles) {
      final point = LayoutGeometryService.objectHandlePoint(object, handle);
      final offset = Offset(_px(point.x), _px(point.y));
      canvas.drawCircle(
        offset,
        radius + 2 / viewScale,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        offset,
        radius,
        Paint()
          ..color = const Color(0xFF00A6A6)
          ..style = PaintingStyle.fill,
      );
    }
    _drawRotationHandle(
      canvas,
      LayoutGeometryService.objectCenter(object),
      object.lengthMm,
      object.rotationDeg,
    );
  }

  void _drawRotationHandle(
    Canvas canvas,
    math.Point<double> center,
    double heightMm,
    double rotationDeg,
  ) {
    final scale = math.max(0.15, viewScale);
    final top = LayoutGeometryService.localToWorld(
      center,
      0,
      -heightMm / 2,
      rotationDeg,
    );
    final handle = LayoutGeometryService.localToWorld(
      center,
      0,
      -heightMm / 2 - 34 / scale / pixelsPerMm,
      rotationDeg,
    );
    final topOffset = Offset(_px(top.x), _px(top.y));
    final handleOffset = Offset(_px(handle.x), _px(handle.y));
    final paint = Paint()
      ..color = const Color(0xFF00A6A6)
      ..strokeWidth = 1.5 / scale
      ..style = PaintingStyle.stroke;
    canvas.drawLine(topOffset, handleOffset, paint);
    canvas.drawCircle(handleOffset, 8 / scale, Paint()..color = Colors.white);
    canvas.drawCircle(handleOffset, 7 / scale, paint);
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint);
    _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint);
    _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint);
    _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final vector = end - start;
    final length = vector.distance;
    if (length <= 0) return;
    final direction = vector / length;
    final visualScale = forExport ? renderScale : 1 / math.max(0.4, viewScale);
    final dash = 8 * visualScale;
    final gap = 5 * visualScale;
    for (var offset = 0.0; offset < length; offset += dash + gap) {
      canvas.drawLine(
        start + direction * offset,
        start + direction * math.min(offset + dash, length),
        paint,
      );
    }
  }

  void _drawDimensionText(
    Canvas canvas,
    String value,
    Offset offset, {
    bool selected = false,
  }) {
    _text(
      canvas,
      value,
      offset,
      (selected ? 12 : 11) *
          bundle.project.dimensionTextScale /
          (forExport ? 1 / renderScale : math.max(0.4, viewScale)),
      selected ? const Color(0xFF007F7A) : const Color(0xFF475569),
    );
  }

  void _drawCenteredDimensionText(
    Canvas canvas,
    String value,
    Offset center, {
    required Color color,
    required double fontSize,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          backgroundColor: Colors.white.withValues(alpha: 0.82),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  String _dimension(double value) => bundle.project.dimensionUnit.format(value);

  void _drawMeasurement(Canvas canvas, LayoutMeasurement measurement) {
    final start = Offset(_px(measurement.x1Mm), _px(measurement.y1Mm));
    final end = Offset(_px(measurement.x2Mm), _px(measurement.y2Mm));
    final selected = measurement.id == selectedId;
    final paint = Paint()
      ..color = selected ? const Color(0xFF00A6A6) : const Color(0xFF176B87)
      ..strokeWidth = forExport
          ? 0.9 * renderScale
          : selected
          ? 3
          : 1.5;
    canvas.drawLine(start, end, paint);
    final endpointRadius = forExport
        ? 1.5 * renderScale
        : selected
        ? 7 / math.max(0.15, viewScale)
        : 3.0;
    if (selected && !forExport) {
      canvas.drawCircle(
        start,
        endpointRadius + 2 / math.max(0.15, viewScale),
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        end,
        endpointRadius + 2 / math.max(0.15, viewScale),
        Paint()..color = Colors.white,
      );
    }
    canvas.drawCircle(start, endpointRadius, paint);
    canvas.drawCircle(end, endpointRadius, paint);
    final value = bundle.project.dimensionUnit.format(measurement.distanceMm);
    _text(
      canvas,
      value,
      (start + end) / 2 + Offset(4 * renderScale, -14 * renderScale),
      8.5 * bundle.project.dimensionTextScale * (forExport ? renderScale : 1),
      paint.color,
    );
  }

  void _drawCenteredFittedLabel(
    Canvas canvas,
    String value,
    Rect rect,
    double fontSize,
    Color color,
  ) {
    final padding = 5 * (forExport ? renderScale : 1);
    final availableWidth = math.max(1.0, rect.width - padding * 2);
    final availableHeight = math.max(1.0, rect.height - padding * 2);
    final probe = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w700,
          backgroundColor: Colors.white.withValues(alpha: 0.82),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout();
    final fitScale = math.min(
      1.0,
      math.min(
        availableWidth / math.max(1.0, probe.width),
        availableHeight / math.max(1.0, probe.height),
      ),
    );
    final fittedFontSize = fontSize * fitScale;
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: fittedFontSize,
          color: color,
          fontWeight: FontWeight.w700,
          backgroundColor: Colors.white.withValues(alpha: 0.82),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout(maxWidth: availableWidth);
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
  }

  void _drawMachineClearanceLabels(
    Canvas canvas,
    MachinePlacement machine,
    Rect rect,
    double fontSize,
    Color color,
  ) {
    final portrait = machine.lengthMm > machine.widthMm;
    final top = portrait
        ? 'Trái ${_dimension(machine.clearanceLeftMm)}'
        : 'Trước ${_dimension(machine.clearanceFrontMm)}';
    final right = portrait
        ? 'Trước ${_dimension(machine.clearanceFrontMm)}'
        : 'Phải ${_dimension(machine.clearanceRightMm)}';
    final bottom = portrait
        ? 'Phải ${_dimension(machine.clearanceRightMm)}'
        : 'Sau ${_dimension(machine.clearanceRearMm)}';
    final left = portrait
        ? 'Sau ${_dimension(machine.clearanceRearMm)}'
        : 'Trái ${_dimension(machine.clearanceLeftMm)}';
    final inset = 7 * (forExport ? renderScale : 1 / math.max(0.4, viewScale));
    _drawCenteredDimensionText(
      canvas,
      top,
      Offset(rect.center.dx, rect.top + inset),
      color: color,
      fontSize: fontSize,
    );
    _drawCenteredDimensionText(
      canvas,
      right,
      Offset(rect.right - inset, rect.center.dy),
      color: color,
      fontSize: fontSize,
    );
    _drawCenteredDimensionText(
      canvas,
      bottom,
      Offset(rect.center.dx, rect.bottom - inset),
      color: color,
      fontSize: fontSize,
    );
    _drawCenteredDimensionText(
      canvas,
      left,
      Offset(rect.left + inset, rect.center.dy),
      color: color,
      fontSize: fontSize,
    );
  }

  void _drawMarker(Canvas canvas, Offset point, String text, Color color) {
    final markerScale = forExport ? renderScale : 1.0;
    canvas.drawCircle(point, 10 * markerScale, Paint()..color = color);
    _text(
      canvas,
      text,
      point - Offset(4 * markerScale, 7 * markerScale),
      10 * markerScale,
      Colors.white,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    double fontSize,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w700,
          backgroundColor: forExport && color != Colors.white
              ? Colors.white.withValues(alpha: 0.82)
              : null,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 200 * (forExport ? renderScale : 1));
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant SiteLayoutPainter oldDelegate) => true;
}

class _ScaleLegend extends StatelessWidget {
  const _ScaleLegend({
    required this.gridMm,
    required this.unit,
    required this.snapEnabled,
  });

  final double gridMm;
  final SiteDimensionUnit unit;
  final bool snapEnabled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          'Lưới ${unit.format(gridMm)} · ${snapEnabled ? 'Bắt dính' : 'Tự do'}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}
