import 'dart:typed_data';

/// Lưu/đọc ảnh của Ngân hàng lỗi. Bản thật cho Android/iOS ở
/// `fault_file_storage_io.dart`; nền tảng khác (web) chưa hỗ trợ.
class FaultFileStorage {
  /// [rootOverride] chỉ có ý nghĩa ở bản io (thư mục tạm trong test); giữ
  /// cùng chữ ký để code gọi chung 1 kiểu.
  const FaultFileStorage({Object? rootOverride});

  bool get isSupported => false;

  Future<void> savePhoto(String fileName, Uint8List bytes) =>
      throw UnsupportedError(
        'Ngân hàng lỗi chưa hỗ trợ lưu ảnh trên nền tảng này.',
      );

  Future<String?> photoPath(String fileName) async => null;

  Future<Uint8List?> readPhoto(String fileName) async => null;

  Future<void> deletePhoto(String fileName) async {}
}
