import 'package:flutter/material.dart';

import '../engine/survey_bom.dart';
import '../engine/survey_geometry.dart';
import '../models/pipe_survey.dart';
import '../providers/pipe_survey_controller.dart';
import 'survey_plant_dialog.dart';

/// Số nhập tay: nhận "2,5" và "2.5"; trống = `null`.
double? parseSurveyNumber(String text) {
  final t = text.trim().replaceAll(',', '.');
  return t.isEmpty ? null : double.tryParse(t);
}

String formatSurveyNumber(double? v) {
  if (v == null) return '';
  return v == v.roundToDouble()
      ? '${v.round()}'
      : v.toString().replaceAll('.', ',');
}

InputDecoration _decoration(String label, {String? hint, String? suffix}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffix,
      isDense: true,
      border: const OutlineInputBorder(),
    );

/// Nút xoá / huỷ / lưu chung cho hai hộp sửa.
List<Widget> _actions(
  BuildContext context, {
  required String deleteKey,
  required String deleteLabel,
  required String saveKey,
  required VoidCallback onSave,
}) => [
  TextButton(
    key: Key(deleteKey),
    onPressed: () => Navigator.pop(context, const _Delete()),
    style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
    child: Text(deleteLabel),
  ),
  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
  FilledButton(key: Key(saveKey), onPressed: onSave, child: const Text('Lưu')),
];

sealed class _Result {
  const _Result();
}

class _Delete extends _Result {
  const _Delete();
}

class _SaveSegment extends _Result {
  const _SaveSegment(
    this.measuredM,
    this.dn,
    this.note,
    this.obstacles,
    this.obstacleRiseM,
  );
  final double? measuredM;
  final int? dn;
  final String note;
  final int obstacles;
  final double? obstacleRiseM;
}

class _SaveNode extends _Result {
  const _SaveNode({
    required this.kind,
    required this.name,
    required this.hangHeightM,
    required this.connectionHeightM,
    required this.dropDn,
    required this.note,
    required this.plant,
  });
  final SurveyNodeKind kind;
  final SurveyPlant? plant;
  final String name;
  final double? hangHeightM;
  final double? connectionHeightM;
  final int? dropDn;
  final String note;
}

/// Hộp sửa đoạn ống: chiều dài đo thực tế, cỡ ống, ghi chú; xoá đoạn.
Future<void> showSurveySegmentSheet(
  BuildContext context,
  PipeSurveyController ctrl,
  String segmentId,
) async {
  final seg = ctrl.survey.segments.where((g) => g.id == segmentId).firstOrNull;
  if (seg == null) return;
  final result = await showDialog<_Result>(
    context: context,
    builder: (_) => _SegmentDialog(ctrl: ctrl, segment: seg),
  );
  switch (result) {
    case null:
      return;
    case _Delete():
      ctrl.edit((s) => surveyDeleteSegment(s, segmentId));
    case final _SaveSegment r:
      ctrl.edit((s) {
        s.segments.firstWhere((g) => g.id == segmentId)
          ..measuredM = r.measuredM
          ..dn = r.dn
          ..note = r.note
          ..obstacles = r.obstacles
          ..obstacleRiseM = r.obstacleRiseM;
      });
    case _SaveNode():
      return;
  }
}

class _SegmentDialog extends StatefulWidget {
  const _SegmentDialog({required this.ctrl, required this.segment});
  final PipeSurveyController ctrl;
  final SurveySegment segment;

  @override
  State<_SegmentDialog> createState() => _SegmentDialogState();
}

class _SegmentDialogState extends State<_SegmentDialog> {
  late final _measured = TextEditingController(
    text: formatSurveyNumber(widget.segment.measuredM),
  );
  late final _note = TextEditingController(text: widget.segment.note);
  late int? _dn = widget.segment.dn;
  late final _obstacles = TextEditingController(
    text: widget.segment.obstacles == 0 ? '' : '${widget.segment.obstacles}',
  );
  late final _rise = TextEditingController(
    text: formatSurveyNumber(widget.segment.obstacleRiseM?.abs()),
  );
  late bool _up = (widget.segment.obstacleRiseM ?? 1) >= 0;

  @override
  void dispose() {
    for (final c in [_measured, _note, _obstacles, _rise]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.ctrl.survey;
    final seg = widget.segment;
    final drawn = surveySegmentDrawnLength(s.node(seg.a)!, s.node(seg.b)!);
    return AlertDialog(
      title: const Text('Đoạn ống'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Theo hình vẽ: ${formatSurveyNumber(drawn)} m'),
            const SizedBox(height: 10),
            TextField(
              key: const Key('survey_segment_length'),
              controller: _measured,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _decoration(
                'Chiều dài đo thực tế',
                hint: 'Trống = theo hình vẽ',
                suffix: 'm',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              key: const Key('survey_segment_dn'),
              initialValue: _dn,
              decoration: _decoration('Cỡ ống'),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text('Mặc định (DN${s.defaultDn})'),
                ),
                for (final size in widget.ctrl.constants.sizes)
                  DropdownMenuItem(value: size, child: Text('DN$size')),
              ],
              onChanged: (v) => setState(() => _dn = v),
            ),
            const SizedBox(height: 14),
            const Text(
              'Vượt chướng ngại (lên / xuống rồi trở lại cao độ cũ)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('survey_segment_obstacles'),
                    controller: _obstacles,
                    keyboardType: TextInputType.number,
                    decoration: _decoration('Số lần', hint: '0'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const Key('survey_segment_rise'),
                    controller: _rise,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _decoration('Chênh cao', suffix: 'm'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              key: const Key('survey_segment_direction'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Vượt lên ∩')),
                ButtonSegment(value: false, label: Text('Vượt xuống ∪')),
              ],
              selected: {_up},
              onSelectionChanged: (v) => setState(() => _up = v.first),
            ),
            const SizedBox(height: 10),
            TextField(controller: _note, decoration: _decoration('Ghi chú')),
          ],
        ),
      ),
      actions: _actions(
        context,
        deleteKey: 'survey_segment_delete',
        deleteLabel: 'Xoá đoạn',
        saveKey: 'survey_segment_save',
        onSave: () {
          final len = parseSurveyNumber(_measured.text);
          final count = int.tryParse(_obstacles.text.trim()) ?? 0;
          final rise = parseSurveyNumber(_rise.text)?.abs();
          final hasObstacle = count > 0 && rise != null && rise > 0;
          Navigator.pop(
            context,
            _SaveSegment(
              len != null && len > 0 ? len : null,
              _dn,
              _note.text.trim(),
              hasObstacle ? count : 0,
              hasObstacle ? (_up ? rise : -rise) : null,
            ),
          );
        },
      ),
    );
  }
}

/// Hộp sửa điểm: loại điểm, tên; điểm sử dụng có độ cao treo riêng, cao độ
/// đầu nối, cỡ ống đứng; xoá điểm. [initialKind]: loại chọn sẵn (điểm mới).
/// Trả `true` khi đã lưu hoặc xoá, `false` khi huỷ.
Future<bool> showSurveyNodeSheet(
  BuildContext context,
  PipeSurveyController ctrl,
  String nodeId, {
  SurveyNodeKind? initialKind,
}) async {
  final node = ctrl.survey.node(nodeId);
  if (node == null) return false;
  final result = await showDialog<_Result>(
    context: context,
    builder: (_) =>
        _NodeDialog(ctrl: ctrl, node: node, initialKind: initialKind),
  );
  switch (result) {
    case null:
    case _SaveSegment():
      return false;
    case _Delete():
      ctrl.edit((s) => surveyDeleteNode(s, nodeId));
    case final _SaveNode r:
      ctrl.edit((s) {
        // Chỉ một cụm máy; đổi sang điểm khác thì mang theo thiết bị đã chọn.
        SurveyPlant? carried;
        if (r.kind == SurveyNodeKind.compressor) {
          for (final other in s.nodes) {
            if (other.id != nodeId && other.kind == SurveyNodeKind.compressor) {
              carried ??= other.plant;
              other
                ..kind = SurveyNodeKind.junction
                ..name = ''
                ..plant = null;
            }
          }
        }
        final name = r.name.isNotEmpty
            ? r.name
            : switch (r.kind) {
                SurveyNodeKind.compressor => 'Cụm máy',
                SurveyNodeKind.usePoint =>
                  'Điểm sử dụng ${s.usePoints.where((n) => n.id != nodeId).length + 1}',
                SurveyNodeKind.junction => '',
              };
        s.node(nodeId)!
          ..kind = r.kind
          ..name = name
          ..note = r.note
          ..hangHeightM = r.hangHeightM
          ..connectionHeightM = r.connectionHeightM
          ..dropDn = r.dropDn
          ..plant = r.kind == SurveyNodeKind.compressor
              ? r.plant ?? carried
              : null;
      });
  }
  return true;
}

class _NodeDialog extends StatefulWidget {
  const _NodeDialog({required this.ctrl, required this.node, this.initialKind});
  final SurveyNodeKind? initialKind;
  final PipeSurveyController ctrl;
  final SurveyNode node;

  @override
  State<_NodeDialog> createState() => _NodeDialogState();
}

class _NodeDialogState extends State<_NodeDialog> {
  late SurveyNodeKind _kind = widget.initialKind ?? widget.node.kind;
  late int? _dropDn = widget.node.dropDn;
  late SurveyPlant? _plant = widget.node.plant;
  late final _name = TextEditingController(text: widget.node.name);
  late final _hang = TextEditingController(
    text: formatSurveyNumber(widget.node.hangHeightM),
  );
  late final _conn = TextEditingController(
    text: formatSurveyNumber(widget.node.connectionHeightM),
  );
  late final _note = TextEditingController(text: widget.node.note);

  @override
  void dispose() {
    for (final t in [_name, _hang, _conn, _note]) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.ctrl.survey;
    final c = widget.ctrl.constants;
    final usePoint = _kind == SurveyNodeKind.usePoint;
    final plantEngine = widget.ctrl.plantEngine;
    return AlertDialog(
      title: const Text('Điểm trên sơ đồ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<SurveyNodeKind>(
              key: const Key('survey_node_kind'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: SurveyNodeKind.junction,
                  label: Text('Điểm nối'),
                ),
                ButtonSegment(
                  value: SurveyNodeKind.usePoint,
                  label: Text('Điểm sử dụng'),
                ),
                ButtonSegment(
                  value: SurveyNodeKind.compressor,
                  label: Text('Cụm máy'),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('survey_node_name'),
              controller: _name,
              decoration: _decoration(
                'Tên',
                hint: usePoint ? 'Vd: Máy tách màu 1' : null,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('survey_node_hang'),
              controller: _hang,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _decoration(
                'Cao độ ống tại điểm',
                hint: s.hangHeightM == null
                    ? 'Trống = độ cao treo của công trình'
                    : 'Trống = ${formatSurveyNumber(s.hangHeightM)} m',
                suffix: 'm',
              ),
            ),
            if (usePoint) ...[
              const SizedBox(height: 10),
              TextField(
                key: const Key('survey_node_connection'),
                controller: _conn,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _decoration(
                  'Cao độ đầu nối ở máy',
                  hint:
                      'Trống = ${formatSurveyNumber(c.defaultConnectionHeightM)} m',
                  suffix: 'm',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                key: const Key('survey_node_drop_dn'),
                initialValue: _dropDn,
                decoration: _decoration('Cỡ ống đứng xuống máy'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Tự động (cỡ ống tại điểm)'),
                  ),
                  for (final size in c.sizes)
                    DropdownMenuItem(value: size, child: Text('DN$size')),
                ],
                onChanged: (v) => setState(() => _dropDn = v),
              ),
            ],
            if (_kind == SurveyNodeKind.compressor && plantEngine != null) ...[
              const SizedBox(height: 6),
              ListTile(
                key: const Key('survey_node_plant'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.square_foot_rounded),
                title: const Text('Kích thước thật (như phòng lắp đặt)'),
                subtitle: Text(surveyPlantSummary(_plant, plantEngine)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final r = await showSurveyPlantDialog(
                    context,
                    engine: plantEngine,
                    initial: _plant,
                  );
                  if (r != null) setState(() => _plant = r.plant);
                },
              ),
            ],
            const SizedBox(height: 10),
            TextField(controller: _note, decoration: _decoration('Ghi chú')),
          ],
        ),
      ),
      actions: _actions(
        context,
        deleteKey: 'survey_node_delete',
        deleteLabel: 'Xoá điểm',
        saveKey: 'survey_node_save',
        onSave: () => Navigator.pop(
          context,
          _SaveNode(
            kind: _kind,
            name: _name.text.trim(),
            note: _note.text.trim(),
            hangHeightM: parseSurveyNumber(_hang.text),
            connectionHeightM: usePoint ? parseSurveyNumber(_conn.text) : null,
            dropDn: usePoint ? _dropDn : null,
            plant: _kind == SurveyNodeKind.compressor ? _plant : null,
          ),
        ),
      ),
    );
  }
}

/// Tên loại hình nền.
String surveyShapeKindLabel(SurveyShapeKind k) => switch (k) {
  SurveyShapeKind.wall => 'Tường',
  SurveyShapeKind.column => 'Cột',
  SurveyShapeKind.obstacle => 'Chướng ngại vật',
  SurveyShapeKind.note => 'Ghi chú',
  SurveyShapeKind.leader => 'Chú thích mũi tên',
  SurveyShapeKind.area => 'Tên vùng / khu vực',
};

/// Loại hình nền chỉ là chữ: để trống chữ thì xoá.
bool _isText(SurveyShapeKind k) =>
    k == SurveyShapeKind.note ||
    k == SurveyShapeKind.leader ||
    k == SurveyShapeKind.area;

/// Hộp sửa khung tên bản vẽ: tên bản vẽ, công trình, khách hàng, người khảo
/// sát (cùng dữ liệu tab Thông tin).
Future<void> showSurveyTitleSheet(
  BuildContext context,
  PipeSurveyController ctrl,
) async {
  final result = await showDialog<List<String>>(
    context: context,
    builder: (_) => _TitleDialog(survey: ctrl.survey),
  );
  if (result == null) return;
  ctrl.edit(
    (s) => s
      ..drawingTitle = result[0]
      ..name = result[1]
      ..customer = result[2]
      ..surveyor = result[3],
    undoable: false,
  );
}

class _TitleDialog extends StatefulWidget {
  const _TitleDialog({required this.survey});
  final PipeSurvey survey;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late final _fields = [
    TextEditingController(text: widget.survey.drawingTitle),
    TextEditingController(text: widget.survey.name),
    TextEditingController(text: widget.survey.customer),
    TextEditingController(text: widget.survey.surveyor),
  ];

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Tên bản vẽ', 'Công trình', 'Khách hàng', 'Người khảo sát'];
    return AlertDialog(
      title: const Text('Khung tên bản vẽ'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (k, c) in _fields.indexed) ...[
              if (k > 0) const SizedBox(height: 10),
              TextField(
                key: Key('survey_title_$k'),
                controller: c,
                decoration: _decoration(
                  labels[k],
                  hint: k == 0 ? PipeSurvey.defaultDrawingTitle : null,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          key: const Key('survey_title_save'),
          onPressed: () =>
              Navigator.pop(context, [for (final c in _fields) c.text.trim()]),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

/// Hộp sửa hình nền: tên / chữ ghi chú, kích thước (tường: dày; cột: rộng ×
/// sâu); xoá. Ghi chú để trống chữ thì xoá luôn.
Future<void> showSurveyShapeSheet(
  BuildContext context,
  PipeSurveyController ctrl,
  String shapeId,
) async {
  final shape = ctrl.survey.shapes.where((h) => h.id == shapeId).firstOrNull;
  if (shape == null) return;
  final result = await showDialog<_ShapeResult>(
    context: context,
    builder: (_) => _ShapeDialog(shape: shape),
  );
  if (result == null) return;
  ctrl.edit((s) {
    final h = s.shapes.where((h) => h.id == shapeId).firstOrNull;
    if (h == null) return;
    if (result.delete || (_isText(h.kind) && result.label.isEmpty)) {
      s.shapes.remove(h);
      return;
    }
    h
      ..label = result.label
      ..sizeM = result.sizeM
      ..size2M = result.size2M;
  });
}

class _ShapeResult {
  const _ShapeResult({
    this.delete = false,
    this.label = '',
    this.sizeM,
    this.size2M,
  });
  final bool delete;
  final String label;
  final double? sizeM;
  final double? size2M;
}

class _ShapeDialog extends StatefulWidget {
  const _ShapeDialog({required this.shape});
  final SurveyShape shape;

  @override
  State<_ShapeDialog> createState() => _ShapeDialogState();
}

class _ShapeDialogState extends State<_ShapeDialog> {
  late final _label = TextEditingController(text: widget.shape.label);
  late final _size = TextEditingController(
    text: formatSurveyNumber(widget.shape.sizeM),
  );
  late final _size2 = TextEditingController(
    text: formatSurveyNumber(widget.shape.size2M),
  );

  @override
  void dispose() {
    for (final c in [_label, _size, _size2]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.shape.kind;
    const number = TextInputType.numberWithOptions(decimal: true);
    return AlertDialog(
      title: Text(surveyShapeKindLabel(kind)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('survey_shape_label'),
              controller: _label,
              autofocus: _isText(kind),
              maxLines: kind == SurveyShapeKind.area || !_isText(kind) ? 1 : 3,
              decoration: _decoration(
                switch (kind) {
                  SurveyShapeKind.note => 'Nội dung ghi chú',
                  SurveyShapeKind.leader => 'Nội dung chú thích',
                  SurveyShapeKind.area => 'Tên khu vực',
                  _ => 'Tên',
                },
                hint: switch (kind) {
                  SurveyShapeKind.obstacle => 'Vd: Bồn nước, Dầm, Ống gió',
                  SurveyShapeKind.column => 'Vd: C3',
                  SurveyShapeKind.leader => 'Vd: Lỗ xuyên tường Ø90',
                  SurveyShapeKind.area => 'Vd: Xưởng sấy, Kho thành phẩm',
                  _ => null,
                },
              ),
            ),
            if (kind == SurveyShapeKind.area) ...[
              const SizedBox(height: 10),
              TextField(
                key: const Key('survey_shape_size'),
                controller: _size,
                keyboardType: number,
                decoration: _decoration(
                  'Chiều cao chữ (theo tỉ lệ sơ đồ)',
                  hint: 'Trống = ${formatSurveyNumber(surveyAreaTextM)}',
                  suffix: 'm',
                ),
              ),
            ],
            if (kind == SurveyShapeKind.wall) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _size,
                keyboardType: number,
                decoration: _decoration(
                  'Độ dày tường',
                  hint: 'Trống = ${formatSurveyNumber(surveyWallThicknessM)}',
                  suffix: 'm',
                ),
              ),
            ],
            if (kind == SurveyShapeKind.column) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _size,
                      keyboardType: number,
                      decoration: _decoration(
                        'Rộng',
                        hint: formatSurveyNumber(surveyColumnSizeM),
                        suffix: 'm',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _size2,
                      keyboardType: number,
                      decoration: _decoration(
                        'Sâu',
                        hint: 'Bằng rộng',
                        suffix: 'm',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('survey_shape_delete'),
          onPressed: () =>
              Navigator.pop(context, const _ShapeResult(delete: true)),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
          child: const Text('Xoá'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          key: const Key('survey_shape_save'),
          onPressed: () {
            double? positive(String t) {
              final v = parseSurveyNumber(t);
              return v != null && v > 0 ? v : null;
            }

            Navigator.pop(
              context,
              _ShapeResult(
                label: _label.text.trim(),
                sizeM: positive(_size.text),
                size2M: positive(_size2.text),
              ),
            );
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
