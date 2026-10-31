import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/survey_bom.dart';
import '../../air_system_config/diagram/air_diagram.dart' show AirDiagramColors;
import '../../air_system_config/room/room_drawing.dart' show RoomColors;
import '../../air_system_config/room/room_engine.dart' show RoomItemKind;
import '../engine/survey_geometry.dart';
import '../engine/survey_plant.dart';
import '../models/pipe_survey.dart';
import '../providers/pipe_survey_controller.dart';
import 'survey_sheets.dart';

/// Công cụ trên màn vẽ sơ đồ.
enum SurveyTool {
  select('Chọn', Icons.touch_app_outlined),
  pipe('Vẽ ống', Icons.timeline_rounded),
  usePoint('Điểm sử dụng', Icons.precision_manufacturing_outlined),
  point('Điểm trên sơ đồ', Icons.add_location_alt_outlined),
  wall('Tường', Icons.horizontal_rule_rounded),
  column('Cột', Icons.crop_square_rounded),
  obstacle('Chướng ngại', Icons.block_outlined),
  move('Di chuyển', Icons.open_with_rounded),
  trim('Cắt', Icons.content_cut_rounded),
  erase('Xoá', Icons.delete_outline_rounded),
  note('Ghi chú', Icons.text_fields_rounded),
  leader('Mũi tên', Icons.north_east_rounded),
  area('Tên vùng', Icons.title_rounded);

  const SurveyTool(this.label, this.icon);
  final String label;
  final IconData icon;

  String get hint => switch (this) {
    SurveyTool.select => 'Chạm vào đoạn ống hoặc điểm để sửa / xoá. Chạm số chiều dài để nhập giá trị đo.',
    SurveyTool.pipe => 'Chạm điểm đầu rồi các điểm tiếp theo (ống đi ngang / dọc); chạm lại điểm cuối hoặc bấm End để dừng. Chạm số chiều dài để nhập giá trị đo.',
    SurveyTool.usePoint =>
      'Chạm lên ống hoặc chỗ trống để đặt điểm sử dụng khí (máy tách màu…).',
    SurveyTool.point => 'Chạm điểm có sẵn, chỗ trống hoặc lên ống để đặt điểm, rồi chọn loại: điểm nối, điểm sử dụng, cụm máy.',
    SurveyTool.move => 'Nhấn giữ vật (điểm, đoạn ống, cụm máy, tường, cột, chữ…) rồi rê tới vị trí mới. Ống nối vào kéo giãn theo.',
    SurveyTool.trim => 'Chạm phần tường cần cắt bỏ: cắt tới chỗ giao với tường, cột, chướng ngại, cụm máy, tường bao.',
    SurveyTool.erase => 'Chạm vật cần xoá (điểm, đoạn ống, cụm máy, tường, cột, chữ…). Xoá nhầm: bấm Undo.',
    SurveyTool.wall => 'Chạm điểm đầu rồi các điểm tiếp theo để vẽ tường (ngang / dọc); chạm lại điểm cuối hoặc bấm End để dừng.',
    SurveyTool.column => 'Chạm để đặt cột (mặc định 0,4 × 0,4 m).',
    SurveyTool.obstacle =>
      'Chạm 2 góc đối diện để vẽ vùng chướng ngại (bồn, dầm, ống gió…).',
    SurveyTool.note => 'Chạm chỗ cần ghi chú rồi nhập nội dung.',
    SurveyTool.leader =>
      'Chạm điểm mũi tên chỉ vào, rồi chạm chỗ đặt chữ và nhập nội dung.',
    SurveyTool.area =>
      'Chạm giữa khu vực rồi nhập tên (vd Xưởng sấy, Kho thành phẩm).',
  };

  /// Công cụ nằm trong menu Edit.
  bool get inEditMenu => index >= SurveyTool.move.index;

  /// Công cụ sửa (không mở hộp nhập chiều dài khi chạm số).
  bool get isModify =>
      this == SurveyTool.move ||
      this == SurveyTool.trim ||
      this == SurveyTool.erase;
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

  /// Đoạn vừa vẽ: hiện thanh nhập chiều dài đo thực tế.
  String? _lastSeg;

  /// Điểm đang vẽ tường tiếp / góc thứ nhất của chướng ngại (m).
  Offset? _shapeFrom;

  /// Vật đang kéo rê (công cụ Di chuyển): vị trí gốc của các điểm / hình.
  SurveyPick? _moving;
  final _dragNodes = <String, Offset>{};
  (double, double, double, double)? _dragShape;
  Offset _dragDelta = Offset.zero;

  bool get _drawing => _drawFrom != null || _shapeFrom != null;

  void _stopDrawing() => setState(() {
    _drawFrom = null;
    _shapeFrom = null;
  });

  /// Kích thước vùng vẽ (px) — vị trí khung tên.
  Size _canvasSize = Size.zero;

  /// Gốc hiển thị (m): dời khi cụm máy tràn sang toạ độ âm.
  Offset _origin = Offset.zero;

  PipeSurveyController get ctrl => widget.ctrl;
  PipeSurvey get s => ctrl.survey;

  void _setTool(SurveyTool t) => setState(() {
    _tool = t;
    _drawFrom = null;
    _shapeFrom = null;
    _moving = null;
    _lastSeg = null;
  });

  /// Vật tại vị trí chạm: điểm, đoạn ống, hình nền, rồi cụm máy (kích thước
  /// thật). [erase]: điểm dùng / cụm máy trước, điểm nối sau đoạn ống.
  SurveyPick? _pickAt(double x, double y, {bool erase = false}) {
    final node = surveyNodeAt(s, x, y);
    final base = Offset(x, y);
    if (node != null && (!erase || node.kind != SurveyNodeKind.junction)) {
      return SurveyPick(base, node: node.id);
    }
    final seg = surveySegmentAt(s, x, y);
    if (seg != null) return SurveyPick(base, segment: seg.$1.id);
    if (node != null) return SurveyPick(base, node: node.id);
    final shape = surveyShapeAt(s, x, y);
    if (shape != null) return SurveyPick(base, shape: shape.id);
    for (final e in ctrl.plants.entries) {
      if (e.value.bounds.contains(base)) {
        return SurveyPick(base, node: e.key, plant: true);
      }
    }
    return null;
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
      );
  }

  /// Đặt chữ (ghi chú, mũi tên, tên vùng): mở hộp nhập; huỷ khi chưa nhập
  /// chữ thì bỏ.
  Future<void> _placeText(SurveyShape shape) async {
    ctrl.edit((s) => s.shapes.add(shape));
    if (mounted) await showSurveyShapeSheet(context, ctrl, shape.id);
    if (s.shapes.any((h) => h.id == shape.id && h.label.isEmpty)) {
      ctrl.edit(
        (s) => s.shapes.removeWhere((h) => h.id == shape.id),
        undoable: false,
      );
    }
  }

  /// Đoạn có nhãn chiều dài ở vị trí chạm (nhãn vẽ cạnh giữa đoạn, xem
  /// [SurveyPainter]).
  String? _labelAt(Offset local) {
    for (final seg in s.segments) {
      final a = s.node(seg.a), b = s.node(seg.b);
      if (a == null || b == null) continue;
      final mid = Offset((a.x + b.x) / 2, (a.y + b.y) / 2) * _ppm;
      final vertical = (a.x - b.x).abs() < 1e-6;
      final center =
          mid + (vertical ? const Offset(26, 0) : const Offset(6, -10));
      final d = local - center;
      // Chỉ phần chữ, không trùm lên đường ống (chạm ống vẫn để vẽ / đặt điểm).
      final (rx, ry) = vertical ? (20.0, 9.0) : (24.0, 7.0);
      if (d.dx.abs() <= rx && d.dy.abs() <= ry) return seg.id;
    }
    return null;
  }

  Future<void> _tap(Offset local) async {
    final x = local.dx / _ppm - _origin.dx, y = local.dy / _ppm - _origin.dy;
    // Khung tên bản vẽ (công cụ Chọn).
    if (_tool == SurveyTool.select &&
        SurveyPainter.titleBlockRect(_canvasSize).contains(local)) {
      await showSurveyTitleSheet(context, ctrl);
      return;
    }
    // Chạm số chiều dài (trừ công cụ sửa): nhập chiều dài đo thực tế.
    final segId = _tool.isModify ? null : _labelAt(local - _origin * _ppm);
    if (segId != null) {
      await showSurveySegmentSheet(context, ctrl, segId);
      return;
    }
    switch (_tool) {
      case SurveyTool.select:
        final node = surveyNodeAt(s, x, y);
        if (node != null) {
          await showSurveyNodeSheet(context, ctrl, node.id);
          return;
        }
        final seg = surveySegmentAt(s, x, y);
        if (seg != null) {
          await showSurveySegmentSheet(context, ctrl, seg.$1.id);
          return;
        }
        // Chạm vào cụm máy (kích thước thật): sửa điểm Cụm máy.
        for (final e in ctrl.plants.entries) {
          if (e.value.bounds.contains(Offset(x, y))) {
            await showSurveyNodeSheet(context, ctrl, e.key);
            return;
          }
        }
        final shape = surveyShapeAt(s, x, y);
        if (shape != null) await showSurveyShapeSheet(context, ctrl, shape.id);
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
        String? seg;
        ctrl.edit((s) {
          final end = surveyNodeForTap(s, ox, oy);
          seg = surveyAddPipe(s, s.node(from.id)!, end)?.id;
          next = end.id;
        });
        setState(() {
          _drawFrom = next;
          _lastSeg = seg ?? _lastSeg;
        });
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
      case SurveyTool.point:
        final existing = surveyNodeAt(s, x, y);
        if (existing != null) {
          await showSurveyNodeSheet(context, ctrl, existing.id);
          return;
        }
        // Điểm mới: chưa có cụm máy thì gợi ý loại Cụm máy; huỷ thì bỏ điểm.
        final hasCompressor = s.nodes.any(
          (n) => n.kind == SurveyNodeKind.compressor,
        );
        String? id;
        ctrl.edit((s) => id = surveyNodeForTap(s, x, y).id);
        if (!mounted || id == null) return;
        final saved = await showSurveyNodeSheet(
          context,
          ctrl,
          id!,
          initialKind: hasCompressor
              ? SurveyNodeKind.junction
              : SurveyNodeKind.compressor,
        );
        if (!saved) ctrl.discardLast();
      case SurveyTool.wall:
        final p = Offset(surveySnap(x), surveySnap(y));
        final from = _shapeFrom;
        if (from == null) {
          setState(() => _shapeFrom = p);
          return;
        }
        // Tường đi ngang / dọc như ống; chạm lại điểm cuối: dừng.
        final end = (p.dx - from.dx).abs() >= (p.dy - from.dy).abs()
            ? Offset(p.dx, from.dy)
            : Offset(from.dx, p.dy);
        if ((end - from).distance < 1e-6) {
          setState(() => _shapeFrom = null);
          return;
        }
        ctrl.edit(
          (s) => s.shapes.add(
            SurveyShape(
              kind: SurveyShapeKind.wall,
              x1: from.dx,
              y1: from.dy,
              x2: end.dx,
              y2: end.dy,
            ),
          ),
        );
        setState(() => _shapeFrom = end);
      case SurveyTool.column:
        ctrl.edit(
          (s) => s.shapes.add(
            SurveyShape(
              kind: SurveyShapeKind.column,
              x1: surveySnap(x),
              y1: surveySnap(y),
            ),
          ),
        );
      case SurveyTool.obstacle:
        final p = Offset(surveySnap(x), surveySnap(y));
        final from = _shapeFrom;
        if (from == null) {
          setState(() => _shapeFrom = p);
          return;
        }
        if ((p.dx - from.dx).abs() < 1e-6 || (p.dy - from.dy).abs() < 1e-6) {
          return;
        }
        final shape = SurveyShape(
          kind: SurveyShapeKind.obstacle,
          x1: math.min(from.dx, p.dx),
          y1: math.min(from.dy, p.dy),
          x2: math.max(from.dx, p.dx),
          y2: math.max(from.dy, p.dy),
        );
        ctrl.edit((s) => s.shapes.add(shape));
        setState(() => _shapeFrom = null);
        if (mounted) await showSurveyShapeSheet(context, ctrl, shape.id);
      case SurveyTool.note:
        await _placeText(SurveyShape(kind: SurveyShapeKind.note, x1: x, y1: y));
      case SurveyTool.leader:
        final from = _shapeFrom;
        if (from == null) {
          setState(() => _shapeFrom = Offset(x, y));
          return;
        }
        setState(() => _shapeFrom = null);
        await _placeText(
          SurveyShape(
            kind: SurveyShapeKind.leader,
            x1: from.dx,
            y1: from.dy,
            x2: x,
            y2: y,
          ),
        );
      case SurveyTool.area:
        await _placeText(SurveyShape(kind: SurveyShapeKind.area, x1: x, y1: y));
      case SurveyTool.move:
        _toast('Nhấn giữ vật rồi rê để di chuyển.');
      case SurveyTool.erase:
        final hit = _pickAt(x, y, erase: true);
        if (hit == null) {
          _toast('Chạm đúng vật cần xoá.');
          return;
        }
        ctrl.edit((s) {
          if (hit.plant) {
            s.node(hit.node!)?.plant = null;
          } else if (hit.node case final id?) {
            final n = s.node(id);
            if (n != null) surveyEraseNode(s, n);
          } else if (hit.segment case final id?) {
            surveyDeleteSegment(s, id);
          } else if (hit.shape case final id?) {
            s.shapes.removeWhere((h) => h.id == id);
          }
        });
        if (hit.segment == _lastSeg) setState(() => _lastSeg = null);
      case SurveyTool.trim:
        // Chỉ tìm trong các tường (bỏ qua cột, chữ… nằm trên).
        final walls = PipeSurvey(
          shapes: [
            for (final h in s.shapes)
              if (h.kind == SurveyShapeKind.wall) h,
          ],
        );
        final wall = surveyShapeAt(walls, x, y);
        if (wall == null) {
          _toast('Chạm vào tường cần cắt.');
          return;
        }
        final bl = s.buildingLengthM, bw = s.buildingWidthM;
        final rects = [
          for (final p in ctrl.plants.values) p.room,
          if (bl != null && bw != null && bl > 0 && bw > 0)
            Rect.fromLTWH(0, 0, bl, bw),
        ];
        final done = ctrl.tryEdit(
          (s) => surveyTrimWall(s, wall, x, y, rects: rects),
        );
        if (!done) {
          _toast(
            'Đoạn tường không giao với cạnh nào để cắt — dùng Xoá để xoá cả đoạn.',
          );
        }
    }
  }

  Offset _toM(Offset local) => local / _ppm - _origin;

  /// Nhấn giữ (công cụ Di chuyển): chọn vật, nhớ vị trí gốc.
  void _dragStart(Offset local) {
    final m = _toM(local);
    final pick = _pickAt(m.dx, m.dy);
    if (pick == null) return;
    HapticFeedback.selectionClick();
    _dragNodes.clear();
    _dragShape = null;
    _dragDelta = Offset.zero;
    void keep(String? id) {
      final n = id == null ? null : s.node(id);
      if (n != null) _dragNodes[n.id] = Offset(n.x, n.y);
    }

    keep(pick.node);
    if (pick.segment case final id?) {
      final g = s.segments.where((g) => g.id == id).firstOrNull;
      keep(g?.a);
      keep(g?.b);
    }
    if (pick.shape case final id?) {
      final h = s.shapes.where((h) => h.id == id).firstOrNull;
      if (h != null) _dragShape = (h.x1, h.y1, h.x2, h.y2);
    }
    setState(() => _moving = pick);
  }

  /// Rê: dời theo lưới 0,5 m; lần dời đầu tiên lưu bản hoàn tác.
  void _dragUpdate(Offset local) {
    final pick = _moving;
    if (pick == null) return;
    final m = _toM(local);
    final d = Offset(
      surveySnap(m.dx) - surveySnap(pick.base.dx),
      surveySnap(m.dy) - surveySnap(pick.base.dy),
    );
    if (d == _dragDelta) return;
    if (_dragDelta == Offset.zero) ctrl.checkpoint();
    _dragDelta = d;
    ctrl.edit((s) {
      for (final e in _dragNodes.entries) {
        s.node(e.key)
          ?..x = e.value.dx + d.dx
          ..y = e.value.dy + d.dy;
      }
      final o = _dragShape;
      final h = pick.shape == null
          ? null
          : s.shapes.where((h) => h.id == pick.shape).firstOrNull;
      if (o != null && h != null) {
        h
          ..x1 = o.$1 + d.dx
          ..y1 = o.$2 + d.dy
          ..x2 = o.$3 + d.dx
          ..y2 = o.$4 + d.dy;
      }
    }, undoable: false);
  }

  void _dragEnd() => setState(() => _moving = null);

  void _undo() {
    ctrl.undo();
    _clearTransient();
  }

  void _redo() {
    ctrl.redo();
    _clearTransient();
  }

  void _clearTransient() => setState(() {
    _drawFrom = null;
    _shapeFrom = null;
    _moving = null;
    _lastSeg = null;
  });

  /// Hai hàng nút: công cụ vẽ chính + Undo / Redo; hiện trạng + Edit (menu
  /// sửa, chữ) + End (kết thúc nét đang vẽ).
  Widget _toolbar(BuildContext context) {
    Widget tool(SurveyTool t) => Expanded(
      child: _ToolCell(
        key: Key('survey_tool_${t.name}'),
        icon: t.icon,
        label: t.label,
        tooltip: t.hint,
        selected: _tool == t,
        onTap: () => _setTool(t),
      ),
    );
    final editTool = _tool.inEditMenu ? _tool : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
      child: Column(
        children: [
          Row(
            children: [
              for (final t in [
                SurveyTool.select,
                SurveyTool.pipe,
                SurveyTool.usePoint,
                SurveyTool.point,
              ])
                tool(t),
              Expanded(
                child: _ToolCell(
                  key: const Key('survey_undo'),
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  tooltip: 'Hoàn tác',
                  onTap: ctrl.canUndo ? _undo : null,
                ),
              ),
              Expanded(
                child: _ToolCell(
                  key: const Key('survey_redo'),
                  icon: Icons.redo_rounded,
                  label: 'Redo',
                  tooltip: 'Làm lại',
                  onTap: ctrl.canRedo ? _redo : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final t in [
                SurveyTool.wall,
                SurveyTool.column,
                SurveyTool.obstacle,
              ])
                tool(t),
              Expanded(
                flex: 2,
                child: PopupMenuButton<SurveyTool>(
                  key: const Key('survey_edit'),
                  tooltip: 'Edit: di chuyển, cắt, xoá, ghi chú…',
                  position: PopupMenuPosition.under,
                  onSelected: _setTool,
                  itemBuilder: (context) => [
                    for (final t in SurveyTool.values.where(
                      (t) => t.inEditMenu,
                    ))
                      PopupMenuItem(
                        key: Key('survey_edit_${t.name}'),
                        value: t,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          selected: _tool == t,
                          leading: Icon(t.icon),
                          title: Text(t.label),
                          subtitle: Text(
                            t.hint,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                  child: _ToolCell(
                    icon: editTool?.icon ?? Icons.edit_outlined,
                    label: editTool == null
                        ? 'Edit'
                        : 'Edit · ${editTool.label}',
                    selected: editTool != null,
                    dropdown: true,
                  ),
                ),
              ),
              Expanded(
                child: _ToolCell(
                  key: const Key('survey_finish'),
                  icon: Icons.stop_circle_outlined,
                  label: 'End',
                  tooltip: 'Kết thúc nét đang vẽ',
                  onTap: _drawing ? _stopDrawing : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plants = ctrl.plants;
    var maxX = s.nodes.fold(0.0, (m, n) => math.max(m, n.x));
    var maxY = s.nodes.fold(0.0, (m, n) => math.max(m, n.y));
    var minX = 0.0, minY = 0.0;
    for (final h in s.shapes) {
      maxX = math.max(maxX, math.max(h.x1, h.x2));
      maxY = math.max(maxY, math.max(h.y1, h.y2));
    }
    for (final p in plants.values) {
      final b = p.bounds;
      maxX = math.max(maxX, b.right);
      maxY = math.max(maxY, b.bottom);
      minX = math.min(minX, b.left);
      minY = math.min(minY, b.top);
    }
    // Gốc nguyên mét để lưới vẫn khớp; chừa 1 m cho chữ.
    _origin = Offset(
      minX < 0 ? (-minX).ceil() + 1.0 : 0,
      minY < 0 ? (-minY).ceil() + 1.0 : 0,
    );
    final w =
        [s.buildingLengthM ?? 0, maxX + 10, 40.0].reduce(math.max) + _origin.dx;
    final h =
        [s.buildingWidthM ?? 0, maxY + 10, 30.0].reduce(math.max) + _origin.dy;
    _canvasSize = Size(w * _ppm, h * _ppm);
    return Column(
      children: [
        _toolbar(context),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
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
                        // Di chuyển: nhấn giữ rồi rê.
                        onLongPressStart: _tool == SurveyTool.move
                            ? (d) => _dragStart(d.localPosition)
                            : null,
                        onLongPressMoveUpdate: _tool == SurveyTool.move
                            ? (d) => _dragUpdate(d.localPosition)
                            : null,
                        onLongPressEnd: _tool == SurveyTool.move
                            ? (_) => _dragEnd()
                            : null,
                        child: CustomPaint(
                          size: Size(w * _ppm, h * _ppm),
                          painter: SurveyPainter(
                            survey: s,
                            ppm: _ppm,
                            widthM: w,
                            heightM: h,
                            drawFrom: _drawFrom,
                            pendingPoint: _shapeFrom,
                            plants: plants,
                            originM: _origin,
                            selected: _moving,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Thanh nhập chiều dài đoạn vừa vẽ (đè lên sơ đồ, không đẩy
              // vùng vẽ).
              if (_lastSeg != null && s.segments.any((g) => g.id == _lastSeg))
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: _LengthBar(
                    key: ValueKey(_lastSeg),
                    ctrl: ctrl,
                    segmentId: _lastSeg!,
                    onClose: () => setState(() => _lastSeg = null),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nhập nhanh chiều dài đo thực tế của đoạn vừa vẽ: gõ số rồi Enter / ✓.
class _LengthBar extends StatefulWidget {
  const _LengthBar({
    super.key,
    required this.ctrl,
    required this.segmentId,
    required this.onClose,
  });
  final PipeSurveyController ctrl;
  final String segmentId;
  final VoidCallback onClose;

  @override
  State<_LengthBar> createState() => _LengthBarState();
}

class _LengthBarState extends State<_LengthBar> {
  late final _text = TextEditingController(
    text: formatSurveyNumber(_segment?.measuredM),
  );

  SurveySegment? get _segment => widget.ctrl.survey.segments
      .where((g) => g.id == widget.segmentId)
      .firstOrNull;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final len = parseSurveyNumber(_text.text);
    widget.ctrl.edit((s) {
      s.segments.where((g) => g.id == widget.segmentId).firstOrNull?.measuredM =
          len != null && len > 0 ? len : null;
    }, undoable: false);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final seg = _segment;
    final s = widget.ctrl.survey;
    final drawn = seg == null
        ? 0.0
        : surveySegmentDrawnLength(s.node(seg.a)!, s.node(seg.b)!);
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          children: [
            const Text('Đoạn vừa vẽ:'),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const Key('survey_last_length'),
                controller: _text,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Hình vẽ ${formatSurveyNumber(drawn)} m',
                  suffixText: 'm',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            IconButton(
              key: const Key('survey_last_length_save'),
              tooltip: 'Lưu chiều dài',
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
            ),
            IconButton(
              tooltip: 'Đóng',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
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
    this.pendingPoint,
    this.plants = const {},
    this.originM = Offset.zero,
    this.selected,
    this.showGrid = true,
    this.showTitle = true,
  });

  final PipeSurvey survey;
  final double ppm;
  final double widthM;
  final double heightM;
  final String? drawFrom;

  /// Điểm đang vẽ tường / góc chướng ngại thứ nhất (m).
  final Offset? pendingPoint;

  /// Cụm máy theo kích thước thật (theo id điểm Cụm máy).
  final Map<String, SurveyPlantLayout> plants;

  /// Toạ độ sơ đồ (m) của góc trên trái vùng vẽ là -[originM].
  final Offset originM;

  /// Vật đang chọn (tô sáng).
  final SurveyPick? selected;
  final bool showGrid;

  /// Vẽ khung tên bản vẽ ở góc dưới phải.
  final bool showTitle;

  static const _titleW = 300.0, _titleH = 92.0;

  /// Khung tên bản vẽ (px) trong vùng vẽ [size].
  static Rect titleBlockRect(Size size) => Rect.fromLTWH(
    size.width - _titleW - 16,
    size.height - _titleH - 16,
    _titleW,
    _titleH,
  );

  static const _pipe = Color(0xFF1F4E9D);
  static const _point = Color(0xFFEA580C);
  static const _compressor = Color(0xFF15803D);
  static const _riser = Color(0xFF7C3AED);

  @override
  void paint(Canvas canvas, Size size) {
    final s = survey;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    canvas.save();
    canvas.translate(originM.dx * ppm, originM.dy * ppm);
    final x0 = -originM.dx.round(), y0 = -originM.dy.round();
    if (showGrid) {
      final minor = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..strokeWidth = 0.6;
      final major = Paint()
        ..color = const Color(0xFFCBD5E1)
        ..strokeWidth = 1.1;
      for (var i = x0; i <= (widthM - originM.dx).ceil(); i++) {
        canvas.drawLine(
          Offset(i * ppm, y0 * ppm),
          Offset(i * ppm, size.height),
          i % 5 == 0 ? major : minor,
        );
        if (i % 5 == 0 && i != 0) {
          _text(
            canvas,
            '$i m',
            Offset(i * ppm + 2, y0 * ppm + 2),
            9,
            const Color(0xFF94A3B8),
          );
        }
      }
      for (var j = y0; j <= (heightM - originM.dy).ceil(); j++) {
        canvas.drawLine(
          Offset(x0 * ppm, j * ppm),
          Offset(size.width, j * ppm),
          j % 5 == 0 ? major : minor,
        );
        if (j % 5 == 0 && j != 0) {
          _text(
            canvas,
            '$j m',
            Offset(x0 * ppm + 2, j * ppm + 2),
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
    _shapes(canvas, s);
    for (final p in plants.values) {
      _plant(canvas, p);
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
      // Đổi cao độ giữa hai điểm: vòng tròn ống đứng giữa đoạn + chênh cao.
      final ea = a.hangHeightM ?? s.hangHeightM;
      final eb = b.hangHeightM ?? s.hangHeightM;
      if (ea != null && eb != null && (ea - eb).abs() > 1e-6) {
        canvas.drawCircle(mid, 6, Paint()..color = Colors.white);
        canvas.drawCircle(
          mid,
          6,
          Paint()
            ..color = _riser
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        canvas.drawCircle(mid, 2, Paint()..color = _riser);
        _text(
          canvas,
          '↕${_num((ea - eb).abs())} m',
          vertical ? mid.translate(-46, -6) : mid.translate(-14, 8),
          10,
          _riser,
          bold: true,
          background: true,
        );
      }
      // Vượt chướng ngại: bướu ∩ (lên) / ∪ (xuống) ở 3/4 đoạn.
      if (seg.hasObstacles) {
        final up = seg.obstacleRiseM! > 0;
        final at = Offset.lerp(pa, pb, 0.75)!;
        final dir = (pb - pa) / (pb - pa).distance;
        // Pháp tuyến: lên = phía trên (đoạn ngang) / bên trái (đoạn dọc).
        var normal = Offset(dir.dy, -dir.dx);
        if (normal.dy > 0 || (normal.dy == 0 && normal.dx > 0)) {
          normal = -normal;
        }
        if (!up) normal = -normal;
        const half = 9.0, height = 10.0;
        final p0 = at - dir * half, p1 = at + dir * half;
        canvas.drawLine(
          p0,
          p1,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 7,
        );
        canvas.drawPath(
          Path()
            ..moveTo(p0.dx, p0.dy)
            ..cubicTo(
              (p0 + normal * height * 1.3).dx,
              (p0 + normal * height * 1.3).dy,
              (p1 + normal * height * 1.3).dx,
              (p1 + normal * height * 1.3).dy,
              p1.dx,
              p1.dy,
            ),
          Paint()
            ..color = _riser
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
        _text(
          canvas,
          '${up ? '∩' : '∪'}×${seg.obstacles} ${_num(seg.obstacleRiseM!.abs())} m',
          // Chữ ở phía ngoài bướu, không đè lên ống.
          () {
            final tip = at + normal * (height + 4);
            return dir.dx.abs() > 0.5
                ? Offset(tip.dx - 18, normal.dy < 0 ? tip.dy - 14 : tip.dy + 2)
                : Offset(normal.dx > 0 ? tip.dx + 2 : tip.dx - 62, tip.dy - 6);
          }(),
          10,
          _riser,
          bold: true,
          background: true,
        );
      }
    }
    // Điểm.
    for (final n in s.nodes) {
      final p = Offset(n.x * ppm, n.y * ppm);
      switch (n.kind) {
        case SurveyNodeKind.junction:
          canvas.drawCircle(p, 3.5, Paint()..color = _pipe);
        case SurveyNodeKind.compressor when plants[n.id] != null:
          final plant = plants[n.id]!;
          canvas.drawCircle(p, 4.5, Paint()..color = _compressor);
          final room = plant.room;
          _text(
            canvas,
            [
              n.name.isEmpty ? 'Cụm máy' : n.name,
              '${_num(plant.roomLengthM)} × ${_num(plant.roomWidthM)} m',
            ].join(' · '),
            Offset(room.left * ppm, room.top * ppm - 16),
            11,
            _compressor,
            bold: true,
            background: true,
          );
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
      // Cao độ riêng tại điểm.
      if (n.hangHeightM != null && n.hangHeightM != s.hangHeightM) {
        _text(
          canvas,
          '▲${_num(n.hangHeightM!)} m',
          p.translate(6, -22),
          10,
          _riser,
          bold: true,
          background: true,
        );
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
    _notes(canvas, s);
    _highlight(canvas, s);
    canvas.restore();
    if (showTitle) _titleBlock(canvas, size, s);
  }

  /// Tô sáng vật đang chọn để dời.
  void _highlight(Canvas canvas, PipeSurvey s) {
    final pick = selected;
    if (pick == null) return;
    const amber = Color(0xFFF59E0B);
    final line = Paint()
      ..color = amber.withValues(alpha: 0.55)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final box = Paint()
      ..color = amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    Offset p(double x, double y) => Offset(x * ppm, y * ppm);
    if (pick.plant) {
      final plant = plants[pick.node];
      if (plant != null) {
        canvas.drawRect(
          Rect.fromPoints(
            plant.bounds.topLeft * ppm,
            plant.bounds.bottomRight * ppm,
          ).inflate(3),
          box,
        );
      }
      return;
    }
    if (pick.node case final id?) {
      final n = s.node(id);
      if (n != null) canvas.drawCircle(p(n.x, n.y), 13, box);
    }
    if (pick.segment case final id?) {
      final g = s.segments.where((g) => g.id == id).firstOrNull;
      final a = g == null ? null : s.node(g.a);
      final b = g == null ? null : s.node(g.b);
      if (a != null && b != null) {
        canvas.drawLine(p(a.x, a.y), p(b.x, b.y), line);
      }
    }
    if (pick.shape case final id?) {
      final h = s.shapes.where((h) => h.id == id).firstOrNull;
      if (h == null) return;
      if (h.kind == SurveyShapeKind.wall) {
        canvas.drawLine(p(h.x1, h.y1), p(h.x2, h.y2), line);
      } else {
        final r = surveyShapeBounds(h);
        canvas.drawRect(
          Rect.fromPoints(r.topLeft * ppm, r.bottomRight * ppm).inflate(4),
          box,
        );
      }
    }
  }

  /// Khung tên bản vẽ: tên bản vẽ, công trình, khách hàng, người khảo sát và
  /// ngày.
  void _titleBlock(Canvas canvas, Size size, PipeSurvey s) {
    final r = titleBlockRect(size);
    const ink = Color(0xFF0F172A);
    const line = Color(0xFF334155);
    canvas.drawRect(r, Paint()..color = Colors.white);
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(r, stroke);
    var title = _layout(s.drawingTitleOrDefault, 13, ink, bold: true);
    // Tên dài: thu nhỏ chữ cho vừa khung.
    if (title.width > r.width - 16) {
      title = _layout(
        s.drawingTitleOrDefault,
        math.max(8, 13 * (r.width - 16) / title.width),
        ink,
        bold: true,
      );
    }
    const headH = 28.0;
    canvas.save();
    canvas.clipRect(r);
    title.paint(
      canvas,
      Offset(r.center.dx - title.width / 2, r.top + (headH - title.height) / 2),
    );
    canvas.drawLine(
      Offset(r.left, r.top + headH),
      Offset(r.right, r.top + headH),
      stroke..strokeWidth = 1,
    );
    final d = s.surveyDate;
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final rows = [
      ('Công trình', s.name),
      ('Khách hàng', s.customer),
      ('Khảo sát', [s.surveyor, date].where((t) => t.isNotEmpty).join(' · ')),
    ];
    for (final (k, (label, value)) in rows.indexed) {
      final y = r.top + headH + 6 + k * 19.0;
      _layout(
        '$label:',
        10,
        const Color(0xFF64748B),
      ).paint(canvas, Offset(r.left + 8, y + 1));
      _layout(
        value.isEmpty ? '—' : value,
        11,
        ink,
        bold: true,
      ).paint(canvas, Offset(r.left + 84, y));
    }
    canvas.restore();
  }

  /// Cụm máy theo kích thước thật: vùng phòng tối thiểu (nét đứt), thiết bị
  /// đánh số + model như mặt bằng phòng lắp đặt, ống và lọc trong phòng.
  void _plant(Canvas canvas, SurveyPlantLayout plant) {
    Offset p(Offset m) => m * ppm;
    Rect r(Rect m) => Rect.fromPoints(p(m.topLeft), p(m.bottomRight));
    final room = r(plant.room);
    canvas.drawRect(room, Paint()..color = RoomColors.zone);
    _dashedRect(canvas, room, RoomColors.zoneLine);
    final branch = Paint()
      ..color = AirDiagramColors.main
      ..strokeWidth = 1.6;
    for (final (a, b) in plant.branches) {
      canvas.drawLine(p(a), p(b), branch);
    }
    void line(List<Offset> pts, Color color) {
      if (pts.length < 2) return;
      final path = Path()..moveTo(p(pts.first).dx, p(pts.first).dy);
      for (final q in pts.skip(1)) {
        path.lineTo(p(q).dx, p(q).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    line(plant.mainPipe, AirDiagramColors.main);
    line(plant.supplyPipe, AirDiagramColors.supply);
    for (final i in plant.items) {
      final (fill, stroke) = RoomColors.of(i.kind);
      final rect = r(i.rect);
      final fillPaint = Paint()..color = fill;
      final strokePaint = Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      if (i.isRound) {
        canvas
          ..drawCircle(rect.center, rect.shortestSide / 2, fillPaint)
          ..drawCircle(rect.center, rect.shortestSide / 2, strokePaint);
      } else {
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(2));
        canvas
          ..drawRRect(rr, fillPaint)
          ..drawRRect(rr, strokePaint);
      }
      // Số thứ tự; model khi đủ chỗ (tủ điện chỉ ghi số).
      final model = i.kind == RoomItemKind.panel ? null : i.model;
      final number = _layout('${i.number}', 10, stroke, bold: true);
      final label = model == null
          ? null
          : _layout(model, 8, AirDiagramColors.text);
      final inner = i.isRound ? rect.shortestSide * 0.72 : rect.width - 4;
      final showModel =
          label != null && label.width <= inner && rect.height >= 26;
      final textH = number.height + (showModel ? label.height : 0);
      final top = rect.center.dy - textH / 2;
      number.paint(canvas, Offset(rect.center.dx - number.width / 2, top));
      if (showModel) {
        label.paint(
          canvas,
          Offset(rect.center.dx - label.width / 2, top + number.height),
        );
      }
    }
    final fs = math.max(5.0, plant.filterSizeM * ppm);
    // Chữ L1, L2… lệch vuông góc ống, về phía trong phòng.
    final side = Offset(-plant.outDir.dy, plant.outDir.dx);
    for (final (at, n) in plant.filters) {
      final c = p(at);
      final rect = Rect.fromCenter(center: c, width: fs, height: fs);
      canvas
        ..drawRect(rect, Paint()..color = AirDiagramColors.filterBowl)
        ..drawRect(
          rect,
          Paint()
            ..color = AirDiagramColors.filterHead
            ..style = PaintingStyle.stroke,
        );
      final t = _layout('L$n', 8, AirDiagramColors.filterHead, bold: true);
      final toRoom = room.center - c;
      final into = toRoom.dx * side.dx + toRoom.dy * side.dy >= 0
          ? side
          : -side;
      final at2 = c + into * (fs / 2 + 7);
      t.paint(canvas, at2 - Offset(t.width / 2, t.height / 2));
    }
  }

  void _dashedRect(Canvas canvas, Rect r, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    void dash(Offset a, Offset b) {
      final len = (b - a).distance;
      if (len == 0) return;
      final u = (b - a) / len;
      for (var t = 0.0; t < len; t += 8) {
        canvas.drawLine(a + u * t, a + u * math.min(len, t + 4), paint);
      }
    }

    dash(r.topLeft, r.topRight);
    dash(r.topRight, r.bottomRight);
    dash(r.bottomRight, r.bottomLeft);
    dash(r.bottomLeft, r.topLeft);
  }

  TextPainter _layout(
    String text,
    double size,
    Color color, {
    bool bold = false,
  }) => TextPainter(
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

  static const _wall = Color(0xFF475569);
  static const _obstacle = Color(0xFFDC2626);

  /// Hình nền: tường, cột, chướng ngại (dưới ống); ghi chú vẽ sau cùng.
  void _shapes(Canvas canvas, PipeSurvey s) {
    Offset p(double x, double y) => Offset(x * ppm, y * ppm);
    for (final h in s.shapes) {
      switch (h.kind) {
        case SurveyShapeKind.wall:
          canvas.drawLine(
            p(h.x1, h.y1),
            p(h.x2, h.y2),
            Paint()
              ..color = _wall
              ..strokeWidth = math.max(
                4,
                (h.sizeM ?? surveyWallThicknessM) * ppm,
              )
              ..strokeCap = StrokeCap.square,
          );
          if (h.label.isNotEmpty) {
            _text(
              canvas,
              h.label,
              (p(h.x1, h.y1) + p(h.x2, h.y2)) / 2 + const Offset(4, 4),
              10,
              _wall,
              background: true,
            );
          }
        case SurveyShapeKind.column:
          final w = h.sizeM ?? surveyColumnSizeM;
          final d = h.size2M ?? w;
          final r = Rect.fromCenter(
            center: p(h.x1, h.y1),
            width: math.max(8, w * ppm),
            height: math.max(8, d * ppm),
          );
          canvas.drawRect(r, Paint()..color = _wall);
          canvas.drawLine(
            r.topLeft,
            r.bottomRight,
            Paint()
              ..color = Colors.white
              ..strokeWidth = 1,
          );
          canvas.drawLine(
            r.topRight,
            r.bottomLeft,
            Paint()
              ..color = Colors.white
              ..strokeWidth = 1,
          );
          if (h.label.isNotEmpty) {
            _text(
              canvas,
              h.label,
              r.topRight + const Offset(3, -12),
              10,
              _wall,
              bold: true,
              background: true,
            );
          }
        case SurveyShapeKind.obstacle:
          final r = Rect.fromPoints(p(h.x1, h.y1), p(h.x2, h.y2));
          canvas.drawRect(
            r,
            Paint()..color = _obstacle.withValues(alpha: 0.08),
          );
          // Gạch chéo.
          canvas.save();
          canvas.clipRect(r);
          final hatch = Paint()
            ..color = _obstacle.withValues(alpha: 0.35)
            ..strokeWidth = 1;
          for (var t = -r.height; t < r.width; t += 10) {
            canvas.drawLine(
              Offset(r.left + t, r.bottom),
              Offset(r.left + t + r.height, r.top),
              hatch,
            );
          }
          canvas.restore();
          canvas.drawRect(
            r,
            Paint()
              ..color = _obstacle
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
          if (h.label.isNotEmpty) {
            _text(
              canvas,
              h.label,
              r.topLeft + const Offset(4, 3),
              10,
              _obstacle,
              bold: true,
              background: true,
            );
          }
        case SurveyShapeKind.area:
          final t = (h.sizeM ?? surveyAreaTextM) * ppm;
          final tp = TextPainter(
            text: TextSpan(
              text: h.label.toUpperCase(),
              style: TextStyle(
                fontSize: t * 0.8,
                height: 1.2,
                letterSpacing: t * 0.06,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B).withValues(alpha: 0.55),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, p(h.x1, h.y1) - Offset(tp.width / 2, tp.height / 2));
        case SurveyShapeKind.note:
        case SurveyShapeKind.leader:
          break;
      }
    }
    final pending = pendingPoint;
    if (pending != null) {
      final c = p(pending.dx, pending.dy);
      canvas.drawCircle(
        c,
        10,
        Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      canvas.drawCircle(c, 2.5, Paint()..color = const Color(0xFFF59E0B));
    }
  }

  void _notes(Canvas canvas, PipeSurvey s) {
    const ink = Color(0xFF0F172A);
    for (final h in s.shapes) {
      if (h.kind == SurveyShapeKind.leader && h.label.isNotEmpty) {
        final tip = Offset(h.x1 * ppm, h.y1 * ppm);
        final at = Offset(h.x2 * ppm, h.y2 * ppm);
        final paint = Paint()
          ..color = ink
          ..strokeWidth = 1.2;
        canvas.drawLine(at, tip, paint);
        // Mũi tên đặc tại điểm chỉ.
        final d = at - tip;
        if (d.distance > 1) {
          final u = d / d.distance;
          final n = Offset(-u.dy, u.dx);
          canvas.drawPath(
            Path()
              ..moveTo(tip.dx, tip.dy)
              ..lineTo((tip + u * 9 + n * 3.5).dx, (tip + u * 9 + n * 3.5).dy)
              ..lineTo((tip + u * 9 - n * 3.5).dx, (tip + u * 9 - n * 3.5).dy)
              ..close(),
            Paint()..color = ink,
          );
        }
        // Chữ phía đầu kia, lệch theo hướng mũi tên.
        final tp = _layout(h.label, 11, ink);
        final left = d.dx >= 0 ? at.dx + 2 : at.dx - tp.width - 2;
        final top = d.dy >= 0 ? at.dy : at.dy - tp.height;
        _text(canvas, h.label, Offset(left, top), 11, ink, background: true);
        continue;
      }
      if (h.kind != SurveyShapeKind.note || h.label.isEmpty) continue;
      _text(
        canvas,
        h.label,
        Offset(h.x1 * ppm, h.y1 * ppm),
        11,
        const Color(0xFF0F172A),
        background: true,
      );
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

/// Vật được chọn trên sơ đồ: điểm, đoạn ống hoặc hình nền; [plant] = chạm
/// vào khung cụm máy của điểm [node]. [base]: vị trí chạm lúc chọn (m).
class SurveyPick {
  const SurveyPick(
    this.base, {
    this.node,
    this.segment,
    this.shape,
    this.plant = false,
  });
  final Offset base;
  final String? node;
  final String? segment;
  final String? shape;
  final bool plant;
}

/// Một nút trên thanh công cụ: biểu tượng trên, chữ dưới (thu nhỏ cho vừa).
/// [onTap] `null` và không có [selected]: nút mờ (không dùng được), trừ khi
/// nằm trong nút menu ([dropdown]).
class _ToolCell extends StatelessWidget {
  const _ToolCell({
    super.key,
    required this.icon,
    required this.label,
    this.tooltip,
    this.selected = false,
    this.dropdown = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final bool selected;
  final bool dropdown;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null || dropdown;
    final color = !enabled
        ? scheme.onSurface.withValues(alpha: 0.35)
        : selected
        ? scheme.onSecondaryContainer
        : scheme.onSurface;
    final body = Container(
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: selected ? scheme.secondaryContainer : null,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: color),
              if (dropdown) Icon(Icons.arrow_drop_down, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 2),
          // Tên dài (Điểm trên sơ đồ…) xuống 2 dòng, quá nữa thì thu nhỏ.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 64),
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.1,
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final cell = onTap == null
        ? body
        : InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: body,
          );
    return tooltip == null
        ? cell
        : Tooltip(
            message: tooltip!,
            waitDuration: const Duration(milliseconds: 600),
            child: cell,
          );
  }
}
