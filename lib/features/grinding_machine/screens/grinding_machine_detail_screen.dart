import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_extra_spec.dart';
import '../models/grinding_machine.dart';
import '../models/grinding_series.dart';
import '../providers/grinding_machine_provider.dart';
import '../utils/grinding_format.dart';

/// Trang thông số kỹ thuật đầy đủ của 1 model — [machineId] truyền qua path
/// param `/grinding_machine/detail/:machineId`. CHỈ hiển thị field có dữ
/// liệu trong database, không hiển thị placeholder rỗng (yêu cầu mục 5).
class GrindingMachineDetailScreen extends StatefulWidget {
  const GrindingMachineDetailScreen({super.key, required this.machineId});

  final String machineId;

  @override
  State<GrindingMachineDetailScreen> createState() =>
      _GrindingMachineDetailScreenState();
}

class _GrindingMachineDetailScreenState
    extends State<GrindingMachineDetailScreen> {
  GrindingMachine? _machine;
  GrindingSeries? _series;
  List<GrindingExtraSpec> _extraSpecs = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<GrindingMachineProvider>();
    try {
      final machine = await provider.getMachine(widget.machineId);
      if (machine == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Không tìm thấy model này trong database.';
          _isLoading = false;
        });
        return;
      }
      final series = await provider.getSeries(machine.seriesCode);
      final extraSpecs = await provider.getExtraSpecs(machine.machineId);
      if (!mounted) return;
      setState(() {
        _machine = machine;
        _series = series;
        _extraSpecs = extraSpecs;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải thông số: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: Text(_machine?.model ?? 'Chi tiết model')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.muted),
                ),
              ),
            )
          : _DetailBody(
              machine: _machine!,
              series: _series,
              extraSpecs: _extraSpecs,
            ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.machine,
    required this.series,
    required this.extraSpecs,
  });

  final GrindingMachine machine;
  final GrindingSeries? series;
  final List<GrindingExtraSpec> extraSpecs;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);

    final specRows = <(String, String)>[
      if (series != null) ('Dòng máy', '${series!.displayCode} · ${series!.nameVi}'),
      if (GrindingFormat.capacityRange(machine) != null)
        ('Công suất xử lý', GrindingFormat.capacityRange(machine)!),
      if (GrindingFormat.inputSize(machine) != null)
        ('Kích thước đầu vào', GrindingFormat.inputSize(machine)!),
      if (GrindingFormat.finenessRange(machine) != null)
        ('Độ mịn đầu ra', GrindingFormat.finenessRange(machine)!),
      if (GrindingFormat.motorRange(machine) != null)
        ('Công suất động cơ chính', GrindingFormat.motorRange(machine)!),
      if (machine.speedRpmMin != null || machine.speedRpmMax != null)
        ('Tốc độ', _rpmDisplay(machine)),
      if (machine.dimensionsDisplay != null)
        ('Kích thước máy', machine.dimensionsDisplay!),
      if (machine.weightKg != null) ('Trọng lượng', '${_num(machine.weightKg!)} kg'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          machine.model,
          style: TextStyle(
            color: palette.ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (series != null) ...[
          const SizedBox(height: 4),
          Text(
            series!.nameVi,
            style: TextStyle(color: palette.muted, fontSize: 14),
          ),
        ],
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Thông số kỹ thuật',
          child: Column(
            children: [
              for (final (label, value) in specRows)
                _SpecRow(label: label, value: value),
            ],
          ),
        ),
        if (extraSpecs.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Thông số bổ sung',
            child: Column(
              children: [
                for (final spec in extraSpecs)
                  _SpecRow(
                    label: _humanizeSpecKey(spec.specKey),
                    value: spec.displayValue.isEmpty ? '—' : spec.displayValue,
                  ),
              ],
            ),
          ),
        ],
        if (series != null && series!.applicationVi.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(title: 'Ứng dụng', child: _Paragraph(series!.applicationVi)),
        ],
        if (series != null && series!.workingPrincipleVi.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Nguyên lý hoạt động',
            child: _Paragraph(series!.workingPrincipleVi),
          ),
        ],
        if (series != null && series!.notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(title: 'Ghi chú', child: _Paragraph(series!.notes)),
        ],
        const SizedBox(height: 16),
        Text(
          'Nguồn: ${machine.sourceDocument ?? 'Catalog DTC'}'
          '${machine.pdfPage != null ? ' · trang ${machine.pdfPage}' : ''}',
          style: TextStyle(color: palette.muted, fontSize: 11.5),
        ),
      ],
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static String _rpmDisplay(GrindingMachine machine) {
    final min = machine.speedRpmMin;
    final max = machine.speedRpmMax;
    if (min != null && max != null && min != max) {
      return '${_num(min)} - ${_num(max)} vòng/phút';
    }
    return '${_num((min ?? max)!)} vòng/phút';
  }

  static String _humanizeSpecKey(String key) {
    final withSpaces = key.replaceAll('_', ' ');
    if (withSpaces.isEmpty) return withSpaces;
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Container(
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
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Text(
              label,
              style: TextStyle(color: palette.muted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: palette.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Text(
      text,
      style: TextStyle(color: palette.ink, fontSize: 13, height: 1.45),
    );
  }
}
