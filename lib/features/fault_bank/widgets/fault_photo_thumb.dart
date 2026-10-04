import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../../../widgets/stored_image.dart';
import '../models/fault_record.dart';
import '../providers/fault_bank_provider.dart';

/// Ô ảnh vuông: bấm để xem lớn, có nút gỡ ảnh khi [onRemove] khác null.
class FaultPhotoThumb extends StatefulWidget {
  const FaultPhotoThumb({
    super.key,
    required this.photo,
    this.size = 88,
    this.onRemove,
  });

  final FaultAttachment photo;
  final double size;
  final VoidCallback? onRemove;

  @override
  State<FaultPhotoThumb> createState() => _FaultPhotoThumbState();
}

class _FaultPhotoThumbState extends State<FaultPhotoThumb> {
  late Future<String?> _path;

  @override
  void initState() {
    super.initState();
    _path = _resolve();
  }

  @override
  void didUpdateWidget(FaultPhotoThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.fileName != widget.photo.fileName) _path = _resolve();
  }

  Future<String?> _resolve() =>
      context.read<FaultBankProvider>().photoService.pathOf(widget.photo);

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final onRemove = widget.onRemove;
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FutureBuilder<String?>(
                future: _path,
                builder: (context, snapshot) {
                  final path = snapshot.data;
                  if (path == null) {
                    return Container(
                      color: palette.canvas,
                      alignment: Alignment.center,
                      child: Icon(
                        snapshot.connectionState == ConnectionState.done
                            ? Icons.broken_image_outlined
                            : Icons.image_outlined,
                        color: palette.muted,
                      ),
                    );
                  }
                  return GestureDetector(
                    onTap: () => showFaultPhotoViewer(context, path),
                    child: StoredImage(path: path),
                  );
                },
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Xem ảnh toàn màn hình, phóng to bằng 2 ngón tay.
Future<void> showFaultPhotoViewer(BuildContext context, String path) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.black.withValues(alpha: 0.92),
      insetPadding: const EdgeInsets.all(8),
      child: Stack(
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Center(
              child: StoredImage(path: path, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: IconButton(
              tooltip: 'Đóng ảnh',
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ),
  );
}
