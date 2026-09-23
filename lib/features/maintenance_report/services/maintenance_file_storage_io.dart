import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> _reportDirectory(String reportId, String child) async {
  final root = await getApplicationDocumentsDirectory();
  final directory = Directory(
    p.join(root.path, 'DTCProduct', 'MaintenanceReport', reportId, child),
  );
  if (!await directory.exists()) await directory.create(recursive: true);
  return directory;
}

Future<String> persistMaintenanceOriginalPhoto({
  required String reportId,
  required String fileName,
  required List<int> bytes,
}) async {
  final directory = await _reportDirectory(reportId, 'original');
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> persistMaintenanceReportPhoto({
  required String reportId,
  required String kind,
  required String fileName,
  required List<int> bytes,
}) async {
  final directory = await _reportDirectory(reportId, kind);
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> saveMaintenanceReportPdf({
  required String reportId,
  required List<int> bytes,
  required String fileName,
}) async {
  final directory = await _reportDirectory(reportId, 'pdf');
  final file = File(p.join(directory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Uint8List?> readMaintenanceFile(String storedPath) async {
  final file = File(storedPath);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}

/// Xoá 1 file ảnh cụ thể (dùng khi chụp lại 1 ảnh Before/After ở report còn
/// Draft) — không ảnh hưởng tới các ảnh khác trong report.
Future<void> deleteMaintenanceFile(String storedPath) async {
  final file = File(storedPath);
  if (await file.exists()) await file.delete();
}

/// Xoá toàn bộ thư mục ảnh/PDF của 1 report (gọi khi xoá report) —
/// original/before/after/pdf đều nằm chung dưới thư mục `<reportId>`.
Future<void> deleteMaintenanceReportFiles(String reportId) async {
  final root = await getApplicationDocumentsDirectory();
  final directory = Directory(
    p.join(root.path, 'DTCProduct', 'MaintenanceReport', reportId),
  );
  if (await directory.exists()) await directory.delete(recursive: true);
}
