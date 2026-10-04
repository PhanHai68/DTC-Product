import 'package:image_picker/image_picker.dart';

import '../models/fault_record.dart';
import '../utils/fault_ids.dart';
import 'fault_file_storage.dart';

/// Chụp / chọn ảnh, nén ngay khi lấy về rồi lưu thành file trong thư mục của
/// app. Không dùng mạng.
class FaultPhotoService {
  FaultPhotoService({ImagePicker? picker, FaultFileStorage? storage})
    : _picker = picker ?? ImagePicker(),
      storage = storage ?? const FaultFileStorage();

  /// Cạnh dài tối đa sau khi nén.
  static const maxEdge = 1600.0;
  static const jpegQuality = 85;

  final ImagePicker _picker;
  final FaultFileStorage storage;

  /// Trả về null nếu người dùng hủy. [recordId] để đặt tên file duy nhất
  /// toàn hệ thống: `<mã bản ghi>_<uuid>.jpg` — gộp ảnh của nhiều kỹ sư
  /// không bị trùng tên.
  Future<FaultAttachment?> pick({
    required ImageSource source,
    required String recordId,
    String? stepId,
  }) async {
    // image_picker thu nhỏ + nén JPEG bằng code native của Android/iOS.
    final image = await _picker.pickImage(
      source: source,
      maxWidth: maxEdge,
      maxHeight: maxEdge,
      imageQuality: jpegQuality,
      requestFullMetadata: false,
    );
    if (image == null) return null;
    final id = FaultIds.newChildId();
    final fileName = '${recordId}_$id.jpg';
    await storage.savePhoto(fileName, await image.readAsBytes());
    return FaultAttachment(id: id, fileName: fileName, stepId: stepId);
  }

  Future<String?> pathOf(FaultAttachment photo) =>
      storage.photoPath(photo.fileName);

  Future<void> delete(FaultAttachment photo) =>
      storage.deletePhoto(photo.fileName);
}
