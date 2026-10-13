import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../models/drive_item.dart';
import '../services/drive_docs_service.dart';
import '../widgets/drive_file_loader.dart';
import '../widgets/drive_share_sheet.dart';

/// Xem một PDF trên Google Drive, theo [item] (mở từ thư viện) hoặc theo
/// [fileName] (tài liệu cố định mà màn hình khác trỏ tới).
class DrivePdfViewerScreen extends StatelessWidget {
  const DrivePdfViewerScreen({
    super.key,
    required this.title,
    this.item,
    this.fileName,
    this.initialPage = 1,
  }) : assert(item != null || fileName != null);

  final String title;
  final DriveItem? item;
  final String? fileName;
  final int initialPage;

  @override
  Widget build(BuildContext context) {
    final service = DriveDocsService.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          DriveShareButton(item: item, pdfName: fileName),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Đóng tài liệu',
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: DriveFileLoader(
        load: () => item != null
            ? service.loadFile(item!)
            : service.loadPdfByName(fileName!),
        builder: (context, bytes) => SfPdfViewer.memory(
          bytes,
          initialPageNumber: initialPage,
          canShowScrollHead: true,
          canShowScrollStatus: true,
        ),
      ),
    );
  }
}
