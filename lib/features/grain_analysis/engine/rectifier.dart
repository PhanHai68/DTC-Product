import 'dart:math' as math;
import 'dart:typed_data';

import 'homography.dart';
import 'raster.dart';
import 'tray_layout.dart';

/// Nắn phối cảnh: tạo ảnh [width] × [height] mà pixel (u, v) lấy từ điểm
/// [frameToImage](u, v) trên ảnh [src] (nội suy song tuyến).
///
/// Quy ước tọa độ: pixel i phủ đoạn [i, i+1), tâm ở i + 0,5.
RgbRaster warpPerspective(
  RgbRaster src,
  Homography frameToImage,
  int width,
  int height,
) {
  final out = RgbRaster.blank(width, height);
  final m = frameToImage.m;
  final s = src.data;
  final sw = src.width, sh = src.height;
  final o = out.data;
  var di = 0;
  for (var v = 0; v < height; v++) {
    final vc = v + 0.5;
    final bx = m[1] * vc + m[2];
    final by = m[4] * vc + m[5];
    final bw = m[7] * vc + m[8];
    for (var u = 0; u < width; u++) {
      final uc = u + 0.5;
      final w = m[6] * uc + bw;
      final fx = (m[0] * uc + bx) / w - 0.5;
      final fy = (m[3] * uc + by) / w - 0.5;
      var x0 = fx.floor(), y0 = fy.floor();
      var tx = fx - x0, ty = fy - y0;
      if (x0 < 0) {
        x0 = 0;
        tx = 0;
      } else if (x0 >= sw - 1) {
        x0 = sw - 2;
        tx = 1;
      }
      if (y0 < 0) {
        y0 = 0;
        ty = 0;
      } else if (y0 >= sh - 1) {
        y0 = sh - 2;
        ty = 1;
      }
      final i00 = (y0 * sw + x0) * 3;
      final i10 = i00 + 3;
      final i01 = i00 + sw * 3;
      final i11 = i01 + 3;
      final w00 = (1 - tx) * (1 - ty);
      final w10 = tx * (1 - ty);
      final w01 = (1 - tx) * ty;
      final w11 = tx * ty;
      for (var c = 0; c < 3; c++) {
        o[di + c] =
            (s[i00 + c] * w00 +
                    s[i10 + c] * w10 +
                    s[i01 + c] * w01 +
                    s[i11 + c] * w11 +
                    0.5)
                .toInt();
      }
      di += 3;
    }
  }
  return out;
}

/// Hệ số cân bằng trắng (r, g, b) từ ô trắng chuẩn trên khay: đưa màu ô
/// trắng về xám trung tính mà giữ nguyên độ sáng. Trả về null nếu ô quá
/// tối (không tin được) hoặc nằm ngoài ảnh.
List<double>? whiteBalanceGains(
  RgbRaster image,
  Homography mmToImage,
  MmRect patch,
) {
  final inner = patch.inflate(-2);
  if (inner.width <= 0 || inner.height <= 0) return null;
  final rs = <double>[], gs = <double>[], bs = <double>[];
  const nx = 40, ny = 12;
  for (var j = 0; j < ny; j++) {
    for (var i = 0; i < nx; i++) {
      final p = mmToImage.apply(
        inner.left + inner.width * (i + 0.5) / nx,
        inner.top + inner.height * (j + 0.5) / ny,
      );
      final x = p[0].floor(), y = p[1].floor();
      if (x < 0 || y < 0 || x >= image.width || y >= image.height) {
        return null;
      }
      final o = (y * image.width + x) * 3;
      rs.add(image.data[o].toDouble());
      gs.add(image.data[o + 1].toDouble());
      bs.add(image.data[o + 2].toDouble());
    }
  }
  final r = median(rs), g = median(gs), b = median(bs);
  if ((r + g + b) / 3 < 60 || r == 0 || g == 0 || b == 0) return null;
  final target = (r + g + b) / 3;
  return [
    (target / r).clamp(0.5, 2.0),
    (target / g).clamp(0.5, 2.0),
    (target / b).clamp(0.5, 2.0),
  ];
}

/// Nhân từng kênh với hệ số [gains] (tại chỗ).
void applyGains(RgbRaster image, List<double> gains) {
  final luts = [
    for (final g in gains)
      Uint8List.fromList([
        for (var v = 0; v < 256; v++) math.min(255, (v * g).round()),
      ]),
  ];
  final d = image.data;
  final lr = luts[0], lg = luts[1], lb = luts[2];
  for (var o = 0; o < d.length; o += 3) {
    d[o] = lr[d[o]];
    d[o + 1] = lg[d[o + 1]];
    d[o + 2] = lb[d[o + 2]];
  }
}
