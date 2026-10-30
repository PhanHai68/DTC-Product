import 'package:flutter/material.dart';

import '../engine/survey_bom.dart';
import '../engine/survey_geometry.dart';
import '../models/pipe_survey.dart';
import '../providers/pipe_survey_controller.dart';

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
  const _SaveSegment(this.measuredM, this.dn, this.note);
  final double? measuredM;
  final int? dn;
  final String note;
}

class _SaveNode extends _Result {
  const _SaveNode({
    required this.kind,
    required this.name,
    required this.hangHeightM,
    required this.connectionHeightM,
    required this.dropDn,
    required this.note,
  });
  final SurveyNodeKind kind;
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
    case _SaveSegment(:final measuredM, :final dn, :final note):
      ctrl.edit((s) {
        s.segments.firstWhere((g) => g.id == segmentId)
          ..measuredM = measuredM
          ..dn = dn
          ..note = note;
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

  @override
  void dispose() {
    _measured.dispose();
    _note.dispose();
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
          Navigator.pop(
            context,
            _SaveSegment(
              len != null && len > 0 ? len : null,
              _dn,
              _note.text.trim(),
            ),
          );
        },
      ),
    );
  }
}

/// Hộp sửa điểm: loại điểm, tên; điểm sử dụng có độ cao treo riêng, cao độ
/// đầu nối, cỡ ống đứng; xoá điểm.
Future<void> showSurveyNodeSheet(
  BuildContext context,
  PipeSurveyController ctrl,
  String nodeId,
) async {
  final node = ctrl.survey.node(nodeId);
  if (node == null) return;
  final result = await showDialog<_Result>(
    context: context,
    builder: (_) => _NodeDialog(ctrl: ctrl, node: node),
  );
  switch (result) {
    case null:
      return;
    case _Delete():
      ctrl.edit((s) => surveyDeleteNode(s, nodeId));
    case final _SaveNode r:
      ctrl.edit((s) {
        // Chỉ một cụm máy.
        if (r.kind == SurveyNodeKind.compressor) {
          for (final other in s.nodes) {
            if (other.id != nodeId && other.kind == SurveyNodeKind.compressor) {
              other.kind = SurveyNodeKind.junction;
            }
          }
        }
        s.node(nodeId)!
          ..kind = r.kind
          ..name = r.name
          ..note = r.note
          ..hangHeightM = r.hangHeightM
          ..connectionHeightM = r.connectionHeightM
          ..dropDn = r.dropDn;
      });
    case _SaveSegment():
      return;
  }
}

class _NodeDialog extends StatefulWidget {
  const _NodeDialog({required this.ctrl, required this.node});
  final PipeSurveyController ctrl;
  final SurveyNode node;

  @override
  State<_NodeDialog> createState() => _NodeDialogState();
}

class _NodeDialogState extends State<_NodeDialog> {
  late SurveyNodeKind _kind = widget.node.kind;
  late int? _dropDn = widget.node.dropDn;
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
                  label: Text('Điểm dùng'),
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
            if (usePoint) ...[
              const SizedBox(height: 10),
              TextField(
                key: const Key('survey_node_hang'),
                controller: _hang,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _decoration(
                  'Độ cao treo ống tại điểm',
                  hint: s.hangHeightM == null
                      ? 'Trống = theo công trình'
                      : 'Trống = ${formatSurveyNumber(s.hangHeightM)} m',
                  suffix: 'm',
                ),
              ),
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
            hangHeightM: usePoint ? parseSurveyNumber(_hang.text) : null,
            connectionHeightM: usePoint ? parseSurveyNumber(_conn.text) : null,
            dropDn: usePoint ? _dropDn : null,
          ),
        ),
      ),
    );
  }
}
