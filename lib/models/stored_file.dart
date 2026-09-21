/// Phân loại file mà DTC Product đã lưu trên thiết bị, dùng để nhóm và lọc
/// trong màn "Bộ nhớ & Tệp đã lưu".
enum StoredFileCategory {
  pdf('PDF', 'application/pdf'),
  image('Hình ảnh', 'image/*'),
  model3d('Mô hình 3D', 'model/gltf-binary'),
  other('Khác', '*/*');

  const StoredFileCategory(this.label, this.mimeType);

  final String label;
  final String mimeType;

  static StoredFileCategory fromExtension(String extension) {
    final ext = extension.toLowerCase();
    if (ext == '.pdf') return StoredFileCategory.pdf;
    if (const ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'].contains(ext)) {
      return StoredFileCategory.image;
    }
    if (const ['.glb', '.gltf'].contains(ext)) return StoredFileCategory.model3d;
    return StoredFileCategory.other;
  }
}

/// Một file cụ thể mà app đã lưu trong bộ nhớ riêng (Documents/DTCProduct),
/// KHÔNG bao gồm cache hay dữ liệu SQLite (đã ở thư mục database riêng).
class StoredFile {
  const StoredFile({
    required this.filePath,
    required this.fileName,
    required this.extension,
    required this.category,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.featureLabel,
  });

  final String filePath;
  final String fileName;
  final String extension;
  final StoredFileCategory category;
  final int sizeBytes;
  final DateTime modifiedAt;

  /// Tên chức năng đã tạo ra file này (suy ra từ thư mục con), ví dụ
  /// "Ghi chú & Nhắc hẹn", "Lưu mẫu", "Theo dõi dự án".
  final String featureLabel;
}

/// Tổng hợp dung lượng theo danh mục, dùng cho biểu đồ/tóm tắt ở đầu màn hình.
class StorageUsageSummary {
  const StorageUsageSummary({
    required this.pdfBytes,
    required this.imageBytes,
    required this.model3dBytes,
    required this.otherBytes,
    required this.cacheBytes,
    required this.fileCount,
  });

  final int pdfBytes;
  final int imageBytes;
  final int model3dBytes;
  final int otherBytes;
  final int cacheBytes;
  final int fileCount;

  int get savedFilesBytes => pdfBytes + imageBytes + model3dBytes + otherBytes;
  int get totalBytes => savedFilesBytes + cacheBytes;

  int bytesFor(StoredFileCategory category) => switch (category) {
    StoredFileCategory.pdf => pdfBytes,
    StoredFileCategory.image => imageBytes,
    StoredFileCategory.model3d => model3dBytes,
    StoredFileCategory.other => otherBytes,
  };
}

/// Định dạng số byte thành chuỗi dễ đọc (VD: "12,3 MB").
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final formatted = unitIndex == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '${formatted.replaceAll('.', ',')} ${units[unitIndex]}';
}
