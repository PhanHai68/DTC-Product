import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../screens/color_sorter/spec_image_export_dialog.dart';
import '../../../widgets/spec_sheet/spec_sheet.dart';
import '../../grinding_machine/services/grinding_spec_sheet_pdf_service.dart';
import '../../grinding_machine/widgets/grinding_structured_text.dart';
import '../equipment_catalog_config.dart';
import '../models/equipment_catalog.dart';
import '../providers/equipment_catalog_provider.dart';
import '../utils/equipment_spec_sheet.dart';

/// Trang thông số kỹ thuật 1 model — cùng bố cục trang thông số máy nghiền
/// (chip model, ảnh, 3 chỉ số nổi bật, Chi Tiết Ứng Dụng, 3 tab thông số,
/// chọn máy, so sánh, chia sẻ text/PDF).
class EquipmentDetailScreen extends StatefulWidget {
  const EquipmentDetailScreen({
    super.key,
    required this.config,
    required this.machineId,
  });

  final EquipmentCatalogConfig config;
  final String machineId;

  @override
  State<EquipmentDetailScreen> createState() => _EquipmentDetailScreenState();
}

class _EquipmentDetailScreenState extends State<EquipmentDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late String _machineId;

  EquipmentCatalogConfig get _config => widget.config;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _machineId = widget.machineId;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<EquipmentCatalogProvider>().load(_config),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openCompare() =>
      context.push('${_config.routeBase}/compare', extra: [_machineId]);

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<EquipmentCatalogProvider>().catalog(_config);
    final machine = catalog?.machineById(_machineId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông số kỹ thuật'),
        actions: [
          IconButton(
            key: Key('${_config.id}_detail_compare_button'),
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'So sánh model',
            onPressed: _openCompare,
          ),
        ],
      ),
      body: catalog == null
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
          : _buildBody(context, catalog, machine),
    );
  }

  Widget _buildBody(
    BuildContext context,
    LoadedEquipmentCatalog catalog,
    EquipmentMachine machine,
  ) {
    final id = _config.id;
    final series = catalog.seriesOf(machine.seriesCode);
    final sheet = EquipmentSpecSheet(
      config: _config,
      machine: machine,
      series: series,
      imagePath: catalog.imageOf(machine),
      imageCaption: catalog.imageCaptionOf(machine),
    );
    final models = catalog.machinesOf(machine.seriesCode);
    final sections = _detailSections(series);

    return Column(
      children: [
        if (models.length > 1) ...[
          SpecModelChipBar(
            keyPrefix: '${id}_detail_model_',
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
                    zoomTitle: '${_config.title} ${machine.model}',
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
                    key: Key('${id}_detail_application'),
                    emoji: '🎯',
                    title: 'Ứng dụng',
                    text: series.applicationVi,
                    toggleKey: Key('${id}_detail_application_toggle'),
                    backgroundColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                    titleColor: const Color(0xFF1D4ED8),
                  ),
                  const SizedBox(height: 12),
                ],
                if (sections.isNotEmpty) ...[
                  SpecGradientButton(
                    key: Key('${id}_detail_application_button'),
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
                  buttonKey: Key('${id}_detail_selector_button'),
                  title: 'Chọn ${_config.productLabel} phù hợp nhu cầu',
                  icon: Icons.tune_rounded,
                  description: _config.selectorCtaDescription,
                  buttonLabel: 'Mở công cụ chọn máy',
                  onPressed: () =>
                      context.push('${_config.routeBase}/selector'),
                ),
                const SizedBox(height: 16),
                SpecPrimaryButton(
                  key: Key('${id}_detail_compare_cta'),
                  label: 'So sánh model',
                  icon: Icons.compare_arrows,
                  onPressed: _openCompare,
                ),
                const SizedBox(height: 16),
                SpecShareSection(
                  textButtonKey: Key('copy_${id}_specs_btn'),
                  pdfButtonKey: Key('export_${id}_specs_pdf_btn'),
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

  static List<SpecDetailSection> _detailSections(EquipmentSeries? series) {
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

  void _openShare(BuildContext context, EquipmentSpecSheet sheet) {
    showSpecImageExportDialog(
      context: context,
      specs: {'Model': sheet.machine.model},
      imagePath: sheet.imagePath,
      productLabel: _config.productLabel,
      contentItems: const [
        (Icons.table_chart_outlined, 'Bảng thông số kỹ thuật đầy đủ'),
        (Icons.grid_view_outlined, 'Ứng dụng của dòng máy'),
        (Icons.location_on_outlined, 'Thông tin liên hệ tư vấn'),
      ],
      buildText: sheet.shareText,
      buildPdf: ({required contactName, required contactPhone}) =>
          GrindingSpecSheetPdfService.buildCatalogPdf(
            headerTitle: 'CATALOG ${_config.upperLabel}',
            footerLabel: 'DTCGroup · Catalog ${_config.productLabel}',
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
