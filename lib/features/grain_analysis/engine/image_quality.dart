import 'dart:math' as math;
import 'dart:typed_data';

import 'lab_color.dart';
import 'raster.dart';

/// Sáu phép kiểm tra chất lượng ảnh (mục 9 tài liệu yêu cầu).
enum QualityIssue {
  markers(
    'Mốc khay',
    'Không thấy đủ bốn góc khay. Lùi máy ra để thấy cả khay; khay '
        'AnySort phải khác màu hẳn mặt bàn.',
  ),
  tilt('Góc chụp', 'Máy đang nghiêng. Giữ máy song song với khay.'),
  blur('Độ nét', 'Ảnh bị mờ. Giữ chắc máy và chụp lại.'),
  lighting(
    'Ánh sáng',
    'Ánh sáng không đều hoặc bị bóng đổ. Đổi vị trí hoặc che nguồn sáng chói.',
  ),
  resolution(
    'Độ phân giải',
    'Ảnh chưa đủ chi tiết cho nguyên liệu này. Đưa máy lại gần hoặc chia mẫu '
        'làm hai lần chụp.',
  ),
  overlap('Hạt chồng nhau', 'Hạt đang chồng lên nhau. Rải lại thành một lớp.');

  const QualityIssue(this.label, this.message);

  final String label;
  final String message;

  static QualityIssue? byName(String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}

/// Phương sai Laplacian của ảnh xám — càng nhỏ càng mờ.
double laplacianVariance(Uint8List gray, int width, int height) {
  if (width < 3 || height < 3) return 0;
  var sum = 0.0, sumSq = 0.0;
  var n = 0;
  for (var y = 1; y < height - 1; y++) {
    final row = y * width;
    for (var x = 1; x < width - 1; x++) {
      final i = row + x;
      final v =
          4 * gray[i] -
          gray[i - 1] -
          gray[i + 1] -
          gray[i - width] -
          gray[i + width];
      sum += v;
      sumSq += v * v;
      n++;
    }
  }
  final mean = sum / n;
  return sumSq / n - mean * mean;
}

/// Màu nền Lab = trung vị từng kênh trên dải viền rộng [band] pixel.
List<double> estimateBackgroundLab(RgbRaster image, int band) {
  final lut = LabLut.instance;
  final ls = <double>[], as = <double>[], bs = <double>[];
  final b = band.clamp(1, math.min(image.width, image.height) ~/ 2);
  final step = math.max(1, (image.width + image.height) ~/ 800);
  void sample(int x, int y) {
    final o = (y * image.width + x) * 3;
    final idx = LabLut.indexOf(
      image.data[o],
      image.data[o + 1],
      image.data[o + 2],
    );
    ls.add(lut.l[idx]);
    as.add(lut.a[idx]);
    bs.add(lut.b[idx]);
  }

  for (var y = 0; y < image.height; y += step) {
    final inBand = y < b || y >= image.height - b;
    if (inBand) {
      for (var x = 0; x < image.width; x += step) {
        sample(x, y);
      }
    } else {
      for (var x = 0; x < b; x += step) {
        sample(x, y);
      }
      for (var x = image.width - b; x < image.width; x += step) {
        sample(x, y);
      }
    }
  }
  return [median(ls), median(as), median(bs)];
}

/// Màu nền Lab khi không có mốc khay (không biết đâu là viền khay): màu
/// chiếm nhiều pixel nhất. Viền ảnh lúc đó có thể là mặt bàn, mép giấy.
List<double> estimateDominantLab(RgbRaster image) {
  final lut = LabLut.instance;
  // Lưới thô: L 0..100, a/b −128..127, mỗi ô 5 đơn vị.
  int bin(double v, double min) => ((v - min) / 5).floor().clamp(0, 51);
  final counts = <int, int>{};
  final step = math.max(1, image.pixelCount ~/ 200000);
  for (var i = 0; i < image.pixelCount; i += step) {
    final o = i * 3;
    final idx = LabLut.indexOf(
      image.data[o],
      image.data[o + 1],
      image.data[o + 2],
    );
    final key =
        bin(lut.l[idx], 0) * 10000 +
        bin(lut.a[idx], -128) * 100 +
        bin(lut.b[idx], -128);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  var bestKey = 0, best = -1;
  counts.forEach((key, n) {
    if (n > best) {
      best = n;
      bestKey = key;
    }
  });
  final center = [
    (bestKey ~/ 10000) * 5 + 2.5,
    ((bestKey ~/ 100) % 100) * 5 - 128 + 2.5,
    (bestKey % 100) * 5 - 128 + 2.5,
  ];
  // Tinh chỉnh: trung vị các pixel gần ô đó.
  final ls = <double>[], as = <double>[], bs = <double>[];
  for (var i = 0; i < image.pixelCount; i += step) {
    final o = i * 3;
    final idx = LabLut.indexOf(
      image.data[o],
      image.data[o + 1],
      image.data[o + 2],
    );
    final dl = lut.l[idx] - center[0];
    final da = lut.a[idx] - center[1];
    final db = lut.b[idx] - center[2];
    if (dl * dl + da * da + db * db < 100) {
      ls.add(lut.l[idx]);
      as.add(lut.a[idx]);
      bs.add(lut.b[idx]);
    }
  }
  if (ls.isEmpty) return center;
  return [median(ls), median(as), median(bs)];
}

/// Tỉ lệ pixel cháy sáng (có kênh ≥ [level]).
double highlightFraction(RgbRaster image, int level) {
  var count = 0;
  final d = image.data;
  for (var o = 0; o < d.length; o += 3) {
    if (d[o] >= level || d[o + 1] >= level || d[o + 2] >= level) count++;
  }
  return image.pixelCount == 0 ? 0 : count / image.pixelCount;
}
