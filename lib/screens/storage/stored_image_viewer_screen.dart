import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/stored_file.dart';
import '../../services/storage_service.dart'
    if (dart.library.io) '../../services/storage_service_io.dart'
    if (dart.library.js_interop) '../../services/storage_service_web.dart';

/// Màn hình xem ảnh đã lưu, dùng cùng kiểu InteractiveViewer (zoom/pan) đang
/// dùng cho ảnh dự án ở tính năng Theo dõi dự án.
class StoredImageViewerScreen extends StatelessWidget {
  const StoredImageViewerScreen({super.key, required this.file});

  final StoredFile file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Chia sẻ',
            onPressed: () => shareStoredFile(file),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Đóng',
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: .5,
          maxScale: 5,
          child: Image.file(
            File(file.filePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 70,
            ),
          ),
        ),
      ),
    );
  }
}
