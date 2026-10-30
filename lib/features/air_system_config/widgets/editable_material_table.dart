import 'package:flutter/material.dart';

import '../l10n/air_strings.dart';
import '../pipe/material_list.dart';
import '../pipe/pipe_strings.dart';

/// Giá trị nhập ở hộp sửa / thêm vật tư.
class MaterialDraft {
  const MaterialDraft({
    required this.code,
    required this.name,
    required this.spec,
    required this.unit,
    required this.qty,
  });
  final String code;
  final String name;
  final String spec;
  final String unit;
  final double qty;
}

/// Một vật tư trong danh mục để chọn nhanh khi thêm (tên, mã, ĐVT, quy cách
/// như dữ liệu PO / định mức).
class CatalogMaterial {
  const CatalogMaterial({
    required this.name,
    required this.unit,
    this.code,
    this.spec,
  });
  final String? code;
  final String name;
  final String unit;
  final String? spec;
}

/// Bảng vật tư sửa được: STT, vật tư, quy cách, ĐVT, SL. Mặc định khoá để
/// lướt không chạm nhầm; tick "Cho phép sửa" thì chạm một dòng để sửa / xoá,
/// hiện nút thêm vật tư (chọn từ [catalog] được) và khôi phục danh sách gốc.
class EditableMaterialTable extends StatefulWidget {
  const EditableMaterialTable({
    super.key,
    required this.strings,
    required this.rows,
    required this.tableKey,
    required this.edited,
    required this.onSave,
    required this.onDelete,
    required this.onReset,
    required this.onResetList,
    this.catalog = const [],
  });

  final AirStrings strings;
  final List<MaterialRow> rows;
  final String tableKey;

  /// Danh sách đã có phần sửa tay (hiện nút khôi phục).
  final bool edited;

  /// Lưu [MaterialDraft]; [row] `null` = thêm mới.
  final void Function(MaterialRow? row, MaterialDraft draft) onSave;
  final void Function(MaterialRow row) onDelete;

  /// Dòng tự tính về lại giá trị tự tính.
  final void Function(MaterialRow row) onReset;
  final VoidCallback onResetList;
  final List<CatalogMaterial> catalog;

  @override
  State<EditableMaterialTable> createState() => _EditableMaterialTableState();
}

class _EditableMaterialTableState extends State<EditableMaterialTable> {
  bool _editing = false;

  Future<void> _open(MaterialRow? row) async {
    final result = await showDialog<_MaterialAction>(
      context: context,
      builder: (_) => _MaterialDialog(
        strings: widget.strings,
        row: row,
        catalog: widget.catalog,
      ),
    );
    switch (result) {
      case null:
        return;
      case _MaterialSave(:final draft):
        widget.onSave(row, draft);
      case _MaterialDelete():
        widget.onDelete(row!);
      case _MaterialReset():
        widget.onReset(row!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final tableKey = widget.tableKey;
    final rows = widget.rows;
    final scheme = Theme.of(context).colorScheme;
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
                      cell(t, c, onTap: _editing ? () => _open(r) : null),
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
                onPressed: () => _open(null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(s.matAdd),
              ),
              if (widget.edited)
                TextButton.icon(
                  key: Key('${tableKey}_reset'),
                  onPressed: widget.onResetList,
                  icon: const Icon(Icons.restore_rounded, size: 18),
                  label: Text(s.matResetList),
                ),
            ],
          ),
      ],
    );
  }
}

sealed class _MaterialAction {
  const _MaterialAction();
}

class _MaterialSave extends _MaterialAction {
  const _MaterialSave(this.draft);
  final MaterialDraft draft;
}

class _MaterialDelete extends _MaterialAction {
  const _MaterialDelete();
}

class _MaterialReset extends _MaterialAction {
  const _MaterialReset();
}

class _MaterialDialog extends StatefulWidget {
  const _MaterialDialog({
    required this.strings,
    required this.catalog,
    this.row,
  });
  final AirStrings strings;
  final MaterialRow? row;
  final List<CatalogMaterial> catalog;

  @override
  State<_MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialDialogState extends State<_MaterialDialog> {
  late final _code = TextEditingController(text: widget.row?.code);
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
    for (final c in [_code, _name, _spec, _unit, _qty]) {
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
      _MaterialSave(
        MaterialDraft(
          code: _code.text.trim(),
          name: name,
          spec: _spec.text.trim(),
          unit: _unit.text.trim(),
          qty: qty!,
        ),
      ),
    );
  }

  /// Chọn vật tư trong danh mục: điền mã, tên, quy cách, ĐVT.
  Future<void> _pick() async {
    final picked = await showDialog<CatalogMaterial>(
      context: context,
      builder: (_) =>
          _CatalogPicker(strings: widget.strings, catalog: widget.catalog),
    );
    if (picked == null) return;
    setState(() {
      _code.text = picked.code ?? '';
      _name.text = picked.name;
      _spec.text = picked.spec ?? '';
      _unit.text = picked.unit;
    });
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.catalog.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton.icon(
                  key: const Key('material_pick'),
                  onPressed: _pick,
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: Text(s.matPick),
                ),
              ),
            field('code', _code, s.matCode),
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

/// Danh mục vật tư có ô tìm theo tên / mã.
class _CatalogPicker extends StatefulWidget {
  const _CatalogPicker({required this.strings, required this.catalog});
  final AirStrings strings;
  final List<CatalogMaterial> catalog;

  @override
  State<_CatalogPicker> createState() => _CatalogPickerState();
}

class _CatalogPickerState extends State<_CatalogPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final q = _query.trim().toLowerCase();
    final items = [
      for (final m in widget.catalog)
        if (q.isEmpty ||
            m.name.toLowerCase().contains(q) ||
            (m.code ?? '').toLowerCase().contains(q))
          m,
    ];
    return AlertDialog(
      title: Text(s.matPick),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          children: [
            TextField(
              key: const Key('material_pick_search'),
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: s.matPickSearch,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, k) {
                  final m = items[k];
                  return ListTile(
                    dense: true,
                    title: Text(m.name),
                    subtitle: Text(
                      [
                        if (m.code?.isNotEmpty ?? false) m.code!,
                        if (m.spec?.isNotEmpty ?? false) m.spec!,
                        m.unit,
                      ].join(' · '),
                    ),
                    onTap: () => Navigator.pop(context, m),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.matCancel),
        ),
      ],
    );
  }
}
