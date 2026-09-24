import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grinding_import_report.dart';
import '../providers/grinding_machine_provider.dart';
import '../services/grinding_database_file_picker.dart';

class GrindingDatabaseUpdateScreen extends StatefulWidget {
  const GrindingDatabaseUpdateScreen({
    super.key,
    this.filePicker = const GrindingDatabaseFilePicker(),
  });
  final GrindingDatabaseFilePicker filePicker;

  @override
  State<GrindingDatabaseUpdateScreen> createState() =>
      _GrindingDatabaseUpdateScreenState();
}

class _GrindingDatabaseUpdateScreenState
    extends State<GrindingDatabaseUpdateScreen> {
  Map<String, String?> _metadata = const {};
  GrindingImportPreview? _preview;
  bool _busy = true;
  bool _acknowledged = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMetadata());
  }

  Future<void> _loadMetadata() async {
    if (!mounted) return;
    try {
      final meta = await context
          .read<GrindingMachineProvider>()
          .getImportMetadata();
      if (mounted) setState(() => _metadata = meta);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Không tải được thông tin database: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    final provider = context.read<GrindingMachineProvider>();
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final file = await widget.filePicker.pick();
      if (file == null || !mounted) return;
      setState(() {
        _preview = null;
        _acknowledged = false;
      });
      final preview = await provider.previewImport(file.name, file.bytes);
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) {
        setState(() {
          _preview = null;
          _error = 'Không thể kiểm tra file: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final preview = _preview;
    if (preview == null || !preview.report.canImport || !_acknowledged) return;
    final provider = context.read<GrindingMachineProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await provider.applyImport(preview);
      final meta = await provider.getImportMetadata();
      if (!mounted) return;
      setState(() {
        _metadata = meta;
        _preview = null;
        _acknowledged = false;
        _success =
            'Đã cập nhật database Máy nghiền lên phiên bản ${meta['databaseVersion']}.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error =
              'Không thể hoàn tất cập nhật: $error. Hãy kiểm tra lại file trước khi thử lại.';
          _preview = null;
          _acknowledged = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final report = preview?.report;
    final snapshot = report?.snapshot;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Cập nhật database Máy nghiền')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Database hiện tại',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Phiên bản: ${_metadata['databaseVersion'] ?? 'Đang tải…'}',
                    ),
                    if (_metadata['fileName'] != null)
                      Text('File: ${_metadata['fileName']}'),
                    if (_metadata['sourceDocument'] != null)
                      Text('Nguồn: ${_metadata['sourceDocument']}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Chọn một bản catalog đầy đủ dạng Excel (.xlsx) hoặc JSON. '
              'Ứng dụng sẽ kiểm tra và hiển thị thay đổi trước khi cập nhật.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('grinding_import_pick'),
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Chọn file Excel / JSON'),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  key: const Key('grinding_import_error'),
                  style: TextStyle(color: colors.error),
                ),
              ),
            if (_success != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _success!,
                  key: const Key('grinding_import_success'),
                  style: TextStyle(color: colors.primary),
                ),
              ),
            if (preview != null && report != null) ...[
              const SizedBox(height: 16),
              Text(
                preview.fileName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (snapshot != null) ...[
                Text(
                  'Phiên bản ${preview.currentVersion ?? 'chưa có'} → ${snapshot.databaseVersion}',
                ),
                Text(
                  '${snapshot.series.length} dòng máy · ${snapshot.machines.length} model',
                ),
                Text(
                  '${snapshot.extraSpecs.length} thông số bổ sung · ${snapshot.selectionTags.length} tag',
                ),
                Text(
                  '${snapshot.materials.length} nguyên liệu · ${snapshot.materialSeriesMap.length} liên kết · ${snapshot.aiConfig.length} cấu hình',
                ),
                const SizedBox(height: 8),
                _Changes(title: 'Model mới', ids: preview.added),
                _Changes(title: 'Model đổi thông số', ids: preview.updated),
                _Changes(
                  title: 'Model không còn trong file',
                  ids: preview.removed,
                ),
                const Text(
                  'Thông tin dòng máy, nguyên liệu, tag và cấu hình cũng được thay bằng dữ liệu trong file.',
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '${report.issues.where((i) => i.isError).length} lỗi · '
                '${report.issues.where((i) => !i.isError).length} lưu ý',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final issue in report.issues)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    '${issue.isError ? 'Lỗi' : 'Lưu ý'} — $issue',
                    style: TextStyle(
                      color: issue.isError
                          ? colors.error
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              if (report.canImport) ...[
                CheckboxListTile(
                  key: const Key('grinding_import_acknowledge'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _acknowledged,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _acknowledged = v ?? false),
                  title: const Text(
                    'Tôi đã kiểm tra và đồng ý thay thế catalog Máy nghiền bằng toàn bộ nội dung file này.',
                  ),
                ),
                FilledButton.icon(
                  key: const Key('grinding_import_apply'),
                  onPressed: _busy || !_acknowledged ? null : _apply,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Cập nhật database'),
                ),
              ] else
                const Text(
                  'Chưa thể cập nhật. Hãy sửa các lỗi trong file rồi chọn lại.',
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Changes extends StatelessWidget {
  const _Changes({required this.title, required this.ids});
  final String title;
  final List<String> ids;
  @override
  Widget build(BuildContext context) => ids.isEmpty
      ? Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('$title: 0'),
        )
      : ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('$title: ${ids.length}'),
          children: [
            for (final id in ids) ListTile(dense: true, title: Text(id)),
          ],
        );
}
