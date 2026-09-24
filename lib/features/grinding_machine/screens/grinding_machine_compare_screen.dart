import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_machine.dart';
import '../models/grinding_series.dart';
import '../providers/grinding_machine_provider.dart';
import '../utils/grinding_format.dart';
import '../widgets/grinding_machine_picker_sheet.dart';

/// So sánh tối đa 3 model — yêu cầu mục 9. Chỉ hiển thị dữ liệu có trong
/// database, ô thiếu dữ liệu hiển thị "—", KHÔNG tự điền.
class GrindingMachineCompareScreen extends StatefulWidget {
  const GrindingMachineCompareScreen({super.key});

  @override
  State<GrindingMachineCompareScreen> createState() =>
      _GrindingMachineCompareScreenState();
}

class _GrindingMachineCompareScreenState
    extends State<GrindingMachineCompareScreen> {
  static const _maxSlots = 3;
  final List<GrindingMachine?> _slots = List.filled(_maxSlots, null);
  final Map<String, GrindingSeries> _seriesByCode = {};

  Future<void> _pickForSlot(int index) async {
    final excluded = _slots
        .whereType<GrindingMachine>()
        .map((m) => m.machineId)
        .toSet();
    final picked = await showGrindingMachinePickerSheet(
      context,
      excludeMachineIds: excluded,
    );
    if (picked == null || !mounted) return;

    if (!_seriesByCode.containsKey(picked.seriesCode)) {
      final series = await context.read<GrindingMachineProvider>().getSeries(
        picked.seriesCode,
      );
      if (series != null) _seriesByCode[picked.seriesCode] = series;
    }
    if (!mounted) return;
    setState(() => _slots[index] = picked);
  }

  void _clearSlot(int index) {
    setState(() => _slots[index] = null);
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final selected = _slots.whereType<GrindingMachine>().toList();

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: const Text('So sánh model')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              for (var i = 0; i < _maxSlots; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _SlotCard(
                    machine: _slots[i],
                    onTap: () => _pickForSlot(i),
                    onClear: () => _clearSlot(i),
                    slotKey: Key('grinding_compare_slot_$i'),
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
            _CompareTable(machines: selected, seriesByCode: _seriesByCode),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.machine,
    required this.onTap,
    required this.onClear,
    required this.slotKey,
  });

  final GrindingMachine? machine;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final Key slotKey;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Material(
      key: slotKey,
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
  const _CompareTable({required this.machines, required this.seriesByCode});

  final List<GrindingMachine> machines;
  final Map<String, GrindingSeries> seriesByCode;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final rows = <(String, List<String?>)>[
      (
        'Dòng máy',
        machines
            .map((m) => seriesByCode[m.seriesCode]?.displayCode)
            .toList(),
      ),
      (
        'Công suất xử lý',
        machines.map(GrindingFormat.capacityRange).toList(),
      ),
      ('Kích thước đầu vào', machines.map(GrindingFormat.inputSize).toList()),
      (
        'Độ mịn đầu ra',
        machines.map(GrindingFormat.finenessRange).toList(),
      ),
      (
        'Công suất động cơ',
        machines.map(GrindingFormat.motorRange).toList(),
      ),
      (
        'Kích thước máy',
        machines.map((m) => m.dimensionsDisplay).toList(),
      ),
      (
        'Trọng lượng',
        machines
            .map((m) => m.weightKg == null ? null : '${_num(m.weightKg!)} kg')
            .toList(),
      ),
    ];

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
          for (final (label, values) in rows)
            _CompareRow(label: label, values: values),
        ],
      ),
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.label, required this.values});

  final String label;
  final List<String?> values;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final distinctValues = values.whereType<String>().toSet();
    final isDiff = distinctValues.length > 1;

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
