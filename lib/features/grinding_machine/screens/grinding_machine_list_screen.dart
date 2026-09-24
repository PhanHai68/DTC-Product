import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_machine.dart';
import '../models/grinding_material.dart';
import '../models/grinding_series.dart';
import '../providers/grinding_machine_provider.dart';
import '../utils/grinding_filter.dart';
import '../utils/grinding_format.dart';

/// Danh sách TOÀN BỘ model máy nghiền (không nhóm theo Series) — mục 2 Phase
/// 6. Search/filter chạy hoàn toàn trong RAM trên [GrindingMachineProvider]
/// đã cache sẵn — không query lại SQLite theo từng ký tự (mục 16). Chỉ dùng
/// các method public sẵn có của Provider để dựng chỉ mục tìm kiếm 1 lần khi
/// vào màn hình, không thêm method mới vào Repository/Provider.
class GrindingMachineListScreen extends StatefulWidget {
  const GrindingMachineListScreen({super.key});

  @override
  State<GrindingMachineListScreen> createState() =>
      _GrindingMachineListScreenState();
}

class _SearchEntry {
  const _SearchEntry({
    required this.machine,
    required this.series,
    required this.machineType,
    required this.materials,
    required this.haystack,
  });

  final GrindingMachine machine;
  final GrindingSeries? series;
  final String? machineType;
  final Set<String> materials;
  final String haystack;
}

class _GrindingMachineListScreenState extends State<GrindingMachineListScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _isIndexing = true;
  List<_SearchEntry> _entries = const [];
  Set<String> _seriesCodes = const {};
  GrindingFilterCriteria _criteria = const GrindingFilterCriteria();
  Set<String>? _compatibleSeriesCodes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _buildIndex());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Dựng chỉ mục tìm kiếm 1 LẦN khi vào màn hình — mọi lượt gõ sau đó chỉ
  /// lọc [_entries] trong RAM (mục 3, 16). Chỉ gọi các method public sẵn có
  /// của [GrindingMachineProvider], không đụng Repository trực tiếp.
  Future<void> _buildIndex() async {
    final provider = context.read<GrindingMachineProvider>();
    final seriesByCode = {for (final s in provider.series) s.seriesCode: s};
    final tagsBySeries = await provider.getAllSelectionTagsGrouped();

    final materialsBySeries = <String, Set<String>>{};
    for (final material in await provider.getAllMaterials()) {
      final codes = await provider.getCompatibleSeriesCodes(material.materialId);
      for (final code in codes) {
        (materialsBySeries[code] ??= {}).add(material.nameVi);
      }
    }

    final entries = <_SearchEntry>[];
    for (final machine in provider.machines) {
      final series = seriesByCode[machine.seriesCode];
      final tags = tagsBySeries[machine.seriesCode] ?? const {};
      final materials = materialsBySeries[machine.seriesCode] ?? const {};
      final extraSpecs = await provider.getExtraSpecs(machine.machineId);
      final parts = <String>[
        machine.model,
        machine.seriesCode,
        series?.nameVi ?? '',
        series?.nameEn ?? '',
        series?.displayCode ?? '',
        series?.technology ?? '',
        ...tags,
        ...tags.map(GrindingFormat.tagLabel),
        ...materials,
        for (final spec in extraSpecs) ...[spec.specKey, spec.displayValue],
      ];
      entries.add(
        _SearchEntry(
          machine: machine,
          series: series,
          machineType: (series?.technology.isEmpty ?? true)
              ? null
              : series!.technology,
          materials: materials,
          haystack: parts.join(' ').toLowerCase(),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _seriesCodes = seriesByCode.keys.toSet();
      _isIndexing = false;
    });
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => setState(() => _query = value.trim().toLowerCase()),
    );
  }

  Future<void> _openFilterSheet() async {
    final provider = context.read<GrindingMachineProvider>();
    final result = await showModalBottomSheet<GrindingFilterCriteria>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _FilterSheet(
        initial: _criteria,
        allSeries: provider.series,
        materialsFuture: provider.getAllMaterials(),
      ),
    );
    if (result == null || !mounted) return;
    Set<String>? compatible;
    if (result.materialId != null) {
      compatible = await provider.getCompatibleSeriesCodes(result.materialId!);
    }
    if (!mounted) return;
    setState(() {
      _criteria = result;
      _compatibleSeriesCodes = compatible;
    });
  }

  List<GrindingMachine> get _visibleMachines {
    Iterable<_SearchEntry> entries = _entries;
    if (_query.isNotEmpty) {
      entries = entries.where((e) => e.haystack.contains(_query));
    }
    var machines = entries.map((e) => e.machine).toList();
    if (!_criteria.isEmpty) {
      machines = GrindingFilterEngine.apply(
        machines,
        _criteria,
        compatibleSeriesCodes: _compatibleSeriesCodes,
      );
    }
    return machines;
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final machines = _isIndexing ? const <GrindingMachine>[] : _visibleMachines;
    final entryByMachineId = {for (final e in _entries) e.machine.machineId: e};

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: const Text('Danh sách máy nghiền'),
        actions: [
          IconButton(
            key: const Key('grinding_list_filter_button'),
            tooltip: 'Bộ lọc',
            onPressed: _isIndexing ? null : _openFilterSheet,
            icon: Badge(
              label: Text('${_criteria.activeCount}'),
              isLabelVisible: _criteria.activeCount > 0,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      body: _isIndexing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    key: const Key('grinding_list_search_field'),
                    controller: _controller,
                    onChanged: _onQueryChanged,
                    decoration: InputDecoration(
                      hintText:
                          'Tìm model, dòng máy, nguyên liệu, ứng dụng...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _controller.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _controller.clear();
                                _debounce?.cancel();
                                setState(() => _query = '');
                              },
                            ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (_criteria.activeCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Filter (${_criteria.activeCount})',
                          style: TextStyle(
                            color: palette.cyan,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          key: const Key('grinding_list_filter_reset'),
                          onPressed: () => setState(() {
                            _criteria = const GrindingFilterCriteria();
                            _compatibleSeriesCodes = null;
                          }),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        '${machines.length}/${_seriesCodes.isEmpty ? 0 : _entries.length} model',
                        style: TextStyle(color: palette.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: machines.isEmpty
                      ? Center(
                          child: Text(
                            'Không tìm thấy model phù hợp trong database.',
                            style: TextStyle(color: palette.muted),
                          ),
                        )
                      : ListView.separated(
                          key: const Key('grinding_list_results'),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          itemCount: machines.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final machine = machines[index];
                            final entry = entryByMachineId[machine.machineId];
                            return _MachineCard(
                              machine: machine,
                              series: entry?.series,
                              machineType: entry?.machineType,
                              materials: entry?.materials ?? const {},
                              onTap: () => context.push(
                                '/grinding_machine/detail/${machine.machineId}',
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _MachineCard extends StatelessWidget {
  const _MachineCard({
    required this.machine,
    required this.series,
    required this.machineType,
    required this.materials,
    required this.onTap,
  });

  final GrindingMachine machine;
  final GrindingSeries? series;
  final String? machineType;
  final Set<String> materials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final chips = [
      if (machineType != null) machineType,
      GrindingFormat.capacityRange(machine),
      GrindingFormat.finenessRange(machine),
      GrindingFormat.motorRange(machine),
      if (materials.isNotEmpty) materials.take(3).join(', '),
    ].whereType<String>().toList();

    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('grinding_list_card_${machine.machineId}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      machine.model,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (series != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${series!.displayCode} · ${series!.nameVi}',
                        style: TextStyle(color: palette.muted, fontSize: 12),
                      ),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: chips
                            .map(
                              (c) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.cyan.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    color: palette.navy,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: palette.cyan),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.allSeries,
    required this.materialsFuture,
  });

  final GrindingFilterCriteria initial;
  final List<GrindingSeries> allSeries;
  final Future<List<GrindingMaterial>> materialsFuture;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late GrindingFilterCriteria _draft = widget.initial;
  final _motorController = TextEditingController();
  final _finenessController = TextEditingController();
  String _finenessUnit = 'mesh';

  @override
  void initState() {
    super.initState();
    if (widget.initial.maxMotorKw != null) {
      _motorController.text = _fmt(widget.initial.maxMotorKw!);
    }
    if (widget.initial.finenessValue != null) {
      _finenessController.text = _fmt(widget.initial.finenessValue!);
      _finenessUnit = widget.initial.finenessUnit ?? 'mesh';
    }
  }

  @override
  void dispose() {
    _motorController.dispose();
    _finenessController.dispose();
    super.dispose();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: palette.canvas,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              children: [
                Text(
                  'Bộ lọc',
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton(
                  key: const Key('grinding_list_filter_sheet_reset'),
                  onPressed: () =>
                      setState(() => _draft = const GrindingFilterCriteria()),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Nguyên liệu',
              style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<GrindingMaterial>>(
              future: widget.materialsFuture,
              builder: (context, snapshot) {
                final materials = snapshot.data ?? const <GrindingMaterial>[];
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: materials.map((material) {
                    final selected = _draft.materialId == material.materialId;
                    return ChoiceChip(
                      key: Key(
                        'grinding_list_filter_material_${material.materialId}',
                      ),
                      label: Text(material.nameVi),
                      selected: selected,
                      onSelected: (isSelected) => setState(() {
                        _draft = isSelected
                            ? _draft.copyWith(materialId: material.materialId)
                            : _draft.copyWith(clearMaterialId: true);
                      }),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              'Dòng máy (Series)',
              style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.allSeries.map((series) {
                final selected = _draft.seriesCodes.contains(series.seriesCode);
                return ChoiceChip(
                  key: Key('grinding_list_filter_series_${series.seriesCode}'),
                  label: Text(series.displayCode),
                  selected: selected,
                  onSelected: (isSelected) => setState(() {
                    final next = {..._draft.seriesCodes};
                    if (isSelected) {
                      next.add(series.seriesCode);
                    } else {
                      next.remove(series.seriesCode);
                    }
                    _draft = _draft.copyWith(seriesCodes: next);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Text(
              'Công suất',
              style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GrindingCapacityBucket.values.map((bucket) {
                final selected = _draft.capacityBucket == bucket;
                return ChoiceChip(
                  key: Key('grinding_list_filter_capacity_${bucket.name}'),
                  label: Text(bucket.label),
                  selected: selected,
                  onSelected: (isSelected) => setState(() {
                    _draft = isSelected
                        ? _draft.copyWith(capacityBucket: bucket)
                        : _draft.copyWith(clearCapacityBucket: true);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Text(
              'Độ mịn',
              style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['mm', 'mesh', 'µm'].map((unit) {
                final selected = _finenessUnit == unit;
                return ChoiceChip(
                  key: Key('grinding_list_filter_fineness_unit_$unit'),
                  label: Text(unit),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _finenessUnit = unit;
                    _applyFineness(_finenessController.text);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('grinding_list_filter_fineness_field'),
              controller: _finenessController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: _applyFineness,
              decoration: InputDecoration(
                labelText: 'Giá trị ($_finenessUnit)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Công suất động cơ tối đa (kW)',
              style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('grinding_list_filter_motor_field'),
              controller: _motorController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                final parsed = double.tryParse(value.replaceAll(',', '.'));
                setState(() {
                  _draft = parsed == null
                      ? _draft.copyWith(clearMaxMotorKw: true)
                      : _draft.copyWith(maxMotorKw: parsed);
                });
              },
              decoration: const InputDecoration(
                labelText: '≤ kW',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('grinding_list_filter_apply'),
              onPressed: () => Navigator.of(context).pop(_draft),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _applyFineness(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    setState(() {
      _draft = parsed == null
          ? _draft.copyWith(clearFineness: true)
          : _draft.copyWith(finenessUnit: _finenessUnit, finenessValue: parsed);
    });
  }
}
