import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../diagram/air_diagram_render.dart';
import '../models/air_config.dart';
import '../providers/air_config_editor_controller.dart';
import '../room/room_drawing.dart';
import '../room/room_engine.dart';
import '../room/room_strings.dart';
import 'air_config_form.dart' show AirNumberField;

enum RoomEditMode { view, measure, move }

/// Mặt bằng phòng lắp đặt toàn màn hình: xem (kéo, phóng to), đo kích thước
/// giữa 2 điểm (bắt điểm vào góc, cạnh, tâm thiết bị), kéo thiết bị đổi vị
/// trí. Phép đo và vị trí lưu vào cấu hình nên có cả trong file xuất.
class AirRoomEditor extends StatefulWidget {
  const AirRoomEditor({super.key});

  @override
  State<AirRoomEditor> createState() => _AirRoomEditorState();
}

class _AirRoomEditorState extends State<AirRoomEditor> {
  final _transform = TransformationController();
  double? _fittedFor;
  RoomEditMode _mode = RoomEditMode.view;

  /// Điểm đo thứ nhất đang chờ (mm).
  Offset? _pending;

  /// Thiết bị đang chọn (chế độ Di chuyển) — để xoay.
  String? _selectedKey;

  /// Thiết bị đang kéo: khóa, góc trên trái ban đầu (mm), điểm chạm (mm).
  String? _dragKey;

  /// Điểm đo đang kéo (1 hoặc 2).
  int? _dragPoint;
  Offset _dragStart = Offset.zero;
  Offset _grab = Offset.zero;

  static const _snapPx = 16.0;

  /// Bán kính chạm để kéo điểm đo (px màn hình) — rộng cho ngón tay.
  static const _handleGrabPx = 36.0;
  static const _grid = 50.0;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _fit(double viewWidth, double drawingWidth) {
    final scale = (viewWidth / drawingWidth).clamp(0.2, 1.5);
    _transform.value = Matrix4.identity()..scaleByDouble(scale, scale, 1, 1);
    _fittedFor = viewWidth * 100000 + drawingWidth;
  }

  double get _zoom => _transform.value.getMaxScaleOnAxis();

  /// Điểm chạm trên màn hình → px bản vẽ.
  Offset _toDrawing(Offset local) {
    final inverse = Matrix4.tryInvert(_transform.value);
    return inverse == null ? local : MatrixUtils.transformPoint(inverse, local);
  }

  /// Bắt vào điểm gần nhất: góc phòng, góc / trung điểm cạnh / tâm thiết bị,
  /// tâm lọc. Không có điểm nào trong bán kính thì giữ nguyên.
  Offset _snap(Offset mm, RoomResult room, RoomDrawing drawing) {
    final candidates = <Offset>[
      Offset.zero,
      Offset(room.lengthMm, 0),
      Offset(0, room.widthMm),
      Offset(room.lengthMm, room.widthMm),
      for (final i in room.items) ...[
        i.rect.topLeft,
        i.rect.topRight,
        i.rect.bottomLeft,
        i.rect.bottomRight,
        i.rect.topCenter,
        i.rect.bottomCenter,
        i.rect.centerLeft,
        i.rect.centerRight,
        i.rect.center,
      ],
      for (final f in room.filters) f.at,
    ];
    final radius = _snapPx / _zoom / drawing.scale;
    Offset? best;
    var bestD = radius;
    for (final c in candidates) {
      final d = (c - mm).distance;
      if (d <= bestD) {
        best = c;
        bestD = d;
      }
    }
    if (best != null) return best;
    // Không gần điểm nào: dính lên mặt tường hoặc mép thiết bị gần nhất
    // (giữ vị trí dọc theo tường / mép).
    final lines = <Rect>[
      Rect.fromLTWH(0, 0, room.lengthMm, room.widthMm),
      for (final i in room.items)
        if (!i.isRound) i.rect,
    ];
    for (final r in lines) {
      final inSpanX = mm.dx >= r.left - radius && mm.dx <= r.right + radius;
      final inSpanY = mm.dy >= r.top - radius && mm.dy <= r.bottom + radius;
      for (final (edge, horizontal) in [
        (r.top, true),
        (r.bottom, true),
        (r.left, false),
        (r.right, false),
      ]) {
        final d = horizontal ? (mm.dy - edge).abs() : (mm.dx - edge).abs();
        if (d > bestD || !(horizontal ? inSpanX : inSpanY)) continue;
        bestD = d;
        best = horizontal ? Offset(mm.dx, edge) : Offset(edge, mm.dy);
      }
    }
    return best ?? mm;
  }

  /// Gần như ngang / dọc (lệch < 5% chiều dài và ≤ 150 mm): nắn điểm đang
  /// đặt / kéo cho thẳng hàng với điểm kia.
  static Offset _straighten(Offset fixed, Offset moving) {
    final d = moving - fixed;
    final limit = (d.distance * 0.05).clamp(0.0, 150.0);
    if (d.dx.abs() <= limit) return Offset(fixed.dx, moving.dy);
    if (d.dy.abs() <= limit) return Offset(moving.dx, fixed.dy);
    return moving;
  }

  /// Thiết bị trên cùng chứa điểm chạm (nới 150 mm cho khối nhỏ).
  RoomItem? _hit(Offset local, AirConfigEditorController ctrl) {
    final room = ctrl.room;
    final drawing = ctrl.roomDrawing;
    if (room == null || drawing == null) return null;
    final mm = drawing.toMm(_toDrawing(local));
    return room.items.reversed
        .where((i) => i.rect.inflate(150).contains(mm))
        .firstOrNull;
  }

  void _tap(Offset local, AirConfigEditorController ctrl) {
    if (_mode == RoomEditMode.move) {
      setState(() => _selectedKey = _hit(local, ctrl)?.key);
      return;
    }
    if (_mode != RoomEditMode.measure) return;
    final room = ctrl.room;
    final drawing = ctrl.roomDrawing;
    if (room == null || drawing == null) return;
    // Mỗi lần đo tối đa 2 điểm: đã đủ thì chỉ kéo điểm hoặc bấm "Đo lại".
    if (ctrl.config.room.measures.isNotEmpty) return;
    final mm = _snap(drawing.toMm(_toDrawing(local)), room, drawing);
    final first = _pending;
    if (first == null) {
      setState(() => _pending = mm);
      return;
    }
    if ((mm - first).distance < 1) return;
    setState(() => _pending = null);
    _setMeasure(ctrl, first, _straighten(first, mm));
  }

  /// Phép đo hiện tại (một phép, 2 điểm) — lưu vào cấu hình để có trong file
  /// xuất.
  void _setMeasure(AirConfigEditorController ctrl, Offset a, Offset b) {
    ctrl.edit(
      (c) => c.room.measures
        ..clear()
        ..add(RoomMeasure(a.dx, a.dy, b.dx, b.dy)),
    );
  }

  /// Hai điểm đo hiện có (mm): điểm 1, điểm 2 (null khi chưa chọn).
  (Offset?, Offset?) _points(AirConfigEditorController ctrl) {
    final m = ctrl.config.room.measures.lastOrNull;
    if (m == null) return (_pending, null);
    return (Offset(m.ax, m.ay), Offset(m.bx, m.by));
  }

  /// Bắt đầu kéo điểm đo gần ngón tay nhất (bán kính rộng cho điện thoại).
  void _measureDragBegin(Offset local, AirConfigEditorController ctrl) {
    final drawing = ctrl.roomDrawing;
    if (drawing == null) return;
    final finger = drawing.toMm(_toDrawing(local));
    final (a, b) = _points(ctrl);
    final radius = _handleGrabPx / _zoom / drawing.scale;
    int? which;
    var best = radius;
    for (final (k, p) in [(1, a), (2, b)]) {
      if (p == null) continue;
      final d = (p - finger).distance;
      if (d <= best) {
        best = d;
        which = k;
      }
    }
    if (which == null) return;
    setState(() {
      _dragPoint = which;
      _dragStart = which == 1 ? a! : b!;
      _grab = finger;
    });
  }

  /// Điểm đi theo quãng ngón tay di chuyển (không nhảy xuống dưới ngón tay
  /// nên vẫn nhìn thấy điểm), có bắt điểm.
  void _measureDragUpdate(Offset local, AirConfigEditorController ctrl) {
    final which = _dragPoint;
    final room = ctrl.room;
    final drawing = ctrl.roomDrawing;
    if (which == null || room == null || drawing == null) return;
    final target = _snap(
      _dragStart + (drawing.toMm(_toDrawing(local)) - _grab),
      room,
      drawing,
    );
    final (a, b) = _points(ctrl);
    if (b == null) {
      setState(() => _pending = target);
      return;
    }
    if (which == 1) {
      _setMeasure(ctrl, _straighten(b, target), b);
    } else {
      _setMeasure(ctrl, a!, _straighten(a, target));
    }
  }

  void _remeasure(AirConfigEditorController ctrl) {
    setState(() => _pending = null);
    if (ctrl.config.room.measures.isNotEmpty) {
      ctrl.edit((c) => c.room.measures.clear());
    }
  }

  void _dragBegin(Offset local, AirConfigEditorController ctrl) {
    final drawing = ctrl.roomDrawing;
    final hit = _hit(local, ctrl);
    if (hit == null || drawing == null) return;
    setState(() {
      _dragKey = hit.key;
      _selectedKey = hit.key;
      _dragStart = hit.rect.topLeft;
      _grab = drawing.toMm(_toDrawing(local));
    });
  }

  double _snapGrid(double v) => (v / _grid).round() * _grid;

  /// Xoay thiết bị đang chọn 90° quanh tâm. Ghim vị trí hiện tại của mọi
  /// thiết bị trước, để xếp tự động không đẩy các thiết bị khác đi.
  void _rotate(AirConfigEditorController ctrl) {
    final key = _selectedKey;
    final room = ctrl.room;
    final item = room?.items.where((i) => i.key == key).firstOrNull;
    if (room == null || item == null || key == null) return;
    final center = item.rect.center;
    ctrl.edit((c) {
      for (final i in room.items) {
        c.room.positions.putIfAbsent(i.key, () => (i.rect.left, i.rect.top));
      }
      if (!c.room.turned.remove(key)) c.room.turned.add(key);
      c.room.positions[key] = (
        _snapGrid(center.dx - item.rect.height / 2),
        _snapGrid(center.dy - item.rect.width / 2),
      );
    });
  }

  /// Hộp nhập T1 (ngoài phòng), T2 (khí vào máy nén tối đa) cho thông gió.
  Future<void> _editVentTemps(AirConfigEditorController ctrl) async {
    final s = ctrl.strings;
    final v = ctrl.room?.ventilation;
    double? t1 = v?.outsideTempC;
    double? t2 = v?.inletMaxTempC;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.roomVentInputTitle),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.roomVentFormula),
            const SizedBox(height: 12),
            AirNumberField(
              key: const Key('room_vent_t1'),
              label: s.roomOutsideTemp,
              value: t1,
              onChanged: (x) => t1 = x,
            ),
            AirNumberField(
              key: const Key('room_vent_t2'),
              label: s.roomInletTemp,
              value: t2,
              onChanged: (x) => t2 = x,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            key: const Key('room_vent_apply'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.apply),
          ),
        ],
      ),
    );
    if (ok == true) ctrl.setVentTemps(t1, t2);
  }

  Future<void> _editRoomSize(AirConfigEditorController ctrl) async {
    final s = ctrl.strings;
    final room = ctrl.config.room;
    var length = room.lengthM;
    var width = room.widthM;
    var height = room.heightM;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.roomSizeTitle),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.roomInputHint),
            const SizedBox(height: 12),
            AirNumberField(
              key: const Key('room_size_length'),
              label: s.roomLength,
              value: length,
              onChanged: (v) => length = v,
            ),
            AirNumberField(
              key: const Key('room_size_width'),
              label: s.roomWidth,
              value: width,
              onChanged: (v) => width = v,
            ),
            AirNumberField(
              key: const Key('room_size_height'),
              label: s.roomHeight,
              value: height,
              onChanged: (v) => height = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'clear'),
            child: Text(s.roomSizeClear),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.cancel),
          ),
          FilledButton(
            key: const Key('room_size_apply'),
            onPressed: () => Navigator.pop(context, 'apply'),
            child: Text(s.apply),
          ),
        ],
      ),
    );
    if (result == 'apply') {
      ctrl.setRoomSize(length, width, height);
    } else if (result == 'clear') {
      ctrl.setRoomSize(null, null, null);
    }
  }

  void _dragUpdate(Offset local, AirConfigEditorController ctrl) {
    final key = _dragKey;
    final drawing = ctrl.roomDrawing;
    if (key == null || drawing == null) return;
    final target = _dragStart + (drawing.toMm(_toDrawing(local)) - _grab);
    final snapped = (_snapGrid(target.dx), _snapGrid(target.dy));
    if (ctrl.config.room.positions[key] == snapped) return;
    ctrl.edit((c) => c.room.positions[key] = snapped);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AirConfigEditorController>();
    final s = ctrl.strings;
    final drawing = ctrl.roomDrawing;
    final room = ctrl.room;
    if (drawing == null || room == null) return const SizedBox.shrink();
    final (a, b) = _points(ctrl);
    final hint = switch (_mode) {
      RoomEditMode.view => s.roomHintView,
      RoomEditMode.measure =>
        a == null
            ? s.roomHintMeasure
            : b == null
            ? s.roomHintMeasureSecond
            : s.roomHintMeasureDone,
      RoomEditMode.move => s.roomHintMove,
    };
    final canvas = SizedBox(
      width: drawing.width,
      height: drawing.height,
      child: CustomPaint(
        key: const Key('room_editor_canvas'),
        painter: AirDiagramPainter(drawing),
        foregroundPainter: _OverlayPainter(
          drawing: drawing,
          zoom: _zoom,
          handles: _mode == RoomEditMode.measure ? [a, b] : const [],
          active: _dragPoint,
          selected: room.items
              .where((i) => i.key == (_dragKey ?? _selectedKey))
              .firstOrNull,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<RoomEditMode>(
                        key: const Key('room_edit_mode'),
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: RoomEditMode.view,
                            icon: const Icon(Icons.pan_tool_outlined, size: 18),
                            label: Text(s.roomModeView),
                          ),
                          ButtonSegment(
                            value: RoomEditMode.measure,
                            icon: const Icon(
                              Icons.straighten_rounded,
                              size: 18,
                            ),
                            label: Text(s.roomModeMeasure),
                          ),
                          ButtonSegment(
                            value: RoomEditMode.move,
                            icon: const Icon(Icons.open_with_rounded, size: 18),
                            label: Text(s.roomModeMove),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (v) => setState(() {
                          _mode = v.first;
                          _pending = null;
                          _dragKey = null;
                          _selectedKey = null;
                        }),
                      ),
                    ),
                    PopupMenuButton<String>(
                      key: const Key('room_edit_menu'),
                      icon: const Icon(Icons.more_vert),
                      onSelected: (v) {
                        if (v == 'vent') {
                          _editVentTemps(ctrl);
                          return;
                        }
                        if (v == 'size') {
                          _editRoomSize(ctrl);
                          return;
                        }
                        if (v == 'reset') {
                          ctrl.edit(
                            (c) => c.room
                              ..positions.clear()
                              ..turned.clear(),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          key: const Key('room_size_menu'),
                          value: 'size',
                          child: Text(s.roomSizeMenu),
                        ),
                        PopupMenuItem(
                          key: const Key('room_vent_menu'),
                          value: 'vent',
                          child: Text(s.roomVentMenu),
                        ),
                        PopupMenuItem(
                          value: 'reset',
                          enabled:
                              ctrl.config.room.positions.isNotEmpty ||
                              ctrl.config.room.turned.isNotEmpty,
                          child: Text(s.roomResetPositions),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_mode == RoomEditMode.measure)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        FilledButton.tonalIcon(
                          key: const Key('room_remeasure'),
                          onPressed: a == null ? null : () => _remeasure(ctrl),
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: Text(s.roomRemeasure),
                        ),
                        const SizedBox(width: 12),
                        if (a != null && b != null)
                          Expanded(
                            child: Text(
                              '${s.roomMeasureLabel(b.dx - a.dx, b.dy - a.dy)} mm',
                              key: const Key('room_measure_value'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFFC026D3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_mode == RoomEditMode.move)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        FilledButton.tonalIcon(
                          key: const Key('room_rotate'),
                          onPressed: _selectedKey == null
                              ? null
                              : () => _rotate(ctrl),
                          icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
                          label: Text(s.roomRotate),
                        ),
                        const SizedBox(width: 12),
                        if (room.items
                                .where((i) => i.key == _selectedKey)
                                .firstOrNull
                            case final item?)
                          Expanded(
                            child: Text(
                              '${room.items.indexOf(item) + 1}. '
                              '${s.roomKind(item.kind)}'
                              '${item.model == null ? '' : ' – ${item.model}'}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  hint,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
                for (final w in room.warnings)
                  if (w.code == RoomWarningCode.clash ||
                      w.code == RoomWarningCode.outside ||
                      w.code == RoomWarningCode.tooSmall)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        s.roomWarning(w),
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final key = constraints.maxWidth * 100000 + drawing.width;
              if (_fittedFor != key) _fit(constraints.maxWidth, drawing.width);
              final background = const Color(0xFFF1F5F9);
              if (_mode == RoomEditMode.view) {
                return ColoredBox(
                  color: background,
                  child: InteractiveViewer(
                    transformationController: _transform,
                    constrained: false,
                    minScale: 0.15,
                    maxScale: 6,
                    boundaryMargin: const EdgeInsets.all(400),
                    child: canvas,
                  ),
                );
              }
              // Đo / di chuyển: giữ nguyên khung nhìn, cử chỉ dành cho thao tác.
              return GestureDetector(
                key: const Key('room_editor_gestures'),
                behavior: HitTestBehavior.opaque,
                // Kéo tính từ điểm chạm đầu tiên (không mất đoạn ngưỡng kéo).
                dragStartBehavior: DragStartBehavior.down,
                onTapUp: (d) => _tap(d.localPosition, ctrl),
                onPanStart: (d) => _mode == RoomEditMode.move
                    ? _dragBegin(d.localPosition, ctrl)
                    : _measureDragBegin(d.localPosition, ctrl),
                onPanUpdate: (d) => _mode == RoomEditMode.move
                    ? _dragUpdate(d.localPosition, ctrl)
                    : _measureDragUpdate(d.localPosition, ctrl),
                onPanEnd: (_) => setState(() {
                  _dragKey = null;
                  _dragPoint = null;
                }),
                child: ClipRect(
                  child: ColoredBox(
                    color: background,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Transform(
                            transform: _transform.value,
                            child: canvas,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Lớp vẽ tạm (không vào file xuất): điểm đo thứ nhất, viền thiết bị đang
/// kéo.
class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.drawing,
    required this.zoom,
    this.handles = const [],
    this.active,
    this.selected,
  });
  final RoomDrawing drawing;

  /// Độ phóng hiện tại: nút kéo giữ cùng cỡ trên màn hình.
  final double zoom;

  /// Điểm đo 1, 2 (mm), `null` khi chưa chọn.
  final List<Offset?> handles;

  /// Điểm đang kéo (1 hoặc 2).
  final int? active;
  final RoomItem? selected;

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFFC026D3);
    // Nút kéo tròn lớn đánh số 1, 2 (bán kính ~12 px màn hình).
    final r = 12 / zoom;
    for (var k = 0; k < handles.length; k++) {
      final p = handles[k];
      if (p == null) continue;
      final c = drawing.toPx(p);
      final on = active == k + 1;
      canvas
        ..drawCircle(
          c,
          r * (on ? 1.6 : 1.25),
          Paint()..color = color.withValues(alpha: on ? 0.3 : 0.18),
        )
        ..drawCircle(c, r * 0.75, Paint()..color = color)
        ..drawCircle(
          c,
          r * 0.75,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 / zoom,
        );
      final label = TextPainter(
        text: TextSpan(
          text: '${k + 1}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11 / zoom,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, c - Offset(label.width / 2, label.height / 2));
    }
    final item = selected;
    if (item != null) {
      final rect = Rect.fromPoints(
        drawing.toPx(item.rect.topLeft),
        drawing.toPx(item.rect.bottomRight),
      ).inflate(3);
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.zoom != zoom ||
      old.active != active ||
      old.handles.length != handles.length ||
      [for (var k = 0; k < handles.length; k++) old.handles[k] != handles[k]]
          .any((d) => d) ||
      old.selected?.rect != selected?.rect ||
      old.drawing != drawing;
}
