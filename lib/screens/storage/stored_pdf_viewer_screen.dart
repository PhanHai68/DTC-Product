import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../models/stored_file.dart';
import '../../services/storage_service.dart'
    if (dart.library.io) '../../services/storage_service_io.dart'
    if (dart.library.js_interop) '../../services/storage_service_web.dart';

/// Màn hình xem PDF đã lưu trong "Bộ nhớ & Tệp đã lưu" — cùng thư viện
/// Syncfusion đang dùng cho catalog/hướng dẫn sử dụng, chỉ đổi nguồn sang
/// file trên thiết bị thay vì asset đóng gói sẵn.
class StoredPdfViewerScreen extends StatelessWidget {
  const StoredPdfViewerScreen({super.key, required this.file});

  final StoredFile file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Chia sẻ',
            onPressed: () => shareStoredFile(file),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Đóng tài liệu',
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: SfPdfViewer.file(
        File(file.filePath),
        canShowScrollHead: true,
        canShowScrollStatus: true,
      ),
    );
  }
}
