import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../equipment_catalog_config.dart';
import '../models/equipment_catalog.dart';
import '../providers/equipment_catalog_provider.dart';
import '../widgets/equipment_machine_list_tile.dart';

/// So sánh tối đa 3 model trong cùng 1 catalog — cùng kiểu bảng so sánh máy
/// nghiền. Ô thiếu dữ liệu hiện "—", không tự điền.
class EquipmentCompareScreen extends StatefulWidget {
  const EquipmentCompareScreen({
    super.key,
    required this.config,
    this.initialMachineIds,
  });

  final EquipmentCatalogConfig config;
  final List<String>? initialMachineIds;

  @override
  State<EquipmentCompareScreen> createState() => _EquipmentCompareScreenState();
}

class _EquipmentCompareScreenState extends State<EquipmentCompareScreen> {
  static const _maxSlots = 3;
  final List<String?> _slots = List.filled(_maxSlots, null);

  @override
  void initState() {
    super.initState();
    final ids = widget.initialMachineIds ?? const [];
    for (var i = 0; i < ids.length && i < _maxSlots; i++) {
      _slots[i] = ids[i];
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<EquipmentCatalogProvider>().load(widget.config),
    );
  }

  Future<void> _pickForSlot(int index, LoadedEquipmentCatalog catalog) async {
    final excluded = _slots.whereType<String>().toSet();
    final picked = await showModalBottomSheet<EquipmentMachine>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickerSheet(
        config: widget.config,
        catalog: catalog,
        excludeMachineIds: excluded,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _slots[index] = picked.machineId);
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final palette = DtcPalette.of(context);
    final catalog = context.watch<EquipmentCatalogProvider>().catalog(config);
    final slotMachines = [
      for (final id in _slots) id == null ? null : catalog?.machineById(id),
    ];
    final selected = slotMachines.whereType<EquipmentMachine>().toList();

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: Text('So sánh ${config.productLabel}')),
      body: catalog == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Row(
                  children: [
                    for (var i = 0; i < _maxSlots; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _SlotCard(
                          key: Key('${config.id}_compare_slot_$i'),
                          machine: slotMachines[i],
                          onTap: () => _pickForSlot(i, catalog),
                          onClear: () => setState(() => _slots[i] = null),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                if (selected.length < 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Chọn ít nhất 2 model để so sánh.',
                        style: TextStyle(color: palette.muted),
                      ),
                    ),
                  )
                else
                  _CompareTable(machines: selected, catalog: catalog),
              ],
            ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    super.key,
    required this.machine,
    required this.onTap,
    required this.onClear,
  });

  final EquipmentMachine? machine;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: machine == null ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: machine == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: palette.cyan, size: 26),
                    const SizedBox(height: 4),
                    Text(
                      'Chọn model',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.muted, fontSize: 11.5),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      machine!.model,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: onClear,
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.machines, required this.catalog});

  final List<EquipmentMachine> machines;
  final LoadedEquipmentCatalog catalog;

  /// Gộp thông số theo khoá (cùng khoá = cùng hàng) theo thứ tự xuất hiện:
  /// kỹ thuật → bổ sung → lắp đặt. Nhãn lấy từ model đầu tiên có khoá đó.
  List<(String, List<String?>)> _rows() {
    final labels = <String, String>{};
    for (final group in EquipmentSpecGroup.values) {
      for (final machine in machines) {
        for (final spec in machine.specsOf(group)) {
          labels.putIfAbsent(spec.key, () => spec.label);
        }
      }
    }
    return [
      (
        'Dòng máy',
        [for (final m in machines) catalog.seriesOf(m.seriesCode)?.nameVi],
      ),
      for (final MapEntry(:key, value: label) in labels.entries)
        (label, [for (final m in machines) m.valueOf(key)]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: palette.canvas,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Expanded(flex: 3, child: SizedBox()),
                for (final machine in machines)
                  Expanded(
                    flex: 4,
                    child: Text(
                      machine.model,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final (label, values) in _rows())
            _CompareRow(label: label, values: values),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.label, required this.values});

  final String label;
  final List<String?> values;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final isDiff = values.whereType<String>().toSet().length > 1;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(color: palette.muted, fontSize: 11.5),
            ),
          ),
          for (final value in values)
            Expanded(
              flex: 4,
              child: Text(
                value ?? '—',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: value == null
                      ? palette.muted
                      : (isDiff ? palette.cyan : palette.ink),
                  fontWeight: isDiff && value != null
                      ? FontWeight.w800
                      : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.config,
    required this.catalog,
    required this.excludeMachineIds,
  });

  final EquipmentCatalogConfig config;
  final LoadedEquipmentCatalog catalog;
  final Set<String> excludeMachineIds;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final catalog = widget.catalog;
    final results = catalog
        .search(_controller.text)
        .where((m) => !widget.excludeMachineIds.contains(m.machineId))
        .toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  key: Key('${widget.config.id}_picker_search_field'),
                  controller: _controller,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Tìm model để so sánh...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          'Không tìm thấy model phù hợp.',
                          style: TextStyle(color: palette.muted),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final machine = results[index];
                          return EquipmentMachineListTile(
                            config: widget.config,
                            machine: machine,
                            imagePath: catalog.imageOf(machine),
                            subtitle: catalog
                                .seriesOf(machine.seriesCode)
                                ?.nameVi,
                            onTap: () => Navigator.of(context).pop(machine),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
