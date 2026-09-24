import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_machine.dart';
import '../models/grinding_material.dart';
import '../models/grinding_series.dart';
import '../providers/grinding_machine_provider.dart';
import '../utils/grinding_filter.dart';
import '../widgets/grinding_machine_list_tile.dart';

/// Lọc nâng cao theo Nguyên liệu / Công suất / Độ mịn (mesh hoặc micron) —
/// yêu cầu mục 6. Danh sách nguyên liệu lấy từ database, không hard-code.
class GrindingMachineFilterScreen extends StatefulWidget {
  const GrindingMachineFilterScreen({super.key});

  @override
  State<GrindingMachineFilterScreen> createState() =>
      _GrindingMachineFilterScreenState();
}

class _GrindingMachineFilterScreenState
    extends State<GrindingMachineFilterScreen> {
  List<GrindingMaterial> _materials = const [];
  Map<String, GrindingSeries> _seriesByCode = const {};
  GrindingFilterCriteria _criteria = const GrindingFilterCriteria();
  Set<String>? _compatibleSeriesCodes;
  final _finenessController = TextEditingController();
  String _finenessUnit = 'mesh';
  bool _isLoadingMaterials = true;

  static const _finenessUnits = ['mm', 'mesh', 'µm'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<GrindingMachineProvider>();
      final materials = await provider.getAllMaterials();
      if (!mounted) return;
      setState(() {
        _materials = materials;
        _seriesByCode = {for (final s in provider.series) s.seriesCode: s};
        _isLoadingMaterials = false;
      });
    });
  }

  @override
  void dispose() {
    _finenessController.dispose();
    super.dispose();
  }

  Future<void> _selectMaterial(GrindingMaterial? material) async {
    if (material == null) {
      setState(() {
        _criteria = _criteria.copyWith(clearMaterialId: true);
        _compatibleSeriesCodes = null;
      });
      return;
    }
    final provider = context.read<GrindingMachineProvider>();
    final codes = await provider.getCompatibleSeriesCodes(material.materialId);
    if (!mounted) return;
    setState(() {
      _criteria = _criteria.copyWith(materialId: material.materialId);
      _compatibleSeriesCodes = codes;
    });
  }

  void _applyFineness(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    setState(() {
      _criteria = parsed == null
          ? _criteria.copyWith(clearFineness: true)
          : _criteria.copyWith(finenessUnit: _finenessUnit, finenessValue: parsed);
    });
  }

  void _clearAll() {
    setState(() {
      _criteria = const GrindingFilterCriteria();
      _compatibleSeriesCodes = null;
      _finenessController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: const Text('Bộ lọc máy nghiền'),
        actions: [
          if (!_criteria.isEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text('Xóa lọc'),
            ),
        ],
      ),
      body: Consumer<GrindingMachineProvider>(
        builder: (context, provider, _) {
          final hasMaterialFilterNoData =
              _criteria.materialId != null &&
              (_compatibleSeriesCodes == null || _compatibleSeriesCodes!.isEmpty);
          final results = _criteria.isEmpty
              ? const <GrindingMachine>[]
              : GrindingFilterEngine.apply(
                  provider.machines,
                  _criteria,
                  compatibleSeriesCodes: _compatibleSeriesCodes,
                );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _FilterSection(
                title: 'Nguyên liệu',
                child: _isLoadingMaterials
                    ? const Center(child: CircularProgressIndicator())
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _materials.map((material) {
                          final selected =
                              material.materialId == _criteria.materialId;
                          return ChoiceChip(
                            key: Key('grinding_filter_material_${material.materialId}'),
                            label: Text(material.nameVi),
                            selected: selected,
                            onSelected: (isSelected) =>
                                _selectMaterial(isSelected ? material : null),
                          );
                        }).toList(),
                      ),
              ),
              if (hasMaterialFilterNoData) ...[
                const SizedBox(height: 8),
                Text(
                  'Database chưa có dữ liệu tương thích đã xác minh cho nguyên liệu này.',
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              _FilterSection(
                title: 'Công suất',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: GrindingCapacityBucket.values.map((bucket) {
                    final selected = _criteria.capacityBucket == bucket;
                    return ChoiceChip(
                      key: Key('grinding_filter_capacity_${bucket.name}'),
                      label: Text(bucket.label),
                      selected: selected,
                      onSelected: (isSelected) => setState(() {
                        _criteria = isSelected
                            ? _criteria.copyWith(capacityBucket: bucket)
                            : _criteria.copyWith(clearCapacityBucket: true);
                      }),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
              _FilterSection(
                title: 'Độ mịn',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: _finenessUnits.map((unit) {
                        final selected = _finenessUnit == unit;
                        return ChoiceChip(
                          key: Key('grinding_filter_fineness_unit_$unit'),
                          label: Text(unit),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _finenessUnit = unit);
                            _applyFineness(_finenessController.text);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const Key('grinding_filter_fineness_field'),
                      controller: _finenessController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: _applyFineness,
                      decoration: InputDecoration(
                        labelText: 'Giá trị ($_finenessUnit)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    if (_finenessUnit != 'mm')
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Tự quy đổi tương đương mesh ↔ µm khi so khớp (theo bảng chuẩn).',
                          style: TextStyle(color: palette.muted, fontSize: 11.5),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_criteria.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Chọn ít nhất 1 điều kiện để lọc.',
                      style: TextStyle(color: palette.muted),
                    ),
                  ),
                )
              else ...[
                Text(
                  '${results.length} model phù hợp',
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (results.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Không có model nào khớp điều kiện lọc trong database.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.muted),
                      ),
                    ),
                  )
                else
                  for (final machine in results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GrindingMachineListTile(
                        machine: machine,
                        subtitle: _seriesByCode[machine.seriesCode]?.nameVi,
                        onTap: () => context.push(
                          '/grinding_machine/detail/${machine.machineId}',
                        ),
                      ),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: palette.navy,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
