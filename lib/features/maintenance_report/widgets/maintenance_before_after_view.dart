import 'package:flutter/material.dart';

import '../../../theme/dtc_palette.dart';
import '../../../widgets/stored_image.dart';
import '../models/maintenance_photo.dart';
import 'verified_photo_badge.dart';

/// Hiển thị Before | After cạnh nhau cho 1 Maintenance Item — có thể có
/// nhiều ảnh mỗi bên (cuộn ngang), ảnh đầu tiên là ảnh chính. Chạm vào 1 ảnh
/// để xem toàn màn hình (zoom/pan) — dùng để so sánh trực quan trước khi
/// tạo PDF.
class MaintenanceBeforeAfterView extends StatelessWidget {
  const MaintenanceBeforeAfterView({
    super.key,
    required this.beforePhotos,
    required this.afterPhotos,
    this.onDeletePhoto,
    this.onAddBefore,
    this.onAddAfter,
  });

  final List<MaintenancePhoto> beforePhotos;
  final List<MaintenancePhoto> afterPhotos;
  final ValueChanged<MaintenancePhoto>? onDeletePhoto;
  final VoidCallback? onAddBefore;
  final VoidCallback? onAddAfter;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PhotoColumn(
            label: 'TRƯỚC',
            photos: beforePhotos,
            onDelete: onDeletePhoto,
            onAdd: onAddBefore,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PhotoColumn(
            label: 'SAU',
            photos: afterPhotos,
            onDelete: onDeletePhoto,
            onAdd: onAddAfter,
          ),
        ),
      ],
    );
  }
}

class _PhotoColumn extends StatelessWidget {
  const _PhotoColumn({
    required this.label,
    required this.photos,
    this.onDelete,
    this.onAdd,
  });

  final String label;
  final List<MaintenancePhoto> photos;
  final ValueChanged<MaintenancePhoto>? onDelete;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: palette.muted,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        if (photos.isEmpty)
          _EmptySlot(onAdd: onAdd, palette: palette)
        else
          Column(
            children: [
              for (final photo in photos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PhotoTile(
                    photo: photo,
                    onDelete: onDelete == null ? null : () => onDelete!(photo),
                  ),
                ),
              if (onAdd != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                    label: const Text('Thêm ảnh'),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.onAdd, required this.palette});

  final VoidCallback? onAdd;
  final DtcPaletteData palette;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, color: palette.muted, size: 26),
            const SizedBox(height: 6),
            Text(
              'Chụp ảnh xác thực',
              style: TextStyle(color: palette.muted, fontSize: 11.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, this.onDelete});

  final MaintenancePhoto photo;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final canDisplay = storedImageCanDisplay(photo.reportPath);
    return GestureDetector(
      onTap: canDisplay ? () => _openFullScreen(context) : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: canDisplay
                  ? StoredImage(path: photo.reportPath)
                  : ColoredBox(
                      color: palette.surface,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: palette.muted,
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${photo.capturedAt.hour.toString().padLeft(2, '0')}:'
                      '${photo.capturedAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(color: palette.muted, fontSize: 11),
                    ),
                  ),
                  VerifiedPhotoBadge(verified: photo.verified),
                  if (onDelete != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onDelete,
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: palette.muted,
                      ),
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

  void _openFullScreen(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: StoredImage(path: photo.reportPath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
