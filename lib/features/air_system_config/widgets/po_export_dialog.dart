import 'package:flutter/material.dart';

import '../l10n/air_strings.dart';
import '../pipe/pipe_strings.dart';
import '../services/air_po_excel.dart';
import '../services/po_requester_store.dart';

/// Lựa chọn khi xuất đề nghị vật tư.
typedef PoExportChoice = ({bool pdf, bool merged, PoRequester requester});

/// Hộp xuất đề nghị vật tư: thông tin người đề nghị (tự nhớ cho lần sau, trừ
/// số lần đề nghị), định dạng (Excel / PDF), kiểu (theo hạng mục / gộp mã).
/// Dùng chung cho Cấu hình hệ thống khí nén và Khảo sát vật tư ngoại tuyến.
class PoExportDialog extends StatefulWidget {
  const PoExportDialog({super.key, required this.strings});
  final AirStrings strings;

  @override
  State<PoExportDialog> createState() => _PoExportDialogState();
}

class _PoExportDialogState extends State<PoExportDialog> {
  bool _pdf = false;
  bool _merged = false;
  final _requester = TextEditingController();
  final _employeeId = TextEditingController();
  final _position = TextEditingController();
  final _department = TextEditingController();
  final _projectCode = TextEditingController(
    text: PoRequesterStore.defaultProjectCode,
  );
  final _requestNo = TextEditingController(
    text: PoRequesterStore.defaultRequestNo,
  );

  List<TextEditingController> get _all => [
    _requester,
    _employeeId,
    _position,
    _department,
    _projectCode,
    _requestNo,
  ];

  @override
  void initState() {
    super.initState();
    PoRequesterStore.load().then((saved) {
      if (!mounted) return;
      setState(() {
        _requester.text = saved.requester;
        _employeeId.text = saved.employeeId;
        _position.text = saved.position;
        _department.text = saved.department;
        _projectCode.text = saved.projectCode;
      });
    });
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _export() async {
    final info = PoRequester(
      requester: _requester.text.trim(),
      employeeId: _employeeId.text.trim(),
      position: _position.text.trim(),
      department: _department.text.trim(),
      projectCode: _projectCode.text.trim(),
      requestNo: _requestNo.text.trim(),
    );
    await PoRequesterStore.save(info);
    if (!mounted) return;
    Navigator.pop<PoExportChoice>(context, (
      pdf: _pdf,
      merged: _merged,
      requester: info,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final muted = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 12.5,
    );
    Widget field(String key, TextEditingController c, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: c,
        builder: (context, value, _) => TextField(
          key: Key('po_$key'),
          controller: c,
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
            // Xoá nhanh để nhập thông tin khác.
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: s.poClear,
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: c.clear,
                  ),
          ),
        ),
      ),
    );

    return AlertDialog(
      title: Text(s.poDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            field('requester', _requester, s.poRequester),
            field('employee_id', _employeeId, s.poEmployeeId),
            field('position', _position, s.poPosition),
            field('department', _department, s.poDepartment),
            field('project_code', _projectCode, s.poProjectCode),
            field('request_no', _requestNo, s.poRequestNo),
            Text(s.poRememberHint, style: muted),
            const SizedBox(height: 14),
            Text(s.poFormat),
            const SizedBox(height: 6),
            SegmentedButton<bool>(
              key: const Key('po_format'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Excel'),
                  icon: Icon(Icons.table_chart_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('PDF'),
                  icon: Icon(Icons.picture_as_pdf_outlined),
                ),
              ],
              selected: {_pdf},
              onSelectionChanged: (v) => setState(() => _pdf = v.first),
            ),
            const SizedBox(height: 14),
            Text(s.poStyle),
            const SizedBox(height: 6),
            SegmentedButton<bool>(
              key: const Key('po_style'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(s.poGrouped)),
                ButtonSegment(value: true, label: Text(s.poMerged)),
              ],
              selected: {_merged},
              onSelectionChanged: (v) => setState(() => _merged = v.first),
            ),
            const SizedBox(height: 6),
            Text(_merged ? s.poMergedHint : s.poGroupedHint, style: muted),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.matCancel),
        ),
        FilledButton(
          key: const Key('po_export'),
          onPressed: _export,
          child: Text(s.poExport),
        ),
      ],
    );
  }
}
