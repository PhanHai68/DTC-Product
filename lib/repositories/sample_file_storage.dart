import 'dart:typed_data';

Future<String> persistSamplePhoto({
  required String sourcePath,
  required String fileName,
  List<int>? bytes,
}) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ lưu ảnh mẫu.');
}

Future<Uint8List?> readSamplePhoto(String storedPath) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ đọc ảnh mẫu.');
}

Future<String> saveSamplePdf({
  required List<int> bytes,
  required String fileName,
}) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ lưu PDF.');
}
