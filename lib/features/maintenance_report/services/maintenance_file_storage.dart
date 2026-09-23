import 'dart:typed_data';

Future<String> persistMaintenanceOriginalPhoto({
  required String reportId,
  required String fileName,
  required List<int> bytes,
}) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ lưu ảnh gốc bảo trì.');
}

Future<String> persistMaintenanceReportPhoto({
  required String reportId,
  required String kind,
  required String fileName,
  required List<int> bytes,
}) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ lưu ảnh báo cáo bảo trì.');
}

Future<String> saveMaintenanceReportPdf({
  required String reportId,
  required List<int> bytes,
  required String fileName,
}) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ lưu PDF báo cáo bảo trì.');
}

Future<Uint8List?> readMaintenanceFile(String storedPath) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ đọc file báo cáo bảo trì.');
}

Future<void> deleteMaintenanceReportFiles(String reportId) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ xoá file báo cáo bảo trì.');
}

Future<void> deleteMaintenanceFile(String storedPath) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ xoá file báo cáo bảo trì.');
}
