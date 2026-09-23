import 'dart:typed_data';
import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/maintenance_report.dart';

String _safeFilePart(String value) => value
    .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
    .replaceAll(RegExp(r'\s+'), '')
    .trim();

/// `MaintenanceReport_<Customer>_<Machine>_<yyyyMMdd>.pdf`
String maintenanceReportFileName(MaintenanceReport report) {
  final date = DateFormat('yyyyMMdd').format(report.maintenanceDate);
  final customer = _safeFilePart(
    report.customerName.isEmpty ? 'Customer' : report.customerName,
  );
  final machine = _safeFilePart(
    report.machineName.isEmpty ? 'Machine' : report.machineName,
  );
  return 'MaintenanceReport_${customer}_${machine}_$date.pdf';
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
      title: 'Maintenance Report - ${report.customerName}',
      text: 'Maintenance Report - ${report.customerName} - ${report.machineName}',
      sharePositionOrigin: origin,
      fileNameOverrides: [fileName],
    ),
  );
}
