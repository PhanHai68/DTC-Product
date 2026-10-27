import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../diagram/air_diagram.dart';
import '../diagram/air_diagram_render.dart';
import '../models/air_config.dart';
import '../providers/air_config_editor_controller.dart';
import '../room/room_engine.dart';
import '../room/room_strings.dart';
import '../services/air_config_export_service.dart';
import '../services/air_file_saver.dart';
import 'air_config_form.dart' show AirNumberField;
import 'air_room_editor.dart';

/// Tab "Phòng lắp đặt": phòng thực tế (tuỳ chọn), cách xếp, cửa; kích thước
/// phòng, thông gió, ống chính; bản vẽ mặt bằng (bấm để phóng to), xuất
/// PNG / PDF.
class AirRoomView extends StatelessWidget {
  const AirRoomView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AirConfigEditorController>();
    final room = ctrl.room;
    final drawing = ctrl.roomDrawing;
    if (room == null || drawing == null) return const SizedBox.shrink();
    return ListView(
      key: const PageStorageKey('air_room_view'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        _RoomInput(ctrl: ctrl, result: room),
        if (room.warnings.isNotEmpty) _RoomWarnings(ctrl: ctrl, room: room),
        _RoomCards(ctrl: ctrl, room: room),
        const SizedBox(height: 12),
        _RoomDrawingCard(ctrl: ctrl, drawing: drawing),
      ],
    );
  }
}

class _RoomInput extends StatelessWidget {
  const _RoomInput({required this.ctrl, required this.result});
  final AirConfigEditorController ctrl;
  final RoomResult result;

  @override
  Widget build(BuildContext context) {
    final s = ctrl.strings;
    final room = ctrl.config.room;
    final scheme = Theme.of(context).colorScheme;
    Widget field(String label, double? value, void Function(double?) set) =>
        Expanded(
          child: AirNumberField(
            // Đổi ngôn ngữ thì dựng lại nhãn.
            key: ValueKey(
              'room_${label}_${ctrl.lang.name}_${ctrl.roomSizeRevision}',
            ),
            label: label,
            value: value,
            onChanged: (v) => ctrl.edit((_) => set(v)),
          ),
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.meeting_room_outlined,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.roomInputTitle,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              s.roomInputHint,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                field(s.roomLength, room.lengthM, (v) => room.lengthM = v),
                const SizedBox(width: 8),
                field(s.roomWidth, room.widthM, (v) => room.widthM = v),
                const SizedBox(width: 8),
                field(s.roomHeight, room.heightM, (v) => room.heightM = v),
              ],
            ),
            Text(s.roomStyleLabel),
            const SizedBox(height: 6),
            _RoomOptions(ctrl: ctrl, result: result),
            const SizedBox(height: 12),
            Text(s.roomDoorLabel),
            const SizedBox(height: 6),
            SegmentedButton<RoomDoorWall>(
              key: const Key('room_door'),
              showSelectedIcon: false,
              segments: [
                for (final v in RoomDoorWall.values)
                  ButtonSegment(value: v, label: Text(s.roomDoorWall(v))),
              ],
              selected: {room.door},
              onSelectionChanged: (v) =>
                  ctrl.edit((c) => c.room.door = v.first),
            ),
            const SizedBox(height: 16),
            Text(
              s.roomVentInputTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              s.roomVentFormula,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            // Trống = mặc định (35 °C / 46 °C) trong hằng số.
            AirNumberField(
              key: ValueKey(
                'room_t1_${ctrl.lang.name}_${ctrl.roomSizeRevision}',
              ),
              label: s.roomOutsideTemp,
              value: result.ventilation.outsideTempC,
              onChanged: (v) => ctrl.edit((c) => c.room.outsideTempC = v),
            ),
            AirNumberField(
              key: ValueKey(
                'room_t2_${ctrl.lang.name}_${ctrl.roomSizeRevision}',
              ),
              label: s.roomInletTemp,
              value: result.ventilation.inletMaxTempC,
              onChanged: (v) => ctrl.edit((c) => c.room.inletMaxTempC = v),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3 phương án lắp đặt: hình minh hoạ có tên thiết bị, tên phương án, lọt
/// phòng thực tế không. Bấm để chọn.
class _RoomOptions extends StatelessWidget {
  const _RoomOptions({required this.ctrl, required this.result});
  final AirConfigEditorController ctrl;
  final RoomResult result;

  /// Kích thước gốc (dài × sâu khi đặt dọc tường) của các thiết bị chính
  /// theo thứ tự dãy, bỏ hướng xoay của phương án đang chọn.
  List<(RoomItemKind, double, double)> get _units => [
    for (final i in result.items)
      if (i.kind != RoomItemKind.panel)
        i.rotated
            ? (i.kind, i.depthMm, i.lengthMm)
            : (i.kind, i.lengthMm, i.depthMm),
  ];

  @override
  Widget build(BuildContext context) {
    final s = ctrl.strings;
    final scheme = Theme.of(context).colorScheme;
    final selected = ctrl.config.room.style;
    final units = _units;
    final labels = {
      for (final k in RoomItemKind.values) k: s.roomSketchLabel(k),
    };

    Widget option(RoomOption o, {required bool wide}) {
      final on = o.style == selected;
      final sketch = SizedBox(
        height: 64,
        child: CustomPaint(painter: _OptionSketch(o.style, units, labels)),
      );
      final texts = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.roomStyle(o.style),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            s.roomStyleHint(o.style),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (result.actual)
            Text(
              o.fits ? s.roomFits : s.roomNotFit,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: o.fits
                    ? const Color(0xFF15803D)
                    : const Color(0xFFB91C1C),
              ),
            ),
        ],
      );
      return InkWell(
        key: Key('room_option_${o.style.name}'),
        borderRadius: BorderRadius.circular(12),
        // Đổi phương án: vị trí chỉnh tay và phép đo không còn đúng → bỏ.
        onTap: () => ctrl.edit(
          (c) => c.room
            ..style = o.style
            ..positions.clear()
            ..turned.clear()
            ..measures.clear(),
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: on ? scheme.secondaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on ? scheme.primary : scheme.outlineVariant,
              width: on ? 2 : 1,
            ),
          ),
          // Màn rộng: hình trên, chữ dưới; điện thoại: hình trái, chữ phải.
          child: wide
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [sketch, const SizedBox(height: 6), texts],
                )
              : Row(
                  children: [
                    Expanded(flex: 3, child: sketch),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: texts),
                  ],
                ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        if (!wide) {
          return Column(
            children: [
              for (var k = 0; k < result.options.length; k++) ...[
                if (k > 0) const SizedBox(height: 8),
                option(result.options[k], wide: false),
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var k = 0; k < result.options.length; k++) ...[
                if (k > 0) const SizedBox(width: 8),
                Expanded(child: option(result.options[k], wide: true)),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Hình minh hoạ phương án: tường sau, các thiết bị đúng tỉ lệ thật với
/// nhau (máy nén, bình tròn, máy sấy), xếp sát dọc tường, có tên thiết bị.
/// Phương án 2 xoay máy sấy, phương án 3 xoay máy nén và máy sấy.
class _OptionSketch extends CustomPainter {
  _OptionSketch(this.style, this.units, this.labels);
  final RoomStyle style;
  final List<(RoomItemKind, double, double)> units;
  final Map<RoomItemKind, String> labels;

  static const _colors = {
    RoomItemKind.compressor: Color(0xFF15803D),
    RoomItemKind.tank: Color(0xFF1F4E9D),
    RoomItemKind.dryer: Color(0xFF0284C7),
    RoomItemKind.afterCooler: Color(0xFF6D28D9),
  };

  bool _turned(RoomItemKind k) =>
      (k == RoomItemKind.dryer && style != RoomStyle.option1) ||
      (k == RoomItemKind.compressor && style == RoomStyle.option3);

  @override
  void paint(Canvas canvas, Size size) {
    if (units.isEmpty) return;
    final w = size.width;
    final h = size.height;
    const wallH = 5.0;
    const gapPx = 6.0;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, wallH),
      Paint()..color = const Color(0xFF94A3B8),
    );
    final boxes = [
      for (final (k, l, d) in units) _turned(k) ? (k, d, l) : (k, l, d),
    ];
    // Cùng một tỉ lệ cho mọi thiết bị, vừa khung, khe hở nhỏ cố định.
    final totalW = boxes.fold(0.0, (t, b) => t + b.$2);
    final maxD = boxes.fold(0.0, (m, b) => m > b.$3 ? m : b.$3);
    final scale = [
      (w - gapPx * (boxes.length + 1)) / totalW,
      (h - wallH - 6) / maxD,
    ].reduce((a, b) => a < b ? a : b);
    final used = totalW * scale + gapPx * (boxes.length - 1);
    var x = (w - used) / 2;
    for (final (k, l, d) in boxes) {
      final rect = Rect.fromLTWH(x, wallH + 3, l * scale, d * scale);
      final paint = Paint()..color = _colors[k] ?? const Color(0xFF475569);
      if (k == RoomItemKind.tank) {
        canvas.drawCircle(rect.center, rect.shortestSide / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          paint,
        );
      }
      _label(canvas, labels[k] ?? '', rect, round: k == RoomItemKind.tank);
      x += rect.width + gapPx;
    }
  }

  /// Tên thiết bị giữa khối, tự xuống dòng / thu nhỏ cho vừa.
  void _label(Canvas canvas, String text, Rect rect, {bool round = false}) {
    final box = round ? rect.deflate(rect.width * 0.15) : rect.deflate(2);
    for (var size = 10.0; size >= 6; size -= 1) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white,
            fontSize: size,
            fontWeight: FontWeight.w600,
            height: 1.05,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: box.width);
      final fits =
          painter.height <= box.height &&
          painter.computeLineMetrics().every((m) => m.width <= box.width + 0.5);
      if (fits || size <= 6) {
        painter.paint(
          canvas,
          box.center - Offset(painter.width / 2, painter.height / 2),
        );
        return;
      }
    }
  }

  @override
  bool shouldRepaint(_OptionSketch old) =>
      old.style != style || old.units != units || old.labels != labels;
}

class _RoomWarnings extends StatelessWidget {
  const _RoomWarnings({required this.ctrl, required this.room});
  final AirConfigEditorController ctrl;
  final RoomResult room;

  @override
  Widget build(BuildContext context) {
    final s = ctrl.strings;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final w in room.warnings)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: w.code == RoomWarningCode.estimated
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      w.code == RoomWarningCode.estimated
                          ? Icons.info_outline
                          : Icons.warning_amber_rounded,
                      size: 18,
                      color: w.code == RoomWarningCode.estimated
                          ? const Color(0xFF475569)
                          : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.roomWarning(w),
                        style: const TextStyle(color: Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoomCards extends StatelessWidget {
  const _RoomCards({required this.ctrl, required this.room});
  final AirConfigEditorController ctrl;
  final RoomResult room;

  @override
  Widget build(BuildContext context) {
    final s = ctrl.strings;
    final cards = [
      (
        Icons.square_foot_rounded,
        s.roomCardSize,
        s.roomSize(room),
        s.roomCardSizeSub(room),
      ),
      (
        Icons.air_rounded,
        s.roomCardVent,
        s.roomVentValue(room),
        s.roomVentSub(room),
      ),
      (
        Icons.linear_scale_rounded,
        s.roomCardPipe,
        s.roomPipeValue(room),
        s.roomPipeSub(room),
      ),
      (
        Icons.door_front_door_outlined,
        s.roomCardDoor,
        s.roomDoorValue(room),
        s.roomDoorSub(room),
      ),
    ];
    final scheme = Theme.of(context).colorScheme;
    Widget card((IconData, String, String, String) c) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(c.$1, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.$2,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            c.$3,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            c.$4,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 300
            ? 2
            : 1;
        return Column(
          children: [
            for (var i = 0; i < cards.length; i += columns)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var k = i; k < i + columns; k++) ...[
                        if (k > i) const SizedBox(width: 10),
                        Expanded(
                          child: k < cards.length
                              ? card(cards[k])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RoomDrawingCard extends StatefulWidget {
  const _RoomDrawingCard({required this.ctrl, required this.drawing});
  final AirConfigEditorController ctrl;
  final AirDiagram drawing;

  @override
  State<_RoomDrawingCard> createState() => _RoomDrawingCardState();
}

class _RoomDrawingCardState extends State<_RoomDrawingCard> {
  bool _busy = false;

  void _open() {
    final ctrl = widget.ctrl;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: ctrl,
          child: Scaffold(
            appBar: AppBar(title: Text(ctrl.strings.roomDrawingTitle)),
            body: const AirRoomEditor(),
          ),
        ),
      ),
    );
  }

  Future<void> _export({required bool pdf}) async {
    final ctrl = widget.ctrl;
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      final base = AirConfigExportService.baseName(ctrl.config, DateTime.now());
      // PDF: một file gồm sơ đồ lắp đặt (trang 1) và mặt bằng (trang 2).
      final file = pdf
          ? await AirConfigExportService.pdf(
              ctrl.config,
              ctrl.strings,
              ctrl.diagram,
              base,
              room: widget.drawing,
              roomHeading: ctrl.strings.roomDrawingTitle,
            )
          : await AirConfigExportService.png(
              widget.drawing,
              '${base}_PhongMay',
            );
      await deliverAirExport(file, origin: origin);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không xuất được file: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.ctrl.strings;
    final d = widget.drawing;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.roomDrawingTitle,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  IconButton(
                    key: const Key('room_export_png'),
                    tooltip: s.exportRoomPng,
                    onPressed: () => _export(pdf: false),
                    icon: const Icon(Icons.image_outlined),
                  ),
                  IconButton(
                    key: const Key('room_export_pdf'),
                    tooltip: s.exportRoomPdf,
                    onPressed: () => _export(pdf: true),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                ],
                IconButton(
                  key: const Key('room_open_editor'),
                  tooltip: s.roomEditTooltip,
                  onPressed: _open,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _open,
            child: AspectRatio(
              aspectRatio: d.width / d.height,
              child: FittedBox(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const Key('room_drawing_canvas'),
                    size: Size(d.width, d.height),
                    painter: AirDiagramPainter(d),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
