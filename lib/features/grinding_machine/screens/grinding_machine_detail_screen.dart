import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../screens/color_sorter/spec_image_export_dialog.dart';
import '../../../widgets/spec_sheet/spec_sheet.dart';
import '../models/grinding_extra_spec.dart';
import '../models/grinding_machine.dart';
import '../models/grinding_series.dart';
import '../providers/grinding_machine_provider.dart';
import '../services/grinding_spec_sheet_pdf_service.dart';
import '../utils/grinding_format.dart';
import '../utils/grinding_spec_sheet.dart';
import '../widgets/grinding_structured_text.dart';

/// Trang thông số kỹ thuật của 1 model — [machineId] truyền qua path param
/// `/grinding_machine/detail/:machineId`. Bố cục và màu sắc theo đúng trang
/// máy tách màu (SC16 Pro) để 2 chức năng thống nhất; dùng bộ khung chung
/// trong lib/widgets/spec_sheet. CHỈ hiển thị field có dữ liệu trong
/// database, không hiển thị placeholder rỗng.
class GrindingMachineDetailScreen extends StatefulWidget {
  const GrindingMachineDetailScreen({super.key, required this.machineId});

  final String machineId;

  @override
  State<GrindingMachineDetailScreen> createState() =>
      _GrindingMachineDetailScreenState();
}

class _GrindingMachineDetailScreenState
    extends State<GrindingMachineDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late String _machineId;
  GrindingMachine? _machine;
  GrindingSeries? _series;
  List<GrindingExtraSpec> _extraSpecs = const [];
  Set<String> _selectionTags = const {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _machineId = widget.machineId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(_machineId));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load(String machineId) async {
    final provider = context.read<GrindingMachineProvider>();
    try {
      final machine = await provider.getMachine(machineId);
      if (machine == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Không tìm thấy model này trong cơ sở dữ liệu.';
          _isLoading = false;
        });
        return;
      }
      final series = await provider.getSeries(machine.seriesCode);
      final extraSpecs = await provider.getExtraSpecs(machine.machineId);
      final tagsBySeries = await provider.getAllSelectionTagsGrouped();
      if (!mounted || machineId != _machineId) return;
      setState(() {
        _machine = machine;
        _series = series;
        _extraSpecs = extraSpecs;
        _selectionTags = tagsBySeries[machine.seriesCode] ?? const {};
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải thông số: $error';
        _isLoading = false;
      });
    }
  }

  void _selectModel(GrindingMachine machine) {
    if (machine.machineId == _machineId) return;
    setState(() => _machineId = machine.machineId);
    _load(machine.machineId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông số kỹ thuật'),
        actions: [
          IconButton(
            key: const Key('grinding_detail_advisor_button'),
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Tư vấn chọn máy',
            onPressed: () => context.push('/grinding_machine/selector'),
          ),
          IconButton(
            key: const Key('grinding_detail_compare_button'),
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'So sánh model',
            onPressed: () =>
                context.push('/grinding_machine/compare', extra: [_machineId]),
          ),
        ],
      ),
      body: _isLoading && _machine == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final machine = _machine!;
    final sheet = GrindingSpecSheet(
      machine: machine,
      series: _series,
      extraSpecs: _extraSpecs,
    );
    final siblings = context.watch<GrindingMachineProvider>().machinesOf(
      machine.seriesCode,
    );
    final models = siblings.isEmpty ? [machine] : siblings;
    final tagLabels = (_selectionTags.toList()..sort())
        .map(GrindingFormat.tagLabel)
        .toList();

    return Column(
      children: [
        SpecModelChipBar(
          keyPrefix: 'grinding_detail_model_',
          models: models.map((m) => m.model).toList(),
          selected: machine.model,
          onSelected: (model) =>
              _selectModel(models.firstWhere((m) => m.model == model)),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SpecTitle(sheet.title),
                if (_series != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _series!.nameVi,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Khung ảnh — chỉ hiện khi dòng máy có ảnh.
                if (sheet.imagePath case final imagePath?) ...[
                  SpecImageCard(
                    imagePath: imagePath,
                    zoomTitle: 'Máy nghiền ${machine.model}',
                    caption: sheet.imageCaption,
                    on3dTap: sheet.has3dModel
                        ? () => context.push('/grinding_machine/asp-3d')
                        : null,
                  ),
                  if (sheet.has3dModel) ...[
                    const SizedBox(height: 10),
                    Spec3dButton(
                      onPressed: () => context.push('/grinding_machine/asp-3d'),
                    ),
                  ],
                  const SizedBox(height: 14),
                ],

                // Chỉ số nổi bật
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

                // Ứng dụng của dòng máy (cùng kiểu thẻ "Ứng dụng" trong
                // "Chi Tiết Ứng Dụng Thực Tế"); dòng chưa có nội dung thì
                // vẫn hiện nhãn ứng dụng như trước.
                if (_series?.applicationVi.isNotEmpty ?? false) ...[
                  GrindingTextSection(
                    key: const Key('grinding_detail_application'),
                    emoji: '🎯',
                    title: 'Ứng dụng',
                    text: _series!.applicationVi,
                    toggleKey: const Key('grinding_detail_application_toggle'),
                    backgroundColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                    titleColor: const Color(0xFF1D4ED8),
                  ),
                  const SizedBox(height: 12),
                ] else if (tagLabels.isNotEmpty) ...[
                  SpecChipWrap(labels: tagLabels),
                  const SizedBox(height: 12),
                ],

                if (_detailSections().isNotEmpty) ...[
                  SpecGradientButton(
                    key: const Key('grinding_detail_application_button'),
                    label: 'Chi Tiết Ứng Dụng',
                    onTap: () => showSpecDetailDialog(
                      context: context,
                      title: 'Chi Tiết Ứng Dụng Thực Tế',
                      sections: _detailSections(),
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
                        'Chưa có dữ liệu kích thước / trọng lượng',
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
                  buttonKey: const Key('grinding_detail_selector_button'),
                  title: 'Chọn máy phù hợp cho nguyên liệu',
                  icon: Icons.tune_rounded,
                  description:
                      'Nhập nguyên liệu, công suất và độ mịn cần đạt để được '
                      'gợi ý model phù hợp.',
                  buttonLabel: 'Mở công cụ chọn máy',
                  onPressed: () => context.push('/grinding_machine/selector'),
                ),
                const SizedBox(height: 16),
                SpecPrimaryButton(
                  key: const Key('grinding_detail_compare_cta'),
                  label: 'So sánh model',
                  icon: Icons.compare_arrows,
                  onPressed: () => context.push(
                    '/grinding_machine/compare',
                    extra: [_machineId],
                  ),
                ),
                const SizedBox(height: 16),
                SpecShareSection(
                  textButtonKey: const Key('copy_grinding_specs_btn'),
                  pdfButtonKey: const Key('export_grinding_specs_pdf_btn'),
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

  List<SpecDetailSection> _detailSections() {
    final series = _series;
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
      if (_selectionTags.isNotEmpty)
        SpecDetailSection(
          emoji: '🏷️',
          title: 'Phù hợp với',
          content: (_selectionTags.toList()..sort())
              .map(GrindingFormat.tagLabel)
              .join(' · '),
        ),
      if (series.notes.isNotEmpty)
        SpecDetailSection(emoji: '📝', title: 'Ghi chú', content: series.notes),
    ];
  }

  void _openShare(BuildContext context, GrindingSpecSheet sheet) {
    showSpecImageExportDialog(
      context: context,
      specs: {'Model': sheet.machine.model},
      imagePath: sheet.imagePath,
      productLabel: 'máy nghiền',
      contentItems: const [
        (Icons.table_chart_outlined, 'Bảng thông số kỹ thuật đầy đủ'),
        (Icons.grid_view_outlined, 'Ứng dụng và nguyên liệu phù hợp'),
        (Icons.location_on_outlined, 'Thông tin liên hệ tư vấn'),
      ],
      buildText: sheet.shareText,
      buildPdf: ({required contactName, required contactPhone}) =>
          GrindingSpecSheetPdfService.buildPdf(
            sheet: sheet,
            selectionTags: _selectionTags,
            contactName: contactName,
            contactPhone: contactPhone,
          ),
    );
  }
}
