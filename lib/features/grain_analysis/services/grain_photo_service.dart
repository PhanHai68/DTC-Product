import 'package:image_picker/image_picker.dart';

import 'grain_file_storage.dart';

/// Chụp / chọn ảnh mẫu. Khác các chức năng khác của app: KHÔNG thu nhỏ, KHÔNG
/// nén lại — giữ nguyên độ phân giải gốc của máy (FR-01, NFR-06) vì hạt nhỏ
/// như gạo cần đủ chi tiết để tách và đo.
class GrainPhotoService {
  GrainPhotoService({ImagePicker? picker, GrainFileStorage? storage})
    : _picker = picker ?? ImagePicker(),
      storage = storage ?? const GrainFileStorage();

  final ImagePicker _picker;
  final GrainFileStorage storage;

  /// Trả về tên file đã lưu, null nếu người dùng hủy. Tên file
  /// `<mã phiên>_<thứ tự ảnh>.<đuôi>` để không trùng giữa các phiên.
  Future<String?> pick({
    required ImageSource source,
    required String sessionId,
    required int imageIndex,
  }) async {
    final image = await _picker.pickImage(
      source: source,
      requestFullMetadata: true,
    );
    if (image == null) return null;
    final ext = image.name.contains('.')
        ? image.name.split('.').last.toLowerCase()
        : 'jpg';
    final fileName = '${sessionId}_$imageIndex.$ext';
    await storage.saveImage(fileName, await image.readAsBytes());
    return fileName;
  }

  Future<String?> pathOf(String fileName) => storage.imagePath(fileName);

  Future<void> delete(String fileName) => storage.deleteImage(fileName);
}
