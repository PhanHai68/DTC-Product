import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/air_strings.dart';
import '../pipe/install_kit.dart';
import '../pipe/material_list.dart';
import '../pipe/pipe_engine.dart';
import '../pipe/pipe_strings.dart';
import '../providers/air_config_editor_controller.dart';
import 'air_config_form.dart' show AirNumberField;

/// Tab "Vật tư lắp đặt": vật tư lắp đặt cụm máy theo công suất máy nén (kèm
/// van xả đáy bình, vật tư điện khi tick chọn); vật tư từ cụm máy đến thiết
/// bị sử dụng khí nén — nhập tổng chiều dài, số lần bẻ góc, hao hụt (và ống
/// nhánh khi có từ 2 máy nén); bảng vật tư theo từng DN. Mọi danh sách sửa
/// tay được (thêm / xoá / sửa).
class AirPipeView extends StatelessWidget {
  const AirPipeView({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AirConfigEditorController>();
    final r = ctrl.pipe;
    if (r == null) return const SizedBox.shrink();
    return ListView(
      key: const PageStorageKey('air_pipe_view'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        if (ctrl.installKits != null) _KitCard(ctrl: ctrl),
        _PipeInput(ctrl: ctrl, result: r),
        if (r.warnings.isNotEmpty) _PipeWarnings(ctrl: ctrl, result: r),
        _PipeTable(ctrl: ctrl, result: r),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Bảng vật tư sửa được: STT, vật tư, quy cách, ĐVT, SL. Mặc định khoá để
/// lướt không chạm nhầm; tick "Cho phép sửa" thì chạm một dòng để sửa / xoá,
/// hiện nút thêm vật tư và khôi phục danh sách gốc.
class _EditableBom extends StatefulWidget {
  const _EditableBom({
    required this.ctrl,
    required this.list,
    required this.tableKey,
  });
  final AirConfigEditorController ctrl;
  final MaterialList list;
  final String tableKey;

  @override
  State<_EditableBom> createState() => _EditableBomState();
}

class _EditableBomState extends State<_EditableBom> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final list = widget.list;
    final tableKey = widget.tableKey;
    final s = ctrl.strings;
    final scheme = Theme.of(context).colorScheme;
    final rows = ctrl.materialRows(list);
    final edited = ctrl.config.pipe.edits[list.name] != null;
    const bold = TextStyle(fontWeight: FontWeight.bold);
    Widget cell(
      String text,
      int k, {
      bool header = false,
      VoidCallback? onTap,
    }) {
      final child = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(
          text,
          textAlign: k == 0 || k >= 3 ? TextAlign.center : TextAlign.start,
          style: header || k == 4 ? bold : null,
        ),
      );
      return onTap == null
          ? child
          : TableRowInkWell(onTap: onTap, child: child);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: FilterChip(
              key: Key('${tableKey}_edit'),
              avatar: _editing
                  ? null
                  : const Icon(Icons.edit_outlined, size: 18),
              label: Text(s.matEditMode),
              selected: _editing,
              onSelected: (v) => setState(() => _editing = v),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        if (rows.isEmpty)
          Text(s.matEmpty, style: TextStyle(color: scheme.onSurfaceVariant))
        else
          Table(
            key: Key(tableKey),
            border: TableBorder.all(color: scheme.outlineVariant),
            columnWidths: const {
              0: FixedColumnWidth(44),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(2),
              3: FixedColumnWidth(48),
              4: FixedColumnWidth(44),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: BoxDecoration(color: scheme.secondaryContainer),
                children: [
                  for (final (k, t) in [
                    s.pipeColNo,
                    s.pipeColName,
                    s.pipeColSpec,
                    s.pipeColUnit,
                    s.pipeColQty,
                  ].indexed)
                    cell(t, k, header: true),
                ],
              ),
              for (final (k, r) in rows.indexed)
                TableRow(
                  key: ValueKey('${tableKey}_${r.key}'),
                  // Dòng sửa / thêm tay tô vàng nhạt.
                  decoration: r.isEdited || r.isExtra
                      ? const BoxDecoration(color: Color(0xFFFFF7D6))
                      : null,
                  children: [
                    for (final (c, t) in [
                      '${k + 1}',
                      r.name,
                      (r.spec?.isNotEmpty ?? false) ? r.spec! : r.note ?? '—',
                      r.unit,
                      s.kitQty(r.qty),
                    ].indexed)
                      cell(
                        t,
                        c,
                        onTap: _editing
                            ? () => _editMaterial(context, ctrl, list, r)
                            : null,
                      ),
                  ],
                ),
            ],
          ),
        if (_editing)
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                key: Key('${tableKey}_add'),
                onPressed: () => _editMaterial(context, ctrl, list, null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(s.matAdd),
              ),
              if (edited)
                TextButton.icon(
                  key: Key('${tableKey}_reset'),
                  onPressed: () => ctrl.edit((c) => c.resetMaterialList(list)),
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: Text(s.matResetList),
                ),
            ],
          ),
      ],
    );
  }
}

/// Mở hộp sửa [row] (hoặc thêm mới khi `null`) rồi ghi vào cấu hình.
Future<void> _editMaterial(
  BuildContext context,
  AirConfigEditorController ctrl,
  MaterialList list,
  MaterialRow? row,
) async {
  final result = await showDialog<_MaterialAction>(
    context: context,
    builder: (_) => _MaterialDialog(strings: ctrl.strings, row: row),
  );
  switch (result) {
    case null:
      return;
    case _MaterialSave(:final name, :final spec, :final unit, :final qty):
      ctrl.edit(
        (c) => row == null
            ? c.addMaterial(list, name: name, spec: spec, unit: unit, qty: qty)
            : c.saveMaterial(
                list,
                row,
                name: name,
                spec: spec,
                unit: unit,
                qty: qty,
              ),
      );
    case _MaterialDelete():
      ctrl.edit((c) => c.removeMaterial(list, row!));
    case _MaterialReset():
      ctrl.edit((c) => c.resetMaterial(list, row!));
  }
}

sealed class _MaterialAction {
  const _MaterialAction();
}

class _MaterialSave extends _MaterialAction {
  const _MaterialSave(this.name, this.spec, this.unit, this.qty);
  final String name;
  final String spec;
  final String unit;
  final double qty;
}

class _MaterialDelete extends _MaterialAction {
  const _MaterialDelete();
}

class _MaterialReset extends _MaterialAction {
  const _MaterialReset();
}

class _MaterialDialog extends StatefulWidget {
  const _MaterialDialog({required this.strings, this.row});
  final AirStrings strings;
  final MaterialRow? row;

  @override
  State<_MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialDialogState extends State<_MaterialDialog> {
  late final _name = TextEditingController(text: widget.row?.name);
  late final _spec = TextEditingController(text: widget.row?.spec);
  late final _unit = TextEditingController(text: widget.row?.unit);
  late final _qty = TextEditingController(
    text: widget.row == null ? '1' : widget.strings.kitQty(widget.row!.qty),
  );
  String? _nameError;
  String? _qtyError;

  @override
  void dispose() {
    for (final c in [_name, _spec, _unit, _qty]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final s = widget.strings;
    final name = _name.text.trim();
    // Nhận cả "1,5" và "1.5".
    final qty = double.tryParse(_qty.text.trim().replaceAll(',', '.'));
    setState(() {
      _nameError = name.isEmpty ? s.matNameRequired : null;
      _qtyError = qty == null || qty <= 0 ? s.matQtyInvalid : null;
    });
    if (_nameError != null || _qtyError != null) return;
    Navigator.pop(
      context,
      _MaterialSave(name, _spec.text.trim(), _unit.text.trim(), qty!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final row = widget.row;
    Widget field(
      String key,
      TextEditingController c,
      String label, {
      String? error,
      TextInputType? type,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: Key('material_$key'),
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );

    return AlertDialog(
      title: Text(row == null ? s.matAdd : s.matEdit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            field('name', _name, s.pipeColName, error: _nameError),
            field('spec', _spec, s.pipeColSpec),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: field('unit', _unit, s.pipeColUnit)),
                const SizedBox(width: 8),
                Expanded(
                  child: field(
                    'qty',
                    _qty,
                    s.matQty,
                    error: _qtyError,
                    type: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (row != null)
          TextButton(
            key: const Key('material_delete'),
            onPressed: () => Navigator.pop(context, const _MaterialDelete()),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: Text(s.matDelete),
          ),
        if (row != null && row.isEdited)
          TextButton(
            key: const Key('material_reset'),
            onPressed: () => Navigator.pop(context, const _MaterialReset()),
            child: Text(s.matReset),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.matCancel),
        ),
        FilledButton(
          key: const Key('material_save'),
          onPressed: _save,
          child: Text(s.matSave),
        ),
      ],
    );
  }
}

/// Vật tư lắp đặt cụm máy theo công suất máy nén; tick để thêm van xả tự
/// động đáy bình tích khí và vật tư điện tạm tính.
class _KitCard extends StatelessWidget {
  const _KitCard({required this.ctrl});
  final AirConfigEditorController ctrl;

  @override
  Widget build(BuildContext context) {
    final s = ctrl.strings;
    final scheme = Theme.of(context).colorScheme;
    final kit = ctrl.installKit;
    final pick = ctrl.result.compressor;
    final p = ctrl.config.pipe;
    Widget note(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
      ),
    );
    Widget option(
      String key,
      String title,
      bool value,
      void Function(bool) set,
      InstallKitSection section,
      MaterialList list,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          key: Key(key),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(title),
          value: value,
          onChanged: (v) => ctrl.edit((_) => set(v ?? false)),
        ),
        if (value) ...[
          if (section.note != null) note(section.note!),
          _EditableBom(ctrl: ctrl, list: list, tableKey: '${key}_table'),
          const SizedBox(height: 8),
        ],
      ],
    );

    return _Section(
      title: s.kitTitle,
      icon: Icons.inventory_2_outlined,
      children: [
        note(s.matEditHint),
        if (kit == null) ...[
          Container(
            key: const Key('kit_not_updated'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${s.kitNotUpdated}. ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: s.kitNotUpdatedDetail(pick?.powerKw, [
                      for (final k in ctrl.installKits!.kits) k.hp,
                    ]),
                  ),
                ],
              ),
              style: const TextStyle(color: Color(0xFF1E293B)),
            ),
          ),
          // Công suất chưa có dữ liệu: vẫn nhập tay được.
          const SizedBox(height: 8),
          _EditableBom(
            ctrl: ctrl,
            list: MaterialList.kit,
            tableKey: 'kit_table',
          ),
        ] else ...[
          note(s.kitFor(kit, pick?.model?.modelCode ?? pick?.manualName)),
          if (ctrl.result.compressorQty > 1)
            note(s.kitUnitsNote(ctrl.result.compressorQty)),
          _EditableBom(
            ctrl: ctrl,
            list: MaterialList.kit,
            tableKey: 'kit_table',
          ),
          const SizedBox(height: 4),
          option(
            'kit_drain',
            s.kitDrain,
            p.drainKit,
            (v) => p.drainKit = v,
            kit.drain,
            MaterialList.drain,
          ),
          option(
            'kit_electric',
            s.kitElectric,
            p.electricKit,
            (v) => p.electricKit = v,
            kit.electric,
            MaterialList.electric,
          ),
        ],
      ],
    );
  }
}

class _PipeInput extends StatelessWidget {
  const _PipeInput({required this.ctrl, required this.result});
  final AirConfigEditorController ctrl;
  final PipeResult result;

  @override
  Widget build(BuildContext context) {
    final s = ctrl.strings;
    final p = ctrl.config.pipe;
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      title: s.pipeInputTitle,
      icon: Icons.plumbing_rounded,
      children: [
        Text(
          s.pipeInputHint(result),
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        AirNumberField(
          key: ValueKey('pipe_length_${ctrl.lang.name}'),
          label: s.pipeLength,
          value: p.totalLengthM,
          onChanged: (v) => ctrl.edit((_) => p.totalLengthM = v),
        ),
      ],
    );
  }
}

class _PipeWarnings extends StatelessWidget {
  const _PipeWarnings({required this.ctrl, required this.result});
  final AirConfigEditorController ctrl;
  final PipeResult result;

  @override
  Widget build(BuildContext context) {
    final s = ctrl.strings;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final w in result.warnings)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: w.code == PipeWarningCode.missingLength
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      w.code == PipeWarningCode.missingLength
                          ? Icons.info_outline
                          : Icons.warning_amber_rounded,
                      size: 18,
                      color: w.code == PipeWarningCode.missingLength
                          ? const Color(0xFF475569)
                          : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.pipeWarning(w),
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

class _PipeTable extends StatelessWidget {
  const _PipeTable({required this.ctrl, required this.result});
  final AirConfigEditorController ctrl;
  final PipeResult result;

  @override
  Widget build(BuildContext context) {
    final s = ctrl.strings;
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      title: s.pipeTableTitle,
      icon: Icons.list_alt_rounded,
      children: [
        _EditableBom(
          ctrl: ctrl,
          list: MaterialList.pipe,
          tableKey: 'pipe_bom_table',
        ),
        if (result.items.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            s.pipeNote(result),
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
        ],
      ],
    );
  }
}
