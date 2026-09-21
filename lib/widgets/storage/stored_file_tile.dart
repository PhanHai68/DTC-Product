import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/stored_file.dart';
import '../../theme/dtc_palette.dart';

class StoredFileTile extends StatelessWidget {
  const StoredFileTile({
    super.key,
    required this.file,
    required this.onTap,
    required this.onShare,
    required this.onInfo,
    required this.onDelete,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
  });

  final StoredFile file;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onInfo;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;

  /// Khi bật, chạm vào ô sẽ chọn/bỏ chọn file thay vì mở xem, và icon phân
  /// loại được thay bằng checkbox.
  final bool selectionMode;
  final bool selected;

  IconData get _icon => switch (file.category) {
    StoredFileCategory.pdf => Icons.picture_as_pdf_outlined,
    StoredFileCategory.image => Icons.image_outlined,
    StoredFileCategory.model3d => Icons.view_in_ar_outlined,
    StoredFileCategory.other => Icons.insert_drive_file_outlined,
  };

  Color _iconColor(DtcPaletteData palette) => switch (file.category) {
    StoredFileCategory.pdf => const Color(0xFFE53935),
    StoredFileCategory.image => const Color(0xFF43A047),
    StoredFileCategory.model3d => const Color(0xFF1E88E5),
    StoredFileCategory.other => const Color(0xFFFB8C00),
  };

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? _iconColor(palette).withValues(alpha: 0.08) : null,
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: selectionMode
            ? Checkbox(value: selected, onChanged: (_) => onTap())
            : CircleAvatar(
                backgroundColor: _iconColor(palette).withValues(alpha: 0.12),
                child: Icon(_icon, color: _iconColor(palette)),
              ),
        title: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${file.featureLabel} · ${formatBytes(file.sizeBytes)} · ${dateFormat.format(file.modifiedAt)}',
          style: TextStyle(color: palette.muted, fontSize: 12.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: selectionMode
            ? null
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'share':
                      onShare();
                    case 'info':
                      onInfo();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: Icon(Icons.share_outlined),
                      title: Text('Chia sẻ'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'info',
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Thông tin'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Xóa', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
