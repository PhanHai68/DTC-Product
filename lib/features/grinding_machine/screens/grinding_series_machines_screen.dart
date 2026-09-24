import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_series.dart';
import '../providers/grinding_machine_provider.dart';
import '../widgets/grinding_machine_list_tile.dart';

/// Danh sách model thuộc 1 dòng máy (Series) — mở từ Home khi bấm 1 Series
/// card. [seriesCode] truyền qua `extra` của go_router.
class GrindingSeriesMachinesScreen extends StatefulWidget {
  const GrindingSeriesMachinesScreen({super.key, required this.seriesCode});

  final String seriesCode;

  @override
  State<GrindingSeriesMachinesScreen> createState() =>
      _GrindingSeriesMachinesScreenState();
}

class _GrindingSeriesMachinesScreenState
    extends State<GrindingSeriesMachinesScreen> {
  GrindingSeries? _series;
  bool _isLoadingSeries = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<GrindingMachineProvider>();
      final series = await provider.getSeries(widget.seriesCode);
      if (!mounted) return;
      setState(() {
        _series = series;
        _isLoadingSeries = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: Text(_series?.displayCode ?? 'Dòng máy'),
      ),
      body: Consumer<GrindingMachineProvider>(
        builder: (context, provider, _) {
          final machines = provider.machinesOf(widget.seriesCode);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (_isLoadingSeries)
                const Center(child: CircularProgressIndicator())
              else if (_series != null)
                _SeriesHeader(series: _series!),
              const SizedBox(height: 14),
              Text(
                '${machines.length} model',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (machines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'Chưa có model nào trong database cho dòng máy này.',
                      style: TextStyle(color: palette.muted),
                    ),
                  ),
                )
              else
                for (final machine in machines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GrindingMachineListTile(
                      machine: machine,
                      onTap: () => context.push(
                        '/grinding_machine/detail/${machine.machineId}',
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _SeriesHeader extends StatelessWidget {
  const _SeriesHeader({required this.series});

  final GrindingSeries series;

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
            series.nameVi,
            style: TextStyle(
              color: palette.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            series.nameEn,
            style: TextStyle(color: palette.muted, fontSize: 12.5),
          ),
          if (series.applicationVi.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              series.applicationVi,
              style: TextStyle(color: palette.ink, fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
