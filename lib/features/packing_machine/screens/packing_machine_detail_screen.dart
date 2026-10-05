import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../screens/color_sorter/spec_image_export_dialog.dart';
import '../../../widgets/spec_sheet/spec_sheet.dart';
import '../../grinding_machine/services/grinding_spec_sheet_pdf_service.dart';
import '../../grinding_machine/widgets/grinding_structured_text.dart';
import '../models/packing_catalog.dart';
import '../providers/packing_machine_provider.dart';
import '../utils/packing_spec_sheet.dart';

/// Trang thông số kỹ thuật 1 model máy đóng gói — cùng bố cục trang thông số
/// máy nghiền (chip model, ảnh, 3 chỉ số nổi bật, Chi Tiết Ứng Dụng, 3 tab
/// thông số, so sánh, chia sẻ text/PDF).
class PackingMachineDetailScreen extends StatefulWidget {
  const PackingMachineDetailScreen({super.key, required this.machineId});

  final String machineId;

  @override
  State<PackingMachineDetailScreen> createState() =>
      _PackingMachineDetailScreenState();
}

class _PackingMachineDetailScreenState extends State<PackingMachineDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late String _machineId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _machineId = widget.machineId;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PackingMachineProvider>().load(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PackingMachineProvider>();
    final machine = provider.machineById(_machineId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông số kỹ thuật'),
        actions: [
          IconButton(
            key: const Key('packing_detail_compare_button'),
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'So sánh model',
            onPressed: () =>
                context.push('/packing_machine/compare', extra: [_machineId]),
          ),
        ],
      ),
      body: !provider.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : machine == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không tìm thấy model này trong catalog.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          : _buildBody(context, provider, machine),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PackingMachineProvider provider,
    PackingMachine machine,
  ) {
    final series = provider.seriesOf(machine.seriesCode);
    final sheet = PackingSpecSheet(
      machine: machine,
      series: series,
      imagePath: provider.imageOf(machine),
      imageCaption: provider.imageCaptionOf(machine),
    );
    final models = provider.machinesOf(machine.seriesCode);
    final sections = _detailSections(series);

    return Column(
      children: [
        if (models.length > 1) ...[
          SpecModelChipBar(
            keyPrefix: 'packing_detail_model_',
            models: models.map((m) => m.model).toList(),
            selected: machine.model,
            onSelected: (model) => setState(
              () => _machineId = models
                  .firstWhere((m) => m.model == model)
                  .machineId,
            ),
          ),
          const Divider(height: 1),
        ],
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SpecTitle(sheet.title),
                if (series != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    series.nameVi,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (sheet.imagePath case final imagePath?) ...[
                  SpecImageCard(
                    imagePath: imagePath,
                    zoomTitle: 'Máy đóng gói ${machine.model}',
                    caption: sheet.imageCaption,
                  ),
                  const SizedBox(height: 14),
                ],
                if (sheet.highlights.isNotEmpty) ...[
                  Row(
                    children: [
                      for (var i = 0; i < sheet.highlights.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        SpecHighlightCard(
                          title: sheet.highlights[i].$1,
                          value: sheet.highlights[i].$2,
                          icon: sheet.highlights[i].$3,
                          color: sheet.highlights[i].$4,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                if (series != null && series.applicationVi.isNotEmpty) ...[
                  GrindingTextSection(
                    key: const Key('packing_detail_application'),
                    emoji: '🎯',
                    title: 'Ứng dụng',
                    text: series.applicationVi,
                    toggleKey: const Key('packing_detail_application_toggle'),
                    backgroundColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                    titleColor: const Color(0xFF1D4ED8),
                  ),
                  const SizedBox(height: 12),
                ],
                if (sections.isNotEmpty) ...[
                  SpecGradientButton(
                    key: const Key('packing_detail_application_button'),
                    label: 'Chi Tiết Ứng Dụng',
                    onTap: () => showSpecDetailDialog(
                      context: context,
                      title: 'Chi Tiết Ứng Dụng Thực Tế',
                      sections: sections,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const SpecSectionLabel('Thông số chi tiết'),
                SpecPillTabBar(
                  controller: _tabController,
                  labels: const [
                    'Thông số\nkỹ thuật',
                    'Thông số\nbổ sung',
                    'Lắp đặt',
                  ],
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    final (rows, emptyMessage) = switch (_tabController.index) {
                      1 => (
                        sheet.extraRows,
                        'Model này chưa có thông số bổ sung',
                      ),
                      2 => (
                        sheet.installRows,
                        'Catalog chưa có dữ liệu lắp đặt cho model này',
                      ),
                      _ => (sheet.technicalRows, 'Chưa có thông số kỹ thuật'),
                    };
                    return SpecRowsCard(
                      children: rows.isEmpty
                          ? [SpecEmptyRows(emptyMessage)]
                          : [
                              for (var i = 0; i < rows.length; i++)
                                SpecRow(
                                  label: rows[i].label,
                                  value: rows[i].value,
                                  icon: rows[i].icon,
                                  color: rows[i].color,
                                  showDivider: i < rows.length - 1,
                                ),
                            ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                SpecCtaBlock(
                  buttonKey: const Key('packing_detail_selector_button'),
                  title: 'Chọn máy phù hợp nhu cầu đóng gói',
                  icon: Icons.tune_rounded,
                  description:
                      'Nhập dạng nguyên liệu, khối lượng gói, tốc độ và bao '
                      'bì để được gợi ý model phù hợp.',
                  buttonLabel: 'Mở công cụ chọn máy',
                  onPressed: () => context.push('/packing_machine/selector'),
                ),
                const SizedBox(height: 16),
                SpecPrimaryButton(
                  key: const Key('packing_detail_compare_cta'),
                  label: 'So sánh model',
                  icon: Icons.compare_arrows,
                  onPressed: () => context.push(
                    '/packing_machine/compare',
                    extra: [_machineId],
                  ),
                ),
                const SizedBox(height: 16),
                SpecShareSection(
                  textButtonKey: const Key('copy_packing_specs_btn'),
                  pdfButtonKey: const Key('export_packing_specs_pdf_btn'),
                  onShare: () => _openShare(context, sheet),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static List<SpecDetailSection> _detailSections(PackingSeries? series) {
    if (series == null) return const [];
    return [
      if (series.applicationVi.isNotEmpty)
        SpecDetailSection(
          emoji: '🎯',
          title: 'Ứng dụng',
          content: series.applicationVi,
        ),
      if (series.structureVi.isNotEmpty)
        SpecDetailSection(
          emoji: '🔧',
          title: 'Cấu tạo',
          content: series.structureVi,
        ),
      if (series.workingPrincipleVi.isNotEmpty)
        SpecDetailSection(
          emoji: '⚙️',
          title: 'Nguyên lý hoạt động',
          content: series.workingPrincipleVi,
        ),
      if (series.featuresVi.isNotEmpty)
        SpecDetailSection(
          emoji: '✨',
          title: 'Đặc điểm chính',
          content: series.featuresVi,
        ),
    ];
  }

  void _openShare(BuildContext context, PackingSpecSheet sheet) {
    showSpecImageExportDialog(
      context: context,
      specs: {'Model': sheet.machine.model},
      imagePath: sheet.imagePath,
      productLabel: 'máy đóng gói',
      contentItems: const [
        (Icons.table_chart_outlined, 'Bảng thông số kỹ thuật đầy đủ'),
        (Icons.grid_view_outlined, 'Ứng dụng của dòng máy'),
        (Icons.location_on_outlined, 'Thông tin liên hệ tư vấn'),
      ],
      buildText: sheet.shareText,
      buildPdf: ({required contactName, required contactPhone}) =>
          GrindingSpecSheetPdfService.buildCatalogPdf(
            headerTitle: 'CATALOG MÁY ĐÓNG GÓI',
            footerLabel: 'DTCGroup · Catalog máy đóng gói',
            title: sheet.title,
            subtitle: sheet.series?.nameVi,
            imagePath: sheet.imagePath,
            imageCaption: sheet.imageCaption,
            groups: [
              ('THÔNG SỐ KỸ THUẬT', sheet.technicalRows),
              ('THÔNG SỐ BỔ SUNG', sheet.extraRows),
              ('LẮP ĐẶT', sheet.installRows),
            ],
            applicationText: sheet.series?.applicationVi ?? '',
            contactName: contactName,
            contactPhone: contactPhone,
          ),
    );
  }
}
