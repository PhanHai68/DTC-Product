import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/aux_equip_data.dart';
import '../../providers/aux_equip_provider.dart';
import '../../services/pdf_export_service.dart';

class AuxEquipScreen extends StatefulWidget {
  final String? initialModel;

  const AuxEquipScreen({super.key, this.initialModel});

  @override
  State<AuxEquipScreen> createState() => _AuxEquipScreenState();
}

class _AuxEquipScreenState extends State<AuxEquipScreen> {
  final _searchController = TextEditingController();
  final _verticalScrollController = ScrollController();
  final _horizontalScrollController = ScrollController();
  late final String? _resolvedInitialModel;
  bool _isExportingPdf = false;

  @override
  void initState() {
    super.initState();
    final initialModel = widget.initialModel;
    if (initialModel != null && initialModel.isNotEmpty) {
      var cleanModel = initialModel.trim();
      if (!auxEquipSpecsByModel.containsKey(cleanModel)) {
        final matchedKey = auxEquipSpecsByModel.keys.firstWhere(
          (key) =>
              cleanModel.toLowerCase().contains(key.toLowerCase()) ||
              key.toLowerCase().contains(cleanModel.toLowerCase()),
          orElse: () => '',
        );
        if (matchedKey.isNotEmpty) cleanModel = matchedKey;
      }
      _resolvedInitialModel = cleanModel;
      _searchController.text = cleanModel;
    } else {
      _resolvedInitialModel = null;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _sharePdf(AuxEquipProvider provider) async {
    final items = provider.specs;
    final model = provider.selectedModel;
    if (items == null || model == null) return;
    setState(() => _isExportingPdf = true);
    try {
      final bytes = await DtcPdfExportService.buildAuxEquipmentCatalog(
        model: model,
        items: items,
      );
      if (!mounted) return;
      final safeModel = model.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-');
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
              'Danh sách thiết bị phụ trợ máy tách màu ${model.toUpperCase()}',
          title: 'Thiết bị phụ trợ ${model.toUpperCase()}',
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = AuxEquipProvider();
        final initial = _resolvedInitialModel;
        if (initial != null && initial.isNotEmpty) {
          provider.selectModel(initial);
        }
        return provider;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Thiết Bị Phụ Trợ')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Consumer<AuxEquipProvider>(
                    builder: (context, provider, child) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final selector = _buildSelector(provider);
                          final searchButton = _buildSearchButton(provider);
                          final pdfButton = _buildPdfButton(provider);
                          if (constraints.maxWidth < 620) {
                            return Column(
                              children: [
                                selector,
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: searchButton),
                                    const SizedBox(width: 10),
                                    Expanded(child: pdfButton),
                                  ],
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: selector),
                              const SizedBox(width: 12),
                              searchButton,
                              const SizedBox(width: 10),
                              pdfButton,
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Consumer<AuxEquipProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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
                          return const Center(
                            child: Text(
                              'Chọn tên model máy để xem thiết bị phụ trợ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          );
                        }
                        return _buildEquipmentTable(provider.specs!);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelector(AuxEquipProvider provider) {
    return DropdownMenu<String>(
      key: const Key('aux_model_selector'),
      controller: _searchController,
      initialSelection: _resolvedInitialModel,
      expandedInsets: EdgeInsets.zero,
      label: const Text('Chọn tên model máy'),
      enableFilter: true,
      leadingIcon: const Icon(Icons.search),
      dropdownMenuEntries: auxEquipSpecsByModel.keys
          .map(
            (modelName) =>
                DropdownMenuEntry<String>(value: modelName, label: modelName),
          )
          .toList(),
      onSelected: (value) {
        if (value != null) {
          provider.selectModel(value);
          FocusScope.of(context).unfocus();
        }
      },
    );
  }

  Widget _buildSearchButton(AuxEquipProvider provider) {
    return FilledButton.icon(
      key: const Key('aux_search_button'),
      onPressed: provider.isLoading
          ? null
          : () {
              provider.selectModel(_searchController.text);
              FocusScope.of(context).unfocus();
            },
      icon: const Icon(Icons.manage_search_rounded),
      label: const Text('Tra cứu'),
      style: FilledButton.styleFrom(minimumSize: const Size(120, 52)),
    );
  }

  Widget _buildPdfButton(AuxEquipProvider provider) {
    return OutlinedButton.icon(
      key: const Key('aux_export_pdf_button'),
      onPressed: provider.specs == null || _isExportingPdf
          ? null
          : () => _sharePdf(provider),
      icon: _isExportingPdf
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined),
      label: Text(_isExportingPdf ? 'Đang tạo...' : 'Xuất PDF'),
      style: OutlinedButton.styleFrom(minimumSize: const Size(120, 52)),
    );
  }

  Widget _buildEquipmentTable(List<Map<String, String>> specs) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            key: const Key('aux_vertical_scrollbar'),
            controller: _verticalScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              key: const Key('aux_vertical_scroll_view'),
              controller: _verticalScrollController,
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.depth == 1,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      columnSpacing: 26,
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 72,
                      headingRowColor: WidgetStateProperty.all(
                        Colors.blue.withValues(alpha: 0.1),
                      ),
                      columns: const [
                        DataColumn(label: _TableHeading('Tên thiết bị')),
                        DataColumn(label: _TableHeading('Số lượng')),
                        DataColumn(label: _TableHeading('Công suất (HP)')),
                        DataColumn(label: _TableHeading('Quy cách tham khảo')),
                      ],
                      rows: specs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        var equipmentName = item['Tên thiết bị'] ?? '';
                        final normalizedName = equipmentName
                            .toLowerCase()
                            .trim();
                        final isMechanical =
                            normalizedName == 'hệ thống cơ khí phụ trợ' ||
                            normalizedName == 'hệ thống cơ khí';
                        final isCompressedAir =
                            normalizedName == 'hệ thống nén khí' ||
                            normalizedName == 'hệ thống khí nén';
                        final isHeaderRow = isMechanical || isCompressedAir;
                        if (isMechanical) {
                          equipmentName = '1. Hệ thống cơ khí phụ trợ';
                        }
                        if (isCompressedAir) {
                          equipmentName = '2. Hệ thống khí nén';
                        }
                        final rowTextStyle = isHeaderRow
                            ? TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.blue[900],
                              )
                            : null;
                        return DataRow(
                          color: isHeaderRow
                              ? WidgetStateProperty.all(
                                  Colors.blue.withValues(alpha: 0.2),
                                )
                              : index.isEven
                              ? WidgetStateProperty.all(
                                  Colors.grey.withValues(alpha: 0.05),
                                )
                              : null,
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 250,
                                child: Text(equipmentName, style: rowTextStyle),
                              ),
                            ),
                            DataCell(
                              Center(
                                child: Text(
                                  item['SL'] ?? item['Số lượng'] ?? '',
                                ),
                              ),
                            ),
                            DataCell(
                              Center(child: Text(item['Điện năng (HP)'] ?? '')),
                            ),
                            DataCell(
                              SizedBox(
                                width: 280,
                                child: Text(
                                  item['Qui cách tham khảo'] ??
                                      item['Qui cách'] ??
                                      '',
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
          );
        },
      ),
    );
  }
}

class _TableHeading extends StatelessWidget {
  final String text;

  const _TableHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
