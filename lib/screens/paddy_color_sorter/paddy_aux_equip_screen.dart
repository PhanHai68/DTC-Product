import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/aux_equip_provider.dart';
import '../../services/pdf_export_service.dart';

class PaddyAuxEquipScreen extends StatefulWidget {
  const PaddyAuxEquipScreen({super.key});

  @override
  State<PaddyAuxEquipScreen> createState() => _PaddyAuxEquipScreenState();
}

class _PaddyAuxEquipScreenState extends State<PaddyAuxEquipScreen> {
  final _verticalScrollController = ScrollController();
  final _horizontalScrollController = ScrollController();
  bool _isExportingPdf = false;
  final String _modelName = 'SF7D Pro';

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _sharePdf(AuxEquipProvider provider) async {
    final items = provider.specs;
    if (items == null) return;
    setState(() => _isExportingPdf = true);
    try {
      final bytes = await DtcPdfExportService.buildAuxEquipmentCatalog(
        model: _modelName,
        items: items,
      );
      if (!mounted) return;
      final safeModel = _modelName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-');
      final fileName = 'thiet-bi-phu-tro-$safeModel.pdf';
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
              'Danh sách thiết bị phụ trợ máy tách màu ${_modelName.toUpperCase()}',
          title: 'Thiết bị phụ trợ ${_modelName.toUpperCase()}',
          sharePositionOrigin: origin,
          fileNameOverrides: [fileName],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Chưa thể xuất PDF: $error')));
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Widget _buildPdfButton(AuxEquipProvider provider) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isExportingPdf || provider.specs == null
            ? null
            : () => _sharePdf(provider),
        icon: _isExportingPdf
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.picture_as_pdf),
        label: const Text('Xuất PDF'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = AuxEquipProvider();
        provider.selectModel(_modelName);
        return provider;
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Thiết bị phụ trợ $_modelName')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Consumer<AuxEquipProvider>(
                builder: (context, provider, child) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: _buildPdfButton(provider),
                  );
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Consumer<AuxEquipProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (provider.errorMessage != null) {
                      return Center(
                        child: Text(
                          provider.errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }
                    if (provider.specs == null) {
                      return const Center(child: Text('Đang tải dữ liệu...'));
                    }
                    return _buildSpecsTable(provider.specs!);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecsTable(List<Map<String, dynamic>> specs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Scrollbar(
          controller: _verticalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _verticalScrollController,
            scrollDirection: Axis.vertical,
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Colors.blue.shade100,
                  ),
                  dataRowMaxHeight: double.infinity,
                  dataRowMinHeight: 48,
                  horizontalMargin: 20,
                  columnSpacing: 30,
                  dividerThickness: 1,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'STT',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Tên thiết bị',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'SL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'Điện năng (HP)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'Quy cách',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: specs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    final isEven = index % 2 == 0;
                    return DataRow(
                      color: WidgetStateProperty.all(
                        isEven ? Colors.grey.shade50 : Colors.white,
                      ),
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(
                          Container(
                            constraints: const BoxConstraints(maxWidth: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              row['Tên thiết bị']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            row['SL']?.toString() ?? '',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        DataCell(
                          Text(
                            row['Điện năng (HP)']?.toString() ?? '',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        DataCell(
                          Container(
                            constraints: const BoxConstraints(maxWidth: 250),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              row['Qui cách']?.toString() ?? '',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
