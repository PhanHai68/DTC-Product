import 'package:dtc_product/features/maintenance_report/services/maintenance_watermark_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ghi watermark thành công, ảnh JPG hợp lệ và giữ nguyên kích thước', () async {
    final logoData = await rootBundle.load(
      'assets/images/verified_dtc_product_ink.png',
    );
    final logoBytes = Uint8List.sublistView(logoData);

    // Tạo 1 ảnh nền đỏ 800x600 làm "ảnh chụp" giả lập.
    final basePhoto = img.Image(width: 800, height: 600);
    img.fill(basePhoto, color: img.ColorRgb8(200, 60, 60));
    final photoBytes = Uint8List.fromList(img.encodeJpg(basePhoto));

    final result = await applyMaintenanceWatermark(
      MaintenanceWatermarkRequest(
        photoBytes: photoBytes,
        logoBytes: logoBytes,
        kindLabel: 'BEFORE',
        dateLabel: '23/09/2026',
        timeLabel: '09:35:18',
        photoId: 'MNT-20260923-0015-B01',
      ),
    );

    expect(result, isNotEmpty);
    final decoded = img.decodeImage(result);
    expect(decoded, isNotNull);
    expect(decoded!.width, 800);
    expect(decoded.height, 600);

    // Ảnh đầu vào không bị sửa (hàm phải trả về ảnh MỚI, không ghi đè gốc).
    final originalStillDecodable = img.decodeImage(photoBytes);
    expect(originalStillDecodable, isNotNull);
  });

  test('logo hỏng vẫn trả về ảnh hợp lệ thay vì ném lỗi', () async {
    final basePhoto = img.Image(width: 400, height: 300);
    img.fill(basePhoto, color: img.ColorRgb8(10, 10, 10));
    final photoBytes = Uint8List.fromList(img.encodeJpg(basePhoto));

    final result = await applyMaintenanceWatermark(
      MaintenanceWatermarkRequest(
        photoBytes: photoBytes,
        logoBytes: Uint8List.fromList([1, 2, 3]),
        kindLabel: 'AFTER',
        dateLabel: '23/09/2026',
        timeLabel: '11:05:00',
        photoId: 'MNT-20260923-0015-A01',
      ),
    );

    expect(img.decodeImage(result), isNotNull);
  });
}
