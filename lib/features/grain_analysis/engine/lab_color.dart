import 'dart:math' as math;
import 'dart:typed_data';

/// Chuyển sRGB (D65) sang CIE L*a*b*.
List<double> rgbToLab(int r, int g, int b) {
  double lin(int c) {
    final v = c / 255.0;
    return v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  final rl = lin(r), gl = lin(g), bl = lin(b);
  final x = (rl * 0.4124564 + gl * 0.3575761 + bl * 0.1804375) / 0.95047;
  final y = rl * 0.2126729 + gl * 0.7151522 + bl * 0.0721750;
  final z = (rl * 0.0193339 + gl * 0.1191920 + bl * 0.9503041) / 1.08883;

  double f(double t) => t > 216 / 24389
      ? math.pow(t, 1 / 3).toDouble()
      : (24389 / 27 * t + 16) / 116;

  final fx = f(x), fy = f(y), fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

/// Bảng tra Lab cho 64 mức mỗi kênh (6 bit) — đủ chính xác (sai ΔE < 1,5)
/// để tách nền và lấy màu trung bình, nhanh hơn tính trực tiếp nhiều lần
/// với ảnh 12 MP.
class LabLut {
  LabLut._(this.l, this.a, this.b);

  static LabLut? _instance;

  static LabLut get instance => _instance ??= _build();

  final Float32List l;
  final Float32List a;
  final Float32List b;

  static LabLut _build() {
    const n = 64;
    final l = Float32List(n * n * n);
    final a = Float32List(n * n * n);
    final b = Float32List(n * n * n);
    for (var r = 0; r < n; r++) {
      for (var g = 0; g < n; g++) {
        for (var bl = 0; bl < n; bl++) {
          // Lấy giữa khoảng 4 mức mà ô này đại diện.
          final lab = rgbToLab(r * 4 + 2, g * 4 + 2, bl * 4 + 2);
          final i = (r << 12) | (g << 6) | bl;
          l[i] = lab[0];
          a[i] = lab[1];
          b[i] = lab[2];
        }
      }
    }
    return LabLut._(l, a, b);
  }

  /// Chỉ số trong bảng của màu (r, g, b) 8 bit.
  static int indexOf(int r, int g, int b) =>
      ((r >> 2) << 12) | ((g >> 2) << 6) | (b >> 2);
}
