import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../../models/stored_file.dart';
import '../../services/storage_service.dart'
    if (dart.library.io) '../../services/storage_service_io.dart'
    if (dart.library.js_interop) '../../services/storage_service_web.dart';

/// Xem mô hình 3D (.glb/.gltf) đã lưu — tái sử dụng ModelViewer hiện có của
/// app (đang dùng cho các máy tách màu), chỉ trỏ src sang file cục bộ qua
/// URI "file://" thay vì asset đóng gói sẵn.
class StoredModelViewerScreen extends StatelessWidget {
  const StoredModelViewerScreen({super.key, required this.file});

  final StoredFile file;

  @override
  Widget build(BuildContext context) {
    final fileUri = Uri.file(file.filePath).toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Chia sẻ',
            onPressed: () => shareStoredFile(file),
          ),
        ],
      ),
      body: ModelViewer(
        backgroundColor: const Color(0xFFF1F5F9),
        src: fileUri,
        alt: 'Mô hình 3D ${file.fileName}',
        ar: false,
        autoRotate: true,
        cameraControls: true,
        loading: Loading.eager,
      ),
    );
  }
}
