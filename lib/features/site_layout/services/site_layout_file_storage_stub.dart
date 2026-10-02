import 'dart:typed_data';

Future<String> saveSiteLayoutPhoto({
  required String projectId,
  required String fileName,
  required Uint8List bytes,
  bool thumbnail = false,
}) => throw UnsupportedError('Nền tảng không hỗ trợ lưu ảnh khảo sát.');

Future<String> saveSiteLayoutExport({
  required String projectId,
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) => throw UnsupportedError('Nền tảng không hỗ trợ xuất tệp.');

Future<Uint8List?> readSiteLayoutFile(String path) async => null;

Future<void> deleteSiteLayoutFile(String path) async {}
