import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/input/localized_number.dart';
import '../l10n/air_strings.dart';
import '../models/air_config.dart';
import '../providers/air_config_editor_controller.dart';

/// Tab "Nhập liệu": mọi trường trên một form, đổi là tính lại ngay.
class AirConfigForm extends StatelessWidget {
  const AirConfigForm({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AirConfigEditorController>();
    final s = ctrl.strings;
    final c = ctrl.config;
    final constants = ctrl.engine.constants;
    final comp = c.compressor;

    final catalog = ctrl.engine.catalogModels(comp.type);
    final result = ctrl.result;

    return ListView(
      key: const PageStorageKey('air_config_form'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        _Section(
          title: s.sectionProject,
          icon: Icons.business_center_outlined,
          children: [
            _TextField(
              key: const ValueKey('project_name'),
              label: s.projectName,
              value: c.project.name,
              onChanged: (v) => ctrl.edit((c) => c.project.name = v),
            ),
          ],
        ),
        _Section(
          title: s.sectionCompressor,
          icon: Icons.air_rounded,
          children: [
            _Dropdown<CompressorType>(
              key: ValueKey('type_${s.lang}'),
              label: s.compressorTypeLabel,
              value: comp.type,
              items: {
                for (final v in CompressorType.values) v: s.compressorType(v),
              },
              onChanged: (v) => ctrl.edit((c) {
                c.compressor.type = v;
                // Model đã chọn không thuộc loại mới thì bỏ.
                if (!ctrl.engine
                    .catalogModels(v)
                    .any((m) => m.modelCode == c.compressor.modelCode)) {
                  c.compressor.modelCode = null;
                }
                // Lựa chọn thứ 2 đổi theo loại máy (Chọn model ↔ Nhập tay).
                final second = v.hasCatalog
                    ? CompressorSource.catalog
                    : CompressorSource.manual;
                if (c.compressor.source != CompressorSource.demand &&
                    c.compressor.source != second) {
                  c.compressor.source = CompressorSource.demand;
                }
              }),
            ),
            AirNumberField(
              key: const ValueKey('pressure'),
              label: s.workingPressure,
              suffix: 'bar',
              value: comp.pressure,
              onChanged: (v) => ctrl.edit((c) => c.compressor.pressure = v),
            ),
            const SizedBox(height: 4),
            Text(s.modelSource, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            // Loại có dữ liệu: Theo nhu cầu | Chọn model. Loại chưa có dữ liệu
            // (2-STAGE): Theo nhu cầu | Nhập tay.
            SegmentedButton<CompressorSource>(
              key: const ValueKey('compressor_source'),
              showSelectedIcon: false,
              emptySelectionAllowed: true,
              segments: [
                for (final v in [
                  CompressorSource.demand,
                  comp.type.hasCatalog
                      ? CompressorSource.catalog
                      : CompressorSource.manual,
                ])
                  ButtonSegment(value: v, label: Text(s.source(v))),
              ],
              selected: {
                if (comp.source == CompressorSource.demand ||
                    (comp.source == CompressorSource.catalog) ==
                        comp.type.hasCatalog)
                  comp.source,
              },
              onSelectionChanged: (v) {
                if (v.isNotEmpty) {
                  ctrl.edit((c) => c.compressor.source = v.first);
                }
              },
            ),
            const SizedBox(height: 12),
            if (comp.source == CompressorSource.demand) ...[
              AirNumberField(
                key: const ValueKey('customer_demand'),
                label: s.customerDemand,
                suffix: s.flowUnit,
                value: comp.demand,
                onChanged: (v) => ctrl.edit((c) => c.compressor.demand = v),
              ),
              _MarginField(
                key: const ValueKey('margin_percent'),
                label: s.marginLabel,
                value: comp.marginPercent,
                options: constants.marginOptions,
                onChanged: (v) =>
                    ctrl.edit((c) => c.compressor.marginPercent = v),
              ),
              if (!comp.type.hasCatalog) _Hint(s.noCatalogFor(comp.type)),
            ],
            if (comp.source == CompressorSource.catalog)
              catalog.isEmpty
                  ? _Hint(s.noCatalogFor(comp.type))
                  : _Dropdown<String>(
                      key: ValueKey(
                        'model_${comp.type.name}_${comp.modelCode}',
                      ),
                      label: s.modelLabel,
                      value: catalog.any((m) => m.modelCode == comp.modelCode)
                          ? comp.modelCode
                          : null,
                      items: {
                        for (final m in catalog)
                          m.modelCode:
                              '${m.modelCode} · ${s.n2(m.powerKW)} kW · ${s.flow(m.flowAt(8)!)} @8 bar',
                      },
                      onChanged: (v) =>
                          ctrl.edit((c) => c.compressor.modelCode = v),
                    ),
            if (comp.source == CompressorSource.manual) ...[
              _TextField(
                key: const ValueKey('manual_name'),
                label: s.manualModelName,
                value: comp.manualName,
                onChanged: (v) => ctrl.edit((c) => c.compressor.manualName = v),
              ),
              _Row(
                children: [
                  AirNumberField(
                    key: const ValueKey('manual_power'),
                    label: s.manualPower,
                    suffix: 'kW',
                    value: comp.manualPowerKw,
                    onChanged: (v) =>
                        ctrl.edit((c) => c.compressor.manualPowerKw = v),
                  ),
                  AirNumberField(
                    key: const ValueKey('manual_fad'),
                    label: s.manualFad,
                    suffix: s.flowUnit,
                    value: comp.manualFad,
                    onChanged: (v) =>
                        ctrl.edit((c) => c.compressor.manualFad = v),
                  ),
                ],
              ),
            ],
            // Chọn model / nhập tay: nhắc lại máy và lưu lượng đang dùng.
            if (comp.source != CompressorSource.demand && result.flowFromModel)
              _Hint(
                s.suggested(result, byDemand: false),
                icon: Icons.check_circle_outline,
              ),
            // Cấu hình cũ nhập tay ở loại có dữ liệu: cho quay lại chọn từ dữ liệu.
            if (comp.source == CompressorSource.manual && comp.type.hasCatalog)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('back_to_catalog'),
                  onPressed: () => ctrl.edit(
                    (c) => c.compressor.source = CompressorSource.demand,
                  ),
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: Text(s.backToCatalog),
                ),
              ),
          ],
        ),
        _Section(
          title: s.sectionTank,
          icon: Icons.propane_tank_outlined,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.tankEnabled),
              value: c.tank.enabled,
              onChanged: (v) => ctrl.edit((c) => c.tank.enabled = v),
            ),
            if (c.tank.enabled)
              AirNumberField(
                key: const ValueKey('tank_volume'),
                label: s.tankManual,
                suffix: 'm³',
                value: c.tank.manualVolumeM3,
                helper: ctrl.result.tank == null
                    ? s.tankManualHint
                    : '${s.tankManualHint} · ${s.tankCard(ctrl.result.tank)} ${ctrl.result.tank!.spec?.model ?? ''}',
                onChanged: (v) => ctrl.edit((c) => c.tank.manualVolumeM3 = v),
              ),
          ],
        ),
        _Section(
          title: s.sectionPretreat,
          icon: Icons.filter_alt_outlined,
          children: [
            CheckboxListTile(
              key: const ValueKey('standard_filters'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(s.standardFilters),
              subtitle: Text(s.standardFiltersHint),
              value: c.pretreat.standard,
              onChanged: (v) =>
                  ctrl.edit((c) => c.pretreat.standard = v ?? true),
            ),
            // Tiêu chuẩn: đủ 3 lọc (không tắt được); bỏ tick thì chọn từng lọc.
            for (final (label, value, set) in [
              (
                s.waterSeparator,
                c.pretreat.hasWaterSeparator,
                (AirConfig c, bool v) => c.pretreat.waterSeparator = v,
              ),
              (
                s.coarseFilter,
                c.pretreat.hasCoarse,
                (AirConfig c, bool v) => c.pretreat.coarseFilter = v,
              ),
              (
                s.fineFilter,
                c.pretreat.hasFine,
                (AirConfig c, bool v) => c.pretreat.fineFilter = v,
              ),
            ])
              SwitchListTile(
                contentPadding: const EdgeInsets.only(left: 16),
                dense: true,
                title: Text(label),
                value: value,
                onChanged: c.pretreat.standard
                    ? null
                    : (v) => ctrl.edit((c) => set(c, v)),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.autoDrain),
              value: c.pretreat.autoDrain,
              onChanged: (v) => ctrl.edit((c) => c.pretreat.autoDrain = v),
            ),
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                // Khóa lưu trạng thái riêng: không trùng vị trí cuộn của form.
                key: const PageStorageKey('air_config_advanced'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 4),
                initiallyExpanded:
                    c.pretreat.afterCooler != AfterCoolerType.none,
                title: Text(
                  s.advanced,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                children: [
                  // Không dùng / Có (cấu hình cũ giải nhiệt nước hiện "Có").
                  _Dropdown<AfterCoolerType>(
                    key: ValueKey('after_cooler_${s.lang}'),
                    label: s.afterCoolerLabel,
                    value: c.pretreat.afterCooler == AfterCoolerType.none
                        ? AfterCoolerType.none
                        : AfterCoolerType.air,
                    items: {
                      for (final v in [
                        AfterCoolerType.none,
                        AfterCoolerType.air,
                      ])
                        v: s.afterCooler(v),
                    },
                    onChanged: (v) =>
                        ctrl.edit((c) => c.pretreat.afterCooler = v),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Xử lý khí chung cho cả hệ thống (line chỉ còn tên).
        _Section(
          title: s.sectionTreatment,
          icon: Icons.water_drop_outlined,
          children: [
            _Row(
              children: [
                _Dropdown<LinePdp>(
                  key: ValueKey('treatment_pdp_${s.lang}'),
                  label: s.pdpLabel,
                  value: c.treatment.pdp,
                  items: {for (final v in LinePdp.values) v: s.linePdp(v)},
                  onChanged: (v) => ctrl.edit((c) => c.treatment.pdp = v),
                ),
                AirNumberField(
                  key: const ValueKey('use_pressure'),
                  label: s.usePressure,
                  suffix: 'bar',
                  value: c.treatment.usePressure,
                  onChanged: (v) =>
                      ctrl.edit((c) => c.treatment.usePressure = v),
                ),
              ],
            ),
            _Hint(s.dryerFor(c.treatment.pdp)),
            if (c.treatment.pdp.isDesiccant)
              _Dropdown<RegenType>(
                key: ValueKey('regen_${s.lang}'),
                label: s.regenLabel,
                value: c.regen,
                items: {
                  for (final v in RegenType.values)
                    v: s.regenOption(v, constants.purgeRates[v.name] ?? 0),
                },
                onChanged: (v) => ctrl.edit((c) => c.regen = v),
              ),
          ],
        ),
        _Section(
          title: '${s.sectionLines} (${c.lines.length})',
          icon: Icons.account_tree_outlined,
          children: [
            for (var i = 0; i < c.lines.length; i++)
              _LineCard(
                key: ValueKey(c.lines[i].id),
                index: i,
                line: c.lines[i],
                strings: s,
                canDelete: c.lines.length > 1,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: c.lines.length >= ctrl.maxLines
                    ? null
                    : ctrl.addLine,
                icon: const Icon(Icons.add),
                label: Text(s.addLine),
              ),
            ),
            if (c.lines.length >= ctrl.maxLines)
              _Hint(s.maxLines(ctrl.maxLines)),
          ],
        ),
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    super.key,
    required this.index,
    required this.line,
    required this.strings,
    required this.canDelete,
  });

  final int index;
  final AirLine line;
  final AirStrings strings;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<AirConfigEditorController>();
    final s = strings;
    final scheme = Theme.of(context).colorScheme;
    void edit(void Function(AirLine l) change) => ctrl.edit((c) {
      final target = c.lines.where((l) => l.id == line.id).firstOrNull;
      if (target != null) change(target);
    });
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TextField(
                  key: ValueKey('${line.id}_name'),
                  label: s.lineName,
                  value: line.name,
                  dense: true,
                  onChanged: (v) => edit((l) => l.name = v),
                ),
              ),
              IconButton(
                tooltip: s.deleteLine,
                onPressed: canDelete ? () => ctrl.removeLine(line.id) : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
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
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Hai ô cạnh nhau trên màn rộng, xếp dọc trên điện thoại hẹp.
class _Row extends StatelessWidget {
  const _Row({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(children: children);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {this.icon = Icons.info_outline});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final T? value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          for (final e in items.entries)
            DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _TextField extends StatefulWidget {
  const _TextField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool dense;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: widget.dense ? 0 : 12,
        top: widget.dense ? 8 : 0,
      ),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

/// Ô nhập số theo kiểu Việt Nam (7,5); trống/sai → `null`.
class AirNumberField extends StatefulWidget {
  const AirNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix,
    this.helper,
  });
  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;
  final String? suffix;
  final String? helper;

  @override
  State<AirNumberField> createState() => _AirNumberFieldState();
}

class _AirNumberFieldState extends State<AirNumberField> {
  late final _controller = TextEditingController(text: _format(widget.value));

  static String _format(double? v) {
    if (v == null) return '';
    final text = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return text.replaceAll('.', ',');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const [LocalizedDecimalTextInputFormatter()],
        decoration: InputDecoration(
          labelText: widget.label,
          suffixText: widget.suffix,
          helperText: widget.helper,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (text) => widget.onChanged(
          text.trim().isEmpty ? null : parseLocalizedDouble(text),
        ),
      ),
    );
  }
}

/// Ô "Lưu lượng máy lớn hơn so với nhu cầu thực tế" (%): nhập tự do hoặc chọn
/// nhanh các mức gợi ý.
class _MarginField extends StatefulWidget {
  const _MarginField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final double? value;
  final List<double> options;
  final ValueChanged<double?> onChanged;

  @override
  State<_MarginField> createState() => _MarginFieldState();
}

class _MarginFieldState extends State<_MarginField> {
  late final _controller = TextEditingController(text: _format(widget.value));

  static String _format(double? v) {
    if (v == null) return '';
    final text = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return text.replaceAll('.', ',');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(double v) {
    _controller.text = _format(v);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: const [LocalizedDecimalTextInputFormatter()],
            decoration: InputDecoration(
              labelText: widget.label,
              suffixText: '%',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (text) => widget.onChanged(
              text.trim().isEmpty ? null : parseLocalizedDouble(text),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final v in widget.options)
                ChoiceChip(
                  label: Text('${_format(v)}%'),
                  selected:
                      widget.value != null && (widget.value! - v).abs() < 1e-9,
                  onSelected: (_) => _pick(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
