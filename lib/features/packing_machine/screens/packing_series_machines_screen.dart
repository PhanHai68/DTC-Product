import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../widgets/spec_sheet/spec_sheet.dart';
import '../../grinding_machine/widgets/grinding_structured_text.dart';
import '../models/packing_catalog.dart';
import '../providers/packing_machine_provider.dart';
import '../widgets/packing_machine_list_tile.dart';

/// Trang 1 dòng máy đóng gói — cùng bố cục trang dòng máy nghiền: Ứng dụng,
/// Cấu tạo, Nguyên lý, Đặc điểm chính, ảnh, rồi danh sách model.
class PackingSeriesMachinesScreen extends StatefulWidget {
  const PackingSeriesMachinesScreen({super.key, required this.seriesCode});

  final String seriesCode;

  @override
  State<PackingSeriesMachinesScreen> createState() =>
      _PackingSeriesMachinesScreenState();
}

class _PackingSeriesMachinesScreenState
    extends State<PackingSeriesMachinesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PackingMachineProvider>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PackingMachineProvider>(
      builder: (context, provider, _) {
        final series = provider.seriesOf(widget.seriesCode);
        final machines = provider.machinesOf(widget.seriesCode);
        return Scaffold(
          appBar: AppBar(title: Text(series?.displayCode ?? 'Dòng máy')),
          body: !provider.isLoaded
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
                  children: [
                    if (series != null) _SeriesHeader(series: series),
                    const SizedBox(height: 16),
                    SpecSectionLabel('${machines.length} model'),
                    for (final machine in machines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PackingMachineListTile(
                          machine: machine,
                          imagePath: provider.imageOf(machine),
                          onTap: () => context.push(
                            '/packing_machine/detail/${machine.machineId}',
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _SeriesHeader extends StatelessWidget {
  const _SeriesHeader({required this.series});

  final PackingSeries series;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SpecTitle(series.nameVi.toUpperCase()),
          if (series.applicationVi.contains('\n')) ...[
            const SizedBox(height: 10),
            GrindingStructuredText(
              key: const Key('packing_series_application'),
              text: series.applicationVi,
            ),
          ] else if (series.applicationVi.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              series.applicationVi,
              key: const Key('packing_series_application'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          if (series.structureVi.isNotEmpty) ...[
            const SizedBox(height: 12),
            GrindingTextSection(
              key: const Key('packing_series_structure'),
              title: 'Cấu tạo',
              text: series.structureVi,
              toggleKey: const Key('packing_series_structure_toggle'),
            ),
          ],
          if (series.workingPrincipleVi.isNotEmpty) ...[
            const SizedBox(height: 12),
            GrindingTextSection(
              key: const Key('packing_series_principle'),
              title: 'Nguyên lý hoạt động',
              text: series.workingPrincipleVi,
              toggleKey: const Key('packing_series_principle_toggle'),
            ),
          ],
          if (series.featuresVi.isNotEmpty) ...[
            const SizedBox(height: 12),
            GrindingFeatureList(
              key: const Key('packing_series_features'),
              text: series.featuresVi,
            ),
          ],
          if (series.image case final image?) ...[
            const SizedBox(height: 12),
            SpecImageCard(
              key: const Key('packing_series_image'),
              imagePath: image,
              zoomTitle: series.nameVi,
              caption: series.imageCaption,
            ),
          ],
        ],
      ),
    );
  }
}
