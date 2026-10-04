import 'package:uuid/uuid.dart';

/// Tạo mã định danh cho Ngân hàng lỗi.
///
/// Mã bản ghi sự cố = mã kỹ sư + "-" + UUID v4, tạo 1 lần và không bao giờ
/// đổi — đây là khóa để gộp file của nhiều kỹ sư ở giai đoạn sau.
abstract final class FaultIds {
  static const _uuid = Uuid();

  /// Mã kỹ sư hợp lệ: 2–10 ký tự chữ in hoa / số, VD "KS012".
  static final engineerCodePattern = RegExp(r'^[A-Z0-9]{2,10}$');

  /// Chuẩn hóa mã kỹ sư người dùng gõ: bỏ khoảng trắng, viết hoa.
  static String normalizeEngineerCode(String input) =>
      input.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  static bool isValidEngineerCode(String code) =>
      engineerCodePattern.hasMatch(code);

  /// Mã kỹ sư tự sinh (người dùng không cần nhập): "KS" + 8 ký tự ngẫu
  /// nhiên, VD "KS3F2B9A1C" — đủ để không trùng khi gộp file nhiều máy.
  static String newEngineerCode() =>
      'KS${_uuid.v4().replaceAll('-', '').substring(0, 8).toUpperCase()}';

  /// "KS012-3f2b...". [engineerCode] phải hợp lệ.
  static String newRecordId(String engineerCode) {
    if (!isValidEngineerCode(engineerCode)) {
      throw ArgumentError.value(
        engineerCode,
        'engineerCode',
        'Mã kỹ sư không hợp lệ',
      );
    }
    return '$engineerCode-${_uuid.v4()}';
  }

  /// Dòng máy do kỹ sư tự thêm cũng mang tiền tố mã kỹ sư để không trùng
  /// khi gộp file.
  static String newMachineModelId(String engineerCode) =>
      newRecordId(engineerCode);

  /// Mã cho bước xử lý / ảnh (thuộc về 1 bản ghi).
  static String newChildId() => _uuid.v4();
}
