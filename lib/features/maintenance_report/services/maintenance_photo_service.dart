// "Verified Camera": chỉ chụp bằng camera (KHÔNG có lựa chọn thư viện ảnh),
// lưu Original Photo bất biến, tính SHA-256, rồi ghi thêm bản Report Photo
// có watermark "Verified DTC Product" (asset sẵn có) để dùng hiển thị/PDF.

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../models/maintenance_photo.dart';
import 'maintenance_file_storage.dart'
    if (dart.library.io) 'maintenance_file_storage_io.dart'
    if (dart.library.js_interop) 'maintenance_file_storage_web.dart';
import 'maintenance_watermark_service.dart';

const _verifiedLogoAsset = 'assets/images/verified_dtc_product_ink.png';

class MaintenancePhotoService {
  MaintenancePhotoService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  Uint8List? _logoBytesCache;

  Future<Uint8List> _loadLogoBytes() async {
    final cached = _logoBytesCache;
    if (cached != null) return cached;
    final data = await rootBundle.load(_verifiedLogoAsset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    _logoBytesCache = bytes;
    return bytes;
  }

  /// Chụp 1 ảnh Before/After bằng Verified Camera. [photoId] phải được sinh
  /// sẵn từ repository (theo Session ID) TRƯỚC khi gọi hàm này. Trả về `null`
  /// nếu người dùng huỷ chụp (không tạo ảnh, không đổi gì trong DB).
  Future<MaintenancePhoto?> captureVerifiedPhoto({
    required String reportId,
    required String photoId,
    required MaintenancePhotoKind kind,
    required int sequence,
    String? itemId,
  }) async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 90,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    final extension = p.extension(image.path).isEmpty
        ? '.jpg'
        : p.extension(image.path);

    final originalPath = await persistMaintenanceOriginalPhoto(
      reportId: reportId,
      fileName: '$photoId$extension',
      bytes: bytes,
    );

    final now = DateTime.now();
    final watermarked = await applyMaintenanceWatermark(
      MaintenanceWatermarkRequest(
        photoBytes: bytes,
        logoBytes: await _loadLogoBytes(),
        kindLabel: kind == MaintenancePhotoKind.before ? 'TRUOC' : 'SAU',
        dateLabel: DateFormat('dd/MM/yyyy').format(now),
        timeLabel: DateFormat('HH:mm:ss').format(now),
        photoId: photoId,
      ),
    );
    final reportPath = await persistMaintenanceReportPhoto(
      reportId: reportId,
      kind: kind.name,
      fileName: '$photoId.jpg',
      bytes: watermarked,
    );

    return MaintenancePhoto(
      id: photoId,
      reportId: reportId,
      itemId: itemId,
      kind: kind,
      sequence: sequence,
      originalPath: originalPath,
      reportPath: reportPath,
      sha256: hash,
      verified: true,
      capturedAt: now,
    );
  }

  /// Đọc lại Original Photo trên đĩa và so sánh SHA-256 với giá trị đã lưu.
  /// Trả về `false` nếu file không còn tồn tại hoặc hash không khớp.
  Future<bool> verifyOriginal(MaintenancePhoto photo) async {
    final bytes = await readMaintenanceFile(photo.originalPath);
    if (bytes == null) return false;
    return sha256.convert(bytes).toString() == photo.sha256;
  }
}
