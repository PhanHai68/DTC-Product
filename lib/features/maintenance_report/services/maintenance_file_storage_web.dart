// Bản Web đơn giản hoá: Maintenance Report (chụp ảnh Verified Camera + xác
// minh SHA-256) là tính năng dành cho kỹ sư dùng điện thoại tại hiện trường,
// không phải luồng chính trên Web — chỉ giữ cho code biên dịch được, lưu ảnh
// dạng data URL trong bộ nhớ phiên làm việc (không có Internal Storage thật).
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> persistMaintenanceOriginalPhoto({
  required String reportId,
  required String fileName,
  required List<int> bytes,
}) async => 'data:image/jpeg;base64,${base64Encode(bytes)}';

Future<String> persistMaintenanceReportPhoto({
  required String reportId,
  required String kind,
  required String fileName,
  required List<int> bytes,
}) async => 'data:image/jpeg;base64,${base64Encode(bytes)}';

Future<String> saveMaintenanceReportPdf({
  required String reportId,
  required List<int> bytes,
  required String fileName,
}) async {
  final data = Uint8List.fromList(bytes);
  final blob = web.Blob(
    <JSUint8Array>[data.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return fileName;
}

Future<Uint8List?> readMaintenanceFile(String storedPath) async {
  final separator = storedPath.indexOf(',');
  if (!storedPath.startsWith('data:') || separator < 0) return null;
  return base64Decode(storedPath.substring(separator + 1));
}

Future<void> deleteMaintenanceReportFiles(String reportId) async {}

Future<void> deleteMaintenanceFile(String storedPath) async {}
