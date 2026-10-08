import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'raster.dart';

/// Giải mã ảnh (JPEG/PNG...) ở độ phân giải gốc, xoay theo EXIF rồi đưa về
/// [RgbRaster]. App và script giai đoạn 0 dùng chung hàm này nên số đếm
/// trên cùng một file ảnh luôn trùng nhau.
RgbRaster decodeImageToRaster(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Không đọc được file ảnh.');
  }
  return rasterFromImage(img.bakeOrientation(decoded));
}

RgbRaster rasterFromImage(img.Image image) {
  final rgb = image.format == img.Format.uint8
      ? image
      : image.convert(format: img.Format.uint8);
  final bytes = rgb.getBytes(order: img.ChannelOrder.rgb);
  return RgbRaster(rgb.width, rgb.height, bytes);
}
