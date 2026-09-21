/// Lưu file (PDF/ảnh) của 1 ghi chú vào bộ nhớ ứng dụng, trả về đường dẫn đã
/// lưu. Dùng cho hành động "Lưu file".
Future<String> saveNoteFile({
  required List<int> bytes,
  required String fileName,
}) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ lưu file ghi chú.');
}

/// Ghi file tạm để mở bằng ứng dụng khác, trả về đường dẫn file tạm.
/// Dùng cho hành động "Mở file".
Future<String> cacheNoteFileForOpen({
  required List<int> bytes,
  required String fileName,
}) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ mở file ghi chú.');
}
