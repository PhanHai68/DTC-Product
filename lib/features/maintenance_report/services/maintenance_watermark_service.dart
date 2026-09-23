// Ghi watermark "Verified DTC Product" (asset PNG có sẵn — KHÔNG tạo mới)
// trực tiếp vào ảnh Before/After của Verified Camera, cộng thêm 1 dòng thông
// tin nhỏ (BEFORE/AFTER, ngày, giờ, Photo ID). Xử lý bằng package `image`
// (thuần Dart, không cần Flutter engine) và chạy trong isolate nền qua
// `compute()` để tránh giật UI khi ảnh gốc có độ phân giải lớn.

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

@immutable
class MaintenanceWatermarkRequest {
  const MaintenanceWatermarkRequest({
    required this.photoBytes,
    required this.logoBytes,
    required this.kindLabel,
    required this.dateLabel,
    required this.timeLabel,
    required this.photoId,
  });

  final Uint8List photoBytes;
  final Uint8List logoBytes;

  /// 'BEFORE' hoặc 'AFTER'.
  final String kindLabel;
  final String dateLabel;
  final String timeLabel;
  final String photoId;
}

Future<Uint8List> applyMaintenanceWatermark(
  MaintenanceWatermarkRequest request,
) => compute(_applyWatermarkSync, request);

Uint8List _applyWatermarkSync(MaintenanceWatermarkRequest request) {
  img.Image? photo;
  try {
    photo = img.decodeImage(request.photoBytes);
  } catch (_) {
    photo = null;
  }
  if (photo == null) {
    throw StateError('Không đọc được ảnh vừa chụp để ghi watermark.');
  }

  // decodeImage có thể NÉM LỖI (không chỉ trả về null) với dữ liệu hỏng/quá
  // ngắn — logo lỗi không được phép chặn cả luồng chụp ảnh, luôn rơi về ảnh
  // gốc (không watermark) thay vì làm crash Verified Camera.
  img.Image? logo;
  try {
    logo = img.decodeImage(request.logoBytes);
  } catch (_) {
    logo = null;
  }
  if (logo == null) {
    return Uint8List.fromList(img.encodeJpg(photo, quality: 92));
  }

  // Logo chiếm ~18% chiều rộng ảnh, đặt góc dưới-phải — đủ nhận diện nhưng
  // không che quá nhiều nội dung chính của ảnh.
  final margin = (photo.width * 0.03).round().clamp(8, 40);
  final logoWidth = (photo.width * 0.18).round().clamp(56, 420);
  final scaledLogo = img.copyResize(logo, width: logoWidth);
  final logoX = photo.width - scaledLogo.width - margin;
  final logoY = photo.height - scaledLogo.height - margin;
  img.compositeImage(photo, scaledLogo, dstX: logoX, dstY: logoY);

  // Dòng thông tin nhỏ, đặt phía TRÊN logo trong cùng góc, có nền mờ để chữ
  // luôn đọc được bất kể ảnh nền sáng/tối.
  final lines = <String>[
    request.kindLabel,
    request.dateLabel,
    request.timeLabel,
    'Photo ID: ${request.photoId}',
  ];
  final font = img.arial14;
  const lineHeight = 17;
  final textBlockHeight = lines.length * lineHeight + 10;
  final textBlockWidth = (scaledLogo.width).clamp(120, photo.width - margin * 2);
  final textX = photo.width - textBlockWidth - margin;
  final textY = (logoY - textBlockHeight - 6).clamp(margin, photo.height);

  img.fillRect(
    photo,
    x1: textX,
    y1: textY,
    x2: textX + textBlockWidth,
    y2: textY + textBlockHeight,
    color: img.ColorRgba8(0, 0, 0, 130),
    radius: 6,
  );
  var lineY = textY + 6;
  for (final line in lines) {
    img.drawString(
      photo,
      line,
      font: font,
      x: textX + 8,
      y: lineY,
      color: img.ColorRgb8(255, 255, 255),
    );
    lineY += lineHeight;
  }

  return Uint8List.fromList(img.encodeJpg(photo, quality: 92));
}
