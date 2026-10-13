import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/drive_item.dart';
import '../services/drive_docs_service.dart';
import '../widgets/drive_file_loader.dart';

/// Danh sách thư mục con và file trong một thư mục Google Drive.
///
/// Xác định thư mục bằng [folderId], hoặc bằng [folderPath] (tên từng cấp
/// tính từ thư mục gốc, ví dụ sản phẩm → loại tài liệu). Cả hai null = thư
/// mục gốc.
class DriveDocsScreen extends StatefulWidget {
  const DriveDocsScreen({
    super.key,
    this.folderId,
    this.folderPath,
    this.title,
    this.subtitle,
    this.missingFolderHint,
  });

  final String? folderId;
  final List<List<String>>? folderPath;
  final String? title;
  final String? subtitle;

  /// Đường dẫn thư mục cần tạo trên Drive, hiện khi [folderPath] chưa có.
  final String? missingFolderHint;

  @override
  State<DriveDocsScreen> createState() => _DriveDocsScreenState();
}

class _FolderListing {
  const _FolderListing(this.items, {this.folderMissing = false});
  final List<DriveItem> items;
  final bool folderMissing;
}

class _DriveDocsScreenState extends State<DriveDocsScreen> {
  final _service = DriveDocsService.instance;
  final _searchController = TextEditingController();
  late Future<_FolderListing> _future = _load();
  String _query = '';

  Future<_FolderListing> _load({bool refresh = false}) async {
    final path = widget.folderPath;
    if (path == null) {
      final folderId = widget.folderId ?? _service.rootFolderId;
      return _FolderListing(
        await _service.listFolder(folderId, refresh: refresh),
      );
    }
    final folderId = await _service.findFolderByPath(path, refresh: refresh);
    if (folderId == null) return const _FolderListing([], folderMissing: true);
    return _FolderListing(
      await _service.listFolder(folderId, refresh: refresh),
    );
  }

  Future<void> _refresh() async {
    final future = _load(refresh: true);
    setState(() => _future = future);
    await future.catchError((_) => const _FolderListing([]));
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title ?? 'Tất cả tài liệu'),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
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
          : FutureBuilder<_FolderListing>(
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

  Widget _buildList(_FolderListing listing) {
    final items = listing.items;
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
          if (visible.isEmpty) _buildEmpty(listing),
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

  Widget _buildEmpty(_FolderListing listing) {
    final String message;
    if (listing.items.isNotEmpty) {
      message = 'Không có tài liệu khớp "$_query".';
    } else if (listing.folderMissing && widget.missingFolderHint != null) {
      message =
          'Chưa có tài liệu.\n\nQuản trị viên tạo thư mục trên Google Drive '
          'rồi tải file vào:\n${widget.missingFolderHint}';
    } else {
      message = 'Chưa có tài liệu.';
    }
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
