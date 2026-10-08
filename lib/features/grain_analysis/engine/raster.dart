import 'dart:math' as math;
import 'dart:typed_data';

/// Ảnh RGB 8 bit, các kênh xếp liền nhau (r, g, b, r, g, b, ...).
/// Dùng thay `img.Image` trong các vòng lặp nặng để truy cập mảng trực tiếp.
class RgbRaster {
  RgbRaster(this.width, this.height, this.data)
    : assert(data.length == width * height * 3);

  RgbRaster.blank(this.width, this.height)
    : data = Uint8List(width * height * 3);

  final int width;
  final int height;
  final Uint8List data;

  int get pixelCount => width * height;

  /// Độ sáng (Rec. 601) 0..255 của pixel thứ [index].
  int lumaAt(int index) {
    final o = index * 3;
    return (data[o] * 77 + data[o + 1] * 150 + data[o + 2] * 29) >> 8;
  }

  /// Thu nhỏ bằng cách lấy trung bình từng ô, để cạnh dài ≤ [maxEdge].
  /// Trả về chính ảnh này nếu đã đủ nhỏ.
  RgbRaster downscaleTo(int maxEdge) {
    final longEdge = math.max(width, height);
    if (longEdge <= maxEdge) return this;
    final scale = maxEdge / longEdge;
    final w = math.max(1, (width * scale).round());
    final h = math.max(1, (height * scale).round());
    final out = RgbRaster.blank(w, h);
    final sx = width / w;
    final sy = height / h;
    for (var y = 0; y < h; y++) {
      final y0 = (y * sy).floor();
      final y1 = math.min(height, ((y + 1) * sy).ceil());
      for (var x = 0; x < w; x++) {
        final x0 = (x * sx).floor();
        final x1 = math.min(width, ((x + 1) * sx).ceil());
        var r = 0, g = 0, b = 0, n = 0;
        for (var yy = y0; yy < y1; yy++) {
          var o = (yy * width + x0) * 3;
          for (var xx = x0; xx < x1; xx++) {
            r += data[o];
            g += data[o + 1];
            b += data[o + 2];
            o += 3;
            n++;
          }
        }
        final d = (y * w + x) * 3;
        out.data[d] = r ~/ n;
        out.data[d + 1] = g ~/ n;
        out.data[d + 2] = b ~/ n;
      }
    }
    return out;
  }

  /// Cắt vùng chữ nhật (đã kẹp trong ảnh).
  RgbRaster crop(int left, int top, int cropWidth, int cropHeight) {
    final out = RgbRaster.blank(cropWidth, cropHeight);
    for (var y = 0; y < cropHeight; y++) {
      final src = ((top + y) * width + left) * 3;
      out.data.setRange(y * cropWidth * 3, (y + 1) * cropWidth * 3, data, src);
    }
    return out;
  }

  /// Ảnh xám 0..255.
  Uint8List toGray() {
    final out = Uint8List(pixelCount);
    for (var i = 0, o = 0; i < out.length; i++, o += 3) {
      out[i] = (data[o] * 77 + data[o + 1] * 150 + data[o + 2] * 29) >> 8;
    }
    return out;
  }
}

/// Hình chữ nhật pixel nguyên, [right]/[bottom] không tính (nửa mở).
class PixelRect {
  const PixelRect(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left;
  int get height => bottom - top;
}

/// Ngưỡng Otsu trên histogram [bins] (trả về chỉ số bin; giá trị > ngưỡng
/// thuộc lớp sáng/xa).
int otsuThreshold(List<int> histogram) {
  var total = 0;
  var sum = 0.0;
  for (var i = 0; i < histogram.length; i++) {
    total += histogram[i];
    sum += i * histogram[i];
  }
  if (total == 0) return histogram.length ~/ 2;
  var sumB = 0.0;
  var weightB = 0;
  var best = 0.0;
  var threshold = 0;
  for (var i = 0; i < histogram.length; i++) {
    weightB += histogram[i];
    if (weightB == 0) continue;
    final weightF = total - weightB;
    if (weightF == 0) break;
    sumB += i * histogram[i];
    final meanB = sumB / weightB;
    final meanF = (sum - sumB) / weightF;
    final between = weightB * weightF * (meanB - meanF) * (meanB - meanF);
    if (between > best) {
      best = between;
      threshold = i;
    }
  }
  return threshold;
}

double median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = List<double>.of(values)..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}
