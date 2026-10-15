import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Ảnh hiển thị dạng ô thu nhỏ ([BoxFit.cover]) chỉ cần giải mã vừa ô, không
/// cần độ phân giải gốc: một ảnh 2000–2400 px giải mã đầy đủ tốn khoảng
/// 15–20 MB RAM, lưới vài chục ảnh dễ làm máy yếu giật hoặc tự thoát.
///
/// Các chế độ khác (ví dụ [BoxFit.contain] trong màn xem phóng to) giữ
/// nguyên ảnh gốc để phóng to không bị mờ.
ImageProvider thumbnailImageProvider(
  ImageProvider provider, {
  required BoxConstraints constraints,
  required double devicePixelRatio,
  required BoxFit fit,
}) {
  if (fit != BoxFit.cover) return provider;
  final width = constraints.hasBoundedWidth ? constraints.maxWidth : null;
  final height = constraints.hasBoundedHeight ? constraints.maxHeight : null;
  final longest = [width, height].whereType<double>().fold<double>(0, math.max);
  if (longest <= 0) return provider;
  // Ảnh lấp đầy ô theo cạnh ngắn, nên cho cạnh dài của ảnh gấp đôi cạnh dài
  // của ô: đủ nét với ảnh tỉ lệ đến 2:1 mà vẫn nhỏ hơn nhiều so với ảnh gốc.
  final side = (longest * devicePixelRatio * 2).ceil();
  return ResizeImage(
    provider,
    width: side,
    height: side,
    policy: ResizeImagePolicy.fit,
  );
}
