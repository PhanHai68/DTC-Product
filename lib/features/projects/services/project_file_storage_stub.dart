import 'dart:typed_data';

Future<String> persistProjectFile({
  required String projectId,
  required String sourcePath,
  required String fileName,
  List<int>? bytes,
}) => throw UnsupportedError('Nền tảng này chưa hỗ trợ lưu tệp dự án.');

Future<Uint8List?> readProjectFile(String storedPath) =>
    throw UnsupportedError('Nền tảng này chưa hỗ trợ đọc tệp dự án.');

Future<String> saveProjectReport({
  required String projectId,
  required List<int> bytes,
  required String fileName,
}) => throw UnsupportedError('Nền tảng này chưa hỗ trợ lưu báo cáo.');
