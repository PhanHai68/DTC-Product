import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/tea_aux_equip_data.dart';
import '../../services/pdf_export_service.dart';
import '../../theme/dtc_palette.dart';

class TeaAuxEquipScreen extends StatefulWidget {
  final String modelName;

  const TeaAuxEquipScreen({super.key, this.modelName = 'DF53 PRO'});

  @override
  State<TeaAuxEquipScreen> createState() => _TeaAuxEquipScreenState();
}

class _TeaAuxEquipScreenState extends State<TeaAuxEquipScreen> {
  bool _isExportingPdf = false;

  Future<void> _sharePdf() async {
    setState(() => _isExportingPdf = true);
    try {
      final bytes = await DtcPdfExportService.buildTeaAuxEquipmentPdf(
        model: widget.modelName,
        items: teaAuxEquipData,
      );
      if (!mounted) return;

      final safeModel = widget.modelName.replaceAll(
        RegExp(r'[^a-zA-Z0-9]+'),
        '-',
      );
      final fileName = 'thiet-bi-phu-tro-tra-$safeModel.pdf';
      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName),
          ],
          text:
              'Bảng kê chi tiết dây chuyền thiết bị phụ trợ máy tách màu trà ${widget.modelName}',
          title: 'Thiết bị phụ trợ ${widget.modelName}',
          sharePositionOrigin: origin,
          fileNameOverrides: [fileName],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chưa thể xuất PDF: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            toolbarHeight: 68,
            backgroundColor: palette.surface,
            foregroundColor: palette.navy,
            surfaceTintColor: Colors.transparent,
            shadowColor: palette.navy.withValues(alpha: 0.08),
            scrolledUnderElevation: 2,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.all(10),
              child: IconButton.filledTonal(
                tooltip: 'Trở lại',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  }
                },
                style: IconButton.styleFrom(
                  foregroundColor: palette.navy,
                  backgroundColor: palette.cyan.withValues(alpha: 0.14),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            title: Text(
              'Thiết bị phụ trợ ${widget.modelName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.navy,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = teaAuxEquipData[index];
                  return _AuxEquipCard(item: item, index: index);
                },
                childCount: teaAuxEquipData.length,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isExportingPdf ? null : _sharePdf,
        backgroundColor: palette.navy,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: _isExportingPdf
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Icon(Icons.picture_as_pdf_rounded),
        label: Text(
          _isExportingPdf ? 'Đang tạo PDF...' : 'Chia sẻ PDF',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _AuxEquipCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;

  const _AuxEquipCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final hasSpecs =
        (item['power'] as String).isNotEmpty ||
        (item['voltage'] as String).isNotEmpty ||
        (item['dimensions'] as String).isNotEmpty ||
        (item['weight'] as String).isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: palette.navy.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: palette.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: palette.canvas,
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.cyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: palette.cyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'],
                          style: TextStyle(
                            color: palette.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if ((item['model'] as String).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Model: ${item['model']}',
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.canvas,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      'SL: ${item['quantity']} ${item['unit']}',
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Function
                  _buildSection(
                    palette: palette,
                    icon: Icons.auto_awesome_rounded,
                    title: 'Chức năng chính',
                    content: Text(
                      item['function'],
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Components
                  _buildSection(
                    palette: palette,
                    icon: Icons.settings_rounded,
                    title: 'Các bộ phận chính',
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: (item['components'] as List<String>)
                          .map(
                            (comp) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 6,
                                      right: 8,
                                    ),
                                    child: Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: palette.muted,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      comp,
                                      style: TextStyle(
                                        color: palette.ink,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                  // Specs Grid
                  if (hasSpecs) ...[
                    const SizedBox(height: 16),
                    Divider(color: palette.border, height: 1),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if ((item['power'] as String).isNotEmpty)
                          _buildSpecChip(
                            palette,
                            Icons.bolt_rounded,
                            'Công suất',
                            item['power'],
                          ),
                        if ((item['voltage'] as String).isNotEmpty)
                          _buildSpecChip(
                            palette,
                            Icons.power_rounded,
                            'Điện áp',
                            item['voltage'],
                          ),
                        if ((item['dimensions'] as String).isNotEmpty)
                          _buildSpecChip(
                            palette,
                            Icons.straighten_rounded,
                            'Kích thước',
                            item['dimensions'],
                          ),
                        if ((item['weight'] as String).isNotEmpty)
                          _buildSpecChip(
                            palette,
                            Icons.scale_rounded,
                            'Trọng lượng',
                            '${item['weight']} kg',
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required DtcPaletteData palette,
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: palette.cyan),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: palette.navy,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.only(left: 22), child: content),
      ],
    );
  }

  Widget _buildSpecChip(
    DtcPaletteData palette,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.canvas,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.muted),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: palette.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: palette.navy,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
