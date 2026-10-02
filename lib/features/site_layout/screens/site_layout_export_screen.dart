import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/site_layout_provider.dart';
import '../services/site_layout_file_storage.dart';
import '../services/site_layout_image_service.dart';
import '../services/site_layout_pdf_service.dart';

class SiteLayoutExportScreen extends StatefulWidget {
  const SiteLayoutExportScreen({super.key, required this.projectId});
  final String projectId;

  @override
  State<SiteLayoutExportScreen> createState() => _SiteLayoutExportScreenState();
}

class _SiteLayoutExportScreenState extends State<SiteLayoutExportScreen> {
  bool _showGrid = true;
  bool _showClearance = true;
  bool _showMeasurements = true;
  bool _showNotes = true;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final bundle = context.watch<SiteLayoutProvider>().bundle;
    return Scaffold(
      appBar: AppBar(title: const Text('Xuất hồ sơ mặt bằng')),
      body: bundle == null || bundle.project.id != widget.projectId
          ? const Center(child: Text('Không tìm thấy dữ liệu dự án.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bundle.project.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${bundle.layout.name} · ${bundle.machines.length} thiết bị · ${bundle.photos.length} ảnh',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Hiển thị lưới'),
                        value: _showGrid,
                        onChanged: (value) => setState(() => _showGrid = value),
                      ),
                      SwitchListTile(
                        title: const Text('Hiển thị vùng khoảng hở'),
                        value: _showClearance,
                        onChanged: (value) =>
                            setState(() => _showClearance = value),
                      ),
                      SwitchListTile(
                        title: const Text('Hiển thị phép đo'),
                        value: _showMeasurements,
                        onChanged: (value) =>
                            setState(() => _showMeasurements = value),
                      ),
                      SwitchListTile(
                        title: const Text('Hiển thị ghi chú và marker ảnh'),
                        value: _showNotes,
                        onChanged: (value) =>
                            setState(() => _showNotes = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _exportPng(context),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Xuất ảnh PNG toàn bộ mặt bằng'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _exportPdf(context),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Xuất báo cáo PDF'),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Báo cáo hỗ trợ khảo sát sơ bộ. Kích thước và điều kiện lắp đặt phải được xác nhận tại hiện trường trước khi thi công.',
                  textAlign: TextAlign.center,
                ),
                if (_busy) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
    );
  }

  Future<void> _exportPng(BuildContext context) async {
    final bundle = context.read<SiteLayoutProvider>().bundle!;
    await _run(() async {
      final bytes = await SiteLayoutImageService.buildPng(
        bundle,
        showGrid: _showGrid,
        showClearance: _showClearance,
        showMeasurements: _showMeasurements,
        showNotes: _showNotes,
      );
      await _saveAndShare(bytes, 'png', 'image/png');
    });
  }

  Future<void> _exportPdf(BuildContext context) async {
    final bundle = context.read<SiteLayoutProvider>().bundle!;
    await _run(() async {
      final bytes = await SiteLayoutPdfService.build(bundle);
      await _saveAndShare(bytes, 'pdf', 'application/pdf');
    });
  }

  Future<void> _saveAndShare(
    Uint8List bytes,
    String extension,
    String mimeType,
  ) async {
    final bundle = context.read<SiteLayoutProvider>().bundle!;
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final safeName = bundle.project.name
        .replaceAll(RegExp(r'[^A-Za-z0-9À-ỹ_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final fileName = 'DTC_${safeName}_$stamp.$extension';
    final path = await saveSiteLayoutExport(
      projectId: bundle.project.id,
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
    final file = kIsWeb
        ? XFile.fromData(bytes, mimeType: mimeType, name: fileName)
        : XFile(path, mimeType: mimeType, name: fileName);
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        subject: '${bundle.project.name} - ${bundle.layout.name}',
      ),
    );
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể xuất tệp: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
