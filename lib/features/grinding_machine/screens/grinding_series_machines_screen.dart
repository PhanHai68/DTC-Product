import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../widgets/spec_sheet/spec_sheet.dart';
import '../models/grinding_series.dart';
import '../providers/grinding_machine_provider.dart';
import '../utils/grinding_format.dart';
import '../utils/grinding_series_images.dart';
import '../widgets/grinding_machine_list_tile.dart';
import '../widgets/grinding_structured_text.dart';

/// Danh sách model thuộc 1 dòng máy (Series) — mở từ Home khi bấm 1 Series
/// card. [seriesCode] truyền qua `extra` của go_router. Kiểu dáng theo trang
/// máy tách màu (bộ khung lib/widgets/spec_sheet).
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
  Set<String> _tags = const {};
  bool _isLoadingSeries = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<GrindingMachineProvider>();
      final series = await provider.getSeries(widget.seriesCode);
      final tagsBySeries = await provider.getAllSelectionTagsGrouped();
      if (!mounted) return;
      setState(() {
        _series = series;
        _tags = tagsBySeries[widget.seriesCode] ?? const {};
        _isLoadingSeries = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_series?.displayCode ?? 'Dòng máy')),
      body: Consumer<GrindingMachineProvider>(
        builder: (context, provider, _) {
          final machines = provider.machinesOf(widget.seriesCode);
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
            children: [
              if (_isLoadingSeries)
                const Center(child: CircularProgressIndicator())
              else if (_series != null)
                _SeriesHeader(series: _series!, tags: _tags),
              const SizedBox(height: 16),
              SpecSectionLabel('${machines.length} model'),
              if (machines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'Chưa có model nào trong cơ sở dữ liệu cho dòng máy này.',
                      style: TextStyle(color: Colors.grey.shade600),
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
  const _SeriesHeader({required this.series, required this.tags});

  final GrindingSeries series;
  final Set<String> tags;

  @override
  Widget build(BuildContext context) {
    final isAsp = series.seriesCode == 'ASP_ULTRAFINE';
    final imagePath = GrindingSeriesImages.pathFor(series.seriesCode);
    final tagLabels = (tags.toList()..sort())
        .map(GrindingFormat.tagLabel)
        .toList();
    void open3d() => context.push('/grinding_machine/asp-3d');
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
            // Nội dung nhiều dòng (có gạch đầu dòng) -> canh trái, có cấu trúc.
            const SizedBox(height: 10),
            GrindingStructuredText(
              key: const Key('grinding_series_application'),
              text: series.applicationVi,
            ),
          ] else if (series.applicationVi.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              series.applicationVi,
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
              key: const Key('grinding_series_structure'),
              title: 'Cấu tạo',
              text: series.structureVi,
              toggleKey: const Key('grinding_series_structure_toggle'),
            ),
          ],
          if (series.workingPrincipleVi.contains('\n')) ...[
            const SizedBox(height: 12),
            GrindingTextSection(
              key: const Key('grinding_series_principle'),
              title: 'Nguyên lý hoạt động',
              text: series.workingPrincipleVi,
              toggleKey: const Key('grinding_series_principle_toggle'),
            ),
          ] else if (series.workingPrincipleVi.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text.rich(
              key: const Key('grinding_series_principle'),
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Nguyên lý hoạt động: ',
                    style: TextStyle(
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: series.workingPrincipleVi),
                ],
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          if (series.featuresVi.isNotEmpty) ...[
            const SizedBox(height: 12),
            GrindingFeatureList(
              key: const Key('grinding_series_features'),
              text: series.featuresVi,
            ),
          ],
          // Dòng có ảnh thực tế: hiện ảnh máy thay cho các thẻ ứng dụng.
          if (imagePath != null) ...[
            const SizedBox(height: 12),
            SpecImageCard(
              key: const Key('grinding_series_image'),
              imagePath: imagePath,
              zoomTitle: series.nameVi,
              caption: GrindingSeriesImages.captionFor(series.seriesCode),
              on3dTap: isAsp ? open3d : null,
            ),
          ] else if (tagLabels.isNotEmpty) ...[
            const SizedBox(height: 12),
            SpecChipWrap(labels: tagLabels),
          ],
          if (isAsp) ...[
            const SizedBox(height: 14),
            Spec3dButton(
              key: const Key('grinding_asp_3d_button'),
              label: 'Xem mô hình 3D',
              onPressed: open3d,
            ),
          ],
        ],
      ),
    );
  }
}
