import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../drive_docs_config.dart';
import '../models/drive_item.dart';
import '../services/drive_docs_service.dart';
import '../widgets/drive_file_loader.dart';

/// Xếp các mục có tên trong [order] lên trước, đúng thứ tự đó (không phân
/// biệt hoa thường); các mục còn lại giữ thứ tự sẵn có ở phía sau.
@visibleForTesting
List<DriveItem> orderByNames(List<DriveItem> items, List<String> order) {
  final rank = {
    for (var i = 0; i < order.length; i++) order[i].trim().toLowerCase(): i,
  };
  int rankOf(DriveItem item) =>
      rank[item.name.trim().toLowerCase()] ?? order.length;
  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final byRank = rankOf(a.$2).compareTo(rankOf(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
  return [for (final (_, item) in indexed) item];
}

/// Thư viện tài liệu: thư mục con và file trong một thư mục Google Drive.
/// [folderId] null = thư mục gốc, xếp theo [driveDocsRootOrder].
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

  Future<List<DriveItem>> _load({bool refresh = false}) async {
    final folderId = widget.folderId;
    if (folderId != null) {
      return _service.listFolder(folderId, refresh: refresh);
    }
    final items = await _service.listFolder(
      _service.rootFolderId,
      refresh: refresh,
    );
    return orderByNames(items, driveDocsRootOrder);
  }

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

  Future<void> _open(DriveItem item) async {
    if (item.isFolder) {
      context.push(
        Uri(
          path: '/documents/folder',
          queryParameters: {'id': item.id, 'title': item.name},
        ).toString(),
      );
    } else if (item.isPdf) {
      context.push('/documents/view', extra: item);
    } else if (item.isImage) {
      context.push('/documents/image', extra: item);
    } else if (item.isVideo) {
      context.push('/documents/video', extra: item);
    } else {
      final opened = await launchUrl(
        item.driveViewUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không mở được file bằng Google Drive.'),
          ),
        );
      }
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
          if (items.isNotEmpty) ...[
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
          ],
          if (visible.isEmpty) _buildEmpty(items),
          for (final item in visible)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(_iconOf(item), color: _colorOf(item), size: 32),
                title: Text(item.name),
                subtitle: item.isFolder ? null : Text(_fileInfo(item)),
                trailing: Icon(
                  item.opensInDrive
                      ? Icons.open_in_new_rounded
                      : Icons.chevron_right_rounded,
                ),
                onTap: () => _open(item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(List<DriveItem> items) {
    final message = items.isEmpty
        ? 'Chưa có tài liệu.'
        : 'Không có tài liệu khớp "$_query".';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 64, 16, 0),
      child: Column(
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  static IconData _iconOf(DriveItem item) {
    if (item.isFolder) return Icons.folder_rounded;
    if (item.isPdf) return Icons.picture_as_pdf_rounded;
    if (item.isImage) return Icons.image_rounded;
    if (item.isVideo) return Icons.play_circle_rounded;
    return Icons.insert_drive_file_rounded;
  }

  static Color _colorOf(DriveItem item) {
    if (item.isFolder) return Colors.amber.shade700;
    if (item.isPdf) return Colors.red.shade600;
    if (item.isImage) return Colors.teal.shade600;
    if (item.isVideo) return Colors.indigo.shade500;
    return Colors.blueGrey.shade500;
  }

  static String _fileInfo(DriveItem item) {
    final parts = <String>[
      if (item.size != null) _formatSize(item.size!),
      if (item.modifiedTime != null)
        'Cập nhật ${DateFormat('dd/MM/yyyy').format(item.modifiedTime!.toLocal())}',
      if (item.opensInDrive) 'Mở bằng Google Drive',
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
