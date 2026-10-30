import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/product_data.dart';
import '../pipe/install_kit.dart';
import '../pipe/material_catalog.dart';
import '../pipe/material_list.dart';
import '../pipe/pipe_engine.dart';
import '../pipe/pipe_strings.dart';
import '../providers/air_config_editor_controller.dart';
import 'air_config_form.dart' show AirNumberField;
import 'editable_material_table.dart';

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

/// Bảng vật tư sửa được của một danh sách trong tab (xem
/// [EditableMaterialTable]); phần sửa tay lưu vào cấu hình.
class _EditableBom extends StatelessWidget {
  const _EditableBom({
    required this.ctrl,
    required this.list,
    required this.tableKey,
  });
  final AirConfigEditorController ctrl;
  final MaterialList list;
  final String tableKey;

  @override
  Widget build(BuildContext context) => EditableMaterialTable(
    strings: ctrl.strings,
    rows: ctrl.materialRows(list),
    tableKey: tableKey,
    edited: ctrl.config.pipe.edits[list.name] != null,
    catalog: buildMaterialCatalog(kits: ctrl.installKits, run: pipeRunKit),
    onSave: (row, d) => ctrl.edit(
      (c) => row == null
          ? c.addMaterial(
              list,
              code: d.code,
              name: d.name,
              spec: d.spec,
              unit: d.unit,
              qty: d.qty,
            )
          : c.saveMaterial(
              list,
              row,
              code: d.code,
              name: d.name,
              spec: d.spec,
              unit: d.unit,
              qty: d.qty,
            ),
    ),
    onDelete: (row) => ctrl.edit((c) => c.removeMaterial(list, row)),
    onReset: (row) => ctrl.edit((c) => c.resetMaterial(list, row)),
    onResetList: () => ctrl.edit((c) => c.resetMaterialList(list)),
  );
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
    return _Section(
      title: s.pipeInputTitle,
      icon: Icons.plumbing_rounded,
      children: [
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
    return _Section(
      title: s.pipeTableTitle,
      icon: Icons.list_alt_rounded,
      children: [
        _EditableBom(
          ctrl: ctrl,
          list: MaterialList.pipe,
          tableKey: 'pipe_bom_table',
        ),
      ],
    );
  }
}
