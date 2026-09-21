import '../models/stored_file.dart';

/// Kết quả quét bộ nhớ: danh sách file đã lưu (PDF/ảnh/3D/khác) + dung lượng
/// cache hiện tại.
class StorageScanResult {
  const StorageScanResult({required this.files, required this.cacheBytes});

  final List<StoredFile> files;
  final int cacheBytes;
}

/// Quét toàn bộ Documents/DTCProduct (dữ liệu cá nhân/offline đã lưu) và thư
/// mục cache tạm, KHÔNG bao giờ động tới cơ sở dữ liệu SQLite (nằm ở thư mục
/// databases riêng do hệ điều hành quản lý).
Future<StorageScanResult> scanStorage() {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ quét bộ nhớ.');
}

/// Xóa toàn bộ nội dung thư mục cache tạm, trả về số byte đã giải phóng.
/// KHÔNG bao giờ đụng tới Documents/DTCProduct (ghi chú, dự án, lưu mẫu...).
Future<int> clearAppCache() {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ xóa cache.');
}

/// Xóa 1 file đã lưu. Chỉ cho phép xóa file nằm trong Documents/DTCProduct để
/// tránh xóa nhầm dữ liệu ngoài phạm vi ứng dụng.
Future<bool> deleteStoredFile(String filePath) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ xóa file.');
}

/// Đổi tên file (giữ nguyên phần mở rộng), trả về đường dẫn mới nếu thành
/// công.
Future<String?> renameStoredFile(String filePath, String newBaseName) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ đổi tên file.');
}

Future<void> shareStoredFile(StoredFile file) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ chia sẻ file.');
}

Future<void> openStoredFileExternally(String filePath) {
  throw UnsupportedError('Nền tảng này chưa hỗ trợ mở file.');
}
