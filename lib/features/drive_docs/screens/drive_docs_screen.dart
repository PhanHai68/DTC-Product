import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/drive_item.dart';
import '../services/drive_docs_service.dart';
import '../widgets/drive_pdf_loader.dart';

/// Thư viện tài liệu: duyệt thư mục Google Drive và mở file PDF.
/// [folderId] null = thư mục gốc.
class DriveDocsScreen extends StatefulWidget {
  const DriveDocsScreen({super.key, this.folderId, this.title});

  final String? folderId;
  final String? title;

  @override
  State<DriveDocsScreen> createState() => _DriveDocsScreenState();
}

class _DriveDocsScreenState extends State<DriveDocsScreen> {
  final _service = DriveDocsService.instance;
  final _searchController = TextEditingController();
  late Future<List<DriveItem>> _future = _load();
  String _query = '';

  String get _folderId => widget.folderId ?? _service.rootFolderId;

  Future<List<DriveItem>> _load({bool refresh = false}) =>
      _service.listFolder(_folderId, refresh: refresh);

  Future<void> _refresh() async {
    final future = _load(refresh: true);
    setState(() => _future = future);
    await future.catchError((_) => <DriveItem>[]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _open(DriveItem item) {
    if (item.isFolder) {
      context.push(
        Uri(
          path: '/documents',
          queryParameters: {'folder': item.id, 'title': item.name},
        ).toString(),
      );
    } else {
      context.push('/documents/view', extra: item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Thư viện tài liệu')),
      body: !_service.isConfigured
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Thư viện tài liệu Google Drive chưa được cấu hình.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : FutureBuilder<List<DriveItem>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return DriveDocsErrorView(
                    message: error is DriveDocsException
                        ? error.message
                        : 'Không tải được danh sách tài liệu.',
                    onRetry: _refresh,
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildList(snapshot.data!);
              },
            ),
    );
  }

  Widget _buildList(List<DriveItem> items) {
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? items
        : items.where((i) => i.name.toLowerCase().contains(query)).toList();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Tìm trong thư mục này',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                items.isEmpty
                    ? 'Thư mục chưa có tài liệu PDF.'
                    : 'Không có tài liệu khớp "$_query".',
                textAlign: TextAlign.center,
              ),
            ),
          for (final item in visible)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  item.isFolder
                      ? Icons.folder_rounded
                      : Icons.picture_as_pdf_rounded,
                  color: item.isFolder
                      ? Colors.amber.shade700
                      : Colors.red.shade600,
                  size: 32,
                ),
                title: Text(item.name),
                subtitle: item.isFolder ? null : Text(_fileInfo(item)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _open(item),
              ),
            ),
        ],
      ),
    );
  }

  static String _fileInfo(DriveItem item) {
    final parts = <String>[
      if (item.size != null) _formatSize(item.size!),
      if (item.modifiedTime != null)
        'Cập nhật ${DateFormat('dd/MM/yyyy').format(item.modifiedTime!.toLocal())}',
    ];
    return parts.join(' · ');
  }

  static String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }
}
