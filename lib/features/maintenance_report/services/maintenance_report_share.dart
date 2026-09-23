import 'dart:typed_data';
import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/maintenance_report.dart';

String _safeFilePart(String value) => value
    .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
    .replaceAll(RegExp(r'\s+'), '')
    .trim();

/// Tên file PDF theo đúng quy cách Mã phiên bảo trì:
/// `TTM-<viết tắt kỹ sư>-<tên khách hàng>-<yyyyMMdd>.pdf`. Report luôn đã có
/// sessionId ở thời điểm gọi hàm này (nút "Tạo PDF & Chia sẻ" chỉ hiện sau
/// khi đã Start Maintenance) — nhánh dự phòng dưới đây chỉ để an toàn.
String maintenanceReportFileName(MaintenanceReport report) {
  final sessionId = report.sessionId;
  if (sessionId != null && sessionId.isNotEmpty) {
    return '$sessionId.pdf';
  }
  final date = DateFormat('yyyyMMdd').format(report.maintenanceDate);
  final customer = _safeFilePart(
    report.customerName.isEmpty ? 'KH' : report.customerName,
  );
  return 'TTM-$customer-$date.pdf';
}

/// Mở system share sheet (Zalo/Email/Messenger/Drive/Files/...) cho file PDF
/// vừa tạo — không tích hợp API Zalo, chỉ dùng share native.
Future<void> shareMaintenanceReportPdf({
  required Uint8List bytes,
  required String fileName,
  required MaintenanceReport report,
  Rect? origin,
}) {
  return SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName)],
      title: 'Báo cáo tình trạng máy - ${report.customerName}',
      text:
          'Báo cáo tình trạng máy - ${report.customerName} - ${report.machineModel}',
      sharePositionOrigin: origin,
      fileNameOverrides: [fileName],
    ),
  );
}
