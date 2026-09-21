import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/stored_file.dart';
import '../../providers/storage_provider.dart';
import '../../theme/dtc_palette.dart';
import '../../widgets/storage/storage_usage_card.dart';
import '../../widgets/storage/stored_file_tile.dart';

class StorageOverviewScreen extends StatefulWidget {
  const StorageOverviewScreen({super.key});

  @override
  State<StorageOverviewScreen> createState() => _StorageOverviewScreenState();
}

class _StorageOverviewScreenState extends State<StorageOverviewScreen> {
  bool _selectionMode = false;
  final Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StorageProvider>().load();
    });
  }

  void _enterSelectionMode([StoredFile? seedFile]) {
    setState(() {
      _selectionMode = true;
      if (seedFile != null) _selectedPaths.add(seedFile.filePath);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedPaths.clear();
    });
  }

  void _toggleSelected(StoredFile file) {
    setState(() {
      if (!_selectedPaths.add(file.filePath)) {
        _selectedPaths.remove(file.filePath);
      }
      if (_selectedPaths.isEmpty) _selectionMode = false;
    });
  }

  void _toggleSelectAll(List<StoredFile> visibleFiles) {
    setState(() {
      final allSelected = visibleFiles.every((f) => _selectedPaths.contains(f.filePath));
      if (allSelected) {
        _selectedPaths.removeAll(visibleFiles.map((f) => f.filePath));
      } else {
        _selectedPaths.addAll(visibleFiles.map((f) => f.filePath));
      }
    });
  }

  Future<void> _confirmDeleteSelected(List<StoredFile> allFiles) async {
    final selectedFiles = allFiles.where((f) => _selectedPaths.contains(f.filePath)).toList();
    if (selectedFiles.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Xóa ${selectedFiles.length} file đã chọn?'),
        content: const Text(
          'Các file đã chọn sẽ bị xóa khỏi bộ nhớ ứng dụng. Nếu file đang '
          'được dùng trong Ghi chú hoặc Dự án, liên kết tới file đó sẽ không '
          'còn hoạt động. Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deletedCount = await context.read<StorageProvider>().deleteFiles(selectedFiles);
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selectedPaths.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã xóa $deletedCount file.')),
    );
  }

  static const _tabs = [
    (StorageFilter.all, 'Tất cả'),
    (StorageFilter.pdf, 'PDF'),
    (StorageFilter.image, 'Hình ảnh'),
    (StorageFilter.model3d, '3D'),
    (StorageFilter.other, 'Khác'),
  ];

  void _openFile(StoredFile file) {
    if (_selectionMode) {
      _toggleSelected(file);
      return;
    }
    switch (file.category) {
      case StoredFileCategory.pdf:
        context.push('/storage/pdf', extra: file);
      case StoredFileCategory.image:
        context.push('/storage/image', extra: file);
      case StoredFileCategory.model3d:
        context.push('/storage/model', extra: file);
      case StoredFileCategory.other:
        context.read<StorageProvider>().openFileExternally(file);
    }
  }

  Future<void> _confirmDelete(StoredFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa file này?'),
        content: Text(
          '"${file.fileName}" sẽ bị xóa khỏi bộ nhớ ứng dụng. Nếu file đang '
          'được dùng trong Ghi chú hoặc Dự án, liên kết tới file đó sẽ không '
          'còn hoạt động. Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await context.read<StorageProvider>().deleteFile(file);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Đã xóa "${file.fileName}".' : 'Không thể xóa file này.'),
      ),
    );
  }

  Future<void> _confirmClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa bộ nhớ đệm?'),
        content: const Text(
          'Chỉ xóa các file tạm dùng để mở/xem trước tài liệu. Ghi chú, nhắc '
          'hẹn, dự án, lưu mẫu và toàn bộ dữ liệu cá nhân sẽ được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa cache'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final freed = await context.read<StorageProvider>().clearCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã giải phóng ${formatBytes(freed)}.')),
    );
  }

  void _showFileInfo(StoredFile file) {
    final dateFormat = DateFormat("dd/MM/yyyy 'lúc' HH:mm");
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final palette = DtcPalette.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(file.fileName, style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 16),
              _InfoRow(label: 'Chức năng', value: file.featureLabel, palette: palette),
              _InfoRow(label: 'Loại file', value: file.category.label, palette: palette),
              _InfoRow(label: 'Dung lượng', value: formatBytes(file.sizeBytes), palette: palette),
              _InfoRow(
                label: 'Cập nhật lúc',
                value: dateFormat.format(file.modifiedAt),
                palette: palette,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StorageProvider>();
    final visibleFiles = provider.files;
    final allVisibleSelected = visibleFiles.isNotEmpty &&
        visibleFiles.every((f) => _selectedPaths.contains(f.filePath));

    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Thoát chọn',
                onPressed: _exitSelectionMode,
              ),
              title: Text('Đã chọn ${_selectedPaths.length} file'),
              actions: [
                IconButton(
                  icon: Icon(
                    allVisibleSelected ? Icons.deselect : Icons.select_all,
                  ),
                  tooltip: allVisibleSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
                  onPressed: visibleFiles.isEmpty
                      ? null
                      : () => _toggleSelectAll(visibleFiles),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Xóa các file đã chọn',
                  onPressed: _selectedPaths.isEmpty
                      ? null
                      : () => _confirmDeleteSelected(provider.allFiles),
                ),
              ],
            )
          : AppBar(
              title: const Text('Bộ nhớ & Tệp đã lưu'),
              actions: [
                if (visibleFiles.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.checklist_rounded),
                    tooltip: 'Chọn nhiều file',
                    onPressed: _enterSelectionMode,
                  ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: provider.isLoading && provider.files.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  StorageUsageCard(
                    summary: provider.summary,
                    onClearCache: _confirmClearCache,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: provider.setSearchQuery,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Tìm theo tên file...',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _tabs.map((tab) {
                        final selected = provider.filter == tab.$1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(tab.$2),
                            selected: selected,
                            onSelected: (_) => provider.setFilter(tab.$1),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (provider.files.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          provider.searchQuery.isNotEmpty
                              ? 'Không tìm thấy file phù hợp.'
                              : 'Chưa có file nào được lưu.',
                          style: TextStyle(color: DtcPalette.of(context).muted),
                        ),
                      ),
                    )
                  else
                    ...provider.files.map(
                      (file) => StoredFileTile(
                        file: file,
                        selectionMode: _selectionMode,
                        selected: _selectedPaths.contains(file.filePath),
                        onTap: () => _openFile(file),
                        onLongPress: _selectionMode ? null : () => _enterSelectionMode(file),
                        onShare: () => provider.shareFile(file),
                        onInfo: () => _showFileInfo(file),
                        onDelete: () => _confirmDelete(file),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.palette});

  final String label;
  final String value;
  final DtcPaletteData palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: palette.muted, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
