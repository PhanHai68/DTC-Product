import 'dart:typed_data';

/// Lưu/đọc ảnh mẫu của Phân tích mẫu AI. Bản thật cho Android/iOS ở
/// `grain_file_storage_io.dart`; web chưa hỗ trợ (chỉ dùng trên điện thoại).
class GrainFileStorage {
  const GrainFileStorage({Object? rootOverride});

  bool get isSupported => false;

  Future<void> saveImage(String fileName, Uint8List bytes) =>
      throw UnsupportedError(
        'Phân tích mẫu AI chỉ dùng trên ứng dụng Android/iOS.',
      );

  Future<String?> imagePath(String fileName) async => null;

  Future<void> deleteImage(String fileName) async {}
}
