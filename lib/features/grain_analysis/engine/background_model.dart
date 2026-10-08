import 'dart:math' as math;
import 'dart:typed_data';

import 'lab_color.dart';
import 'raster.dart';

/// Màu nền thay đổi theo vị trí (giấy/khay sáng không đều, bóng mờ, góc
/// tối). Ước trên lưới ô: mỗi ô lấy màu xuất hiện nhiều nhất (hạt thường
/// rải thưa và nhiều màu, nền đồng màu nên luôn là đỉnh), loại ô lệch quá xa
/// màu nền chung (ô bị hạt phủ kín), lấp ô thiếu từ ô bên cạnh, làm mượt,
/// rồi nội suy song tuyến cho từng pixel.
class BackgroundModel {
  BackgroundModel._(
    this.cols,
    this.rows,
    this.cellW,
    this.cellH,
    this.l,
    this.a,
    this.b,
    this.valid,
  );

  /// Số ô theo ngang/dọc và kích thước ô (pixel của ảnh dùng để ước).
  final int cols;
  final int rows;
  final double cellW;
  final double cellH;
  final Float32List l;
  final Float32List a;
  final Float32List b;

  /// Ô ước được trực tiếp (không phải lấp từ ô bên cạnh).
  final Uint8List valid;

  /// Ước nền trên ảnh [image] (thường là ảnh thu nhỏ). [reference] là màu
  /// nền chung; ô nào lệch quá [maxDeviation] (ΔE) bị coi là bị hạt che.
  static BackgroundModel estimate(
    RgbRaster image, {
    required double cellPx,
    required List<double> reference,
    required double maxDeviation,
    required double minSupport,
  }) {
    final cols = math.max(1, (image.width / cellPx).round());
    final rows = math.max(1, (image.height / cellPx).round());
    final cw = image.width / cols, ch = image.height / rows;
    final n = cols * rows;
    final l = Float32List(n), a = Float32List(n), b = Float32List(n);
    final valid = Uint8List(n);
    final lut = LabLut.instance;
    final dev2 = maxDeviation * maxDeviation;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final x0 = (c * cw).floor(),
            x1 = math.min(image.width, ((c + 1) * cw).ceil());
        final y0 = (r * ch).floor(),
            y1 = math.min(image.height, ((r + 1) * ch).ceil());
        final step = math.max(1, ((x1 - x0) * (y1 - y0) / 3000).floor());
        final counts = <int, int>{};
        final idxs = <int>[];
        var k = 0;
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++, k++) {
            if (k % step != 0) continue;
            final o = (y * image.width + x) * 3;
            final idx = LabLut.indexOf(
              image.data[o],
              image.data[o + 1],
              image.data[o + 2],
            );
            idxs.add(idx);
            final key = _bin(lut.l[idx], lut.a[idx], lut.b[idx]);
            counts[key] = (counts[key] ?? 0) + 1;
          }
        }
        if (idxs.isEmpty) continue;
        var bestKey = 0, best = -1;
        counts.forEach((key, v) {
          if (v > best) {
            best = v;
            bestKey = key;
          }
        });
        final center = _center(bestKey);
        final ls = <double>[], as = <double>[], bs = <double>[];
        for (final idx in idxs) {
          final dl = lut.l[idx] - center[0];
          final da = lut.a[idx] - center[1];
          final db = lut.b[idx] - center[2];
          if (dl * dl + da * da + db * db < 49) {
            ls.add(lut.l[idx]);
            as.add(lut.a[idx]);
            bs.add(lut.b[idx]);
          }
        }
        final i = r * cols + c;
        if (ls.length < minSupport * idxs.length) continue;
        l[i] = median(ls);
        a[i] = median(as);
        b[i] = median(bs);
        final dl = l[i] - reference[0];
        final da = a[i] - reference[1];
        final db = b[i] - reference[2];
        if (dl * dl + da * da + db * db <= dev2) valid[i] = 1;
      }
    }

    // Không ô nào hợp lệ → dùng màu nền chung cho cả ảnh.
    if (!valid.contains(1)) {
      for (var i = 0; i < n; i++) {
        l[i] = reference[0];
        a[i] = reference[1];
        b[i] = reference[2];
      }
      return BackgroundModel._(cols, rows, cw, ch, l, a, b, Uint8List(n));
    }

    // Lấp ô thiếu bằng trung bình các ô đã có bên cạnh, lan dần.
    final filled = Uint8List.fromList(valid);
    var pending = filled.where((v) => v == 0).length;
    while (pending > 0) {
      final next = Uint8List.fromList(filled);
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final i = r * cols + c;
          if (filled[i] == 1) continue;
          var sl = 0.0, sa = 0.0, sb = 0.0, m = 0;
          for (var dr = -1; dr <= 1; dr++) {
            for (var dc = -1; dc <= 1; dc++) {
              final rr = r + dr, cc = c + dc;
              if (rr < 0 || cc < 0 || rr >= rows || cc >= cols) continue;
              final j = rr * cols + cc;
              if (filled[j] == 0) continue;
              sl += l[j];
              sa += a[j];
              sb += b[j];
              m++;
            }
          }
          if (m == 0) continue;
          l[i] = sl / m;
          a[i] = sa / m;
          b[i] = sb / m;
          next[i] = 1;
          pending--;
        }
      }
      filled.setAll(0, next);
    }

    // Làm mượt bằng trung vị 3 × 3 để bỏ ô lẻ bị hạt làm lệch.
    Float32List smooth(Float32List src) {
      final out = Float32List(n);
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final values = <double>[];
          for (var dr = -1; dr <= 1; dr++) {
            for (var dc = -1; dc <= 1; dc++) {
              final rr = r + dr, cc = c + dc;
              if (rr < 0 || cc < 0 || rr >= rows || cc >= cols) continue;
              values.add(src[rr * cols + cc]);
            }
          }
          out[r * cols + c] = median(values);
        }
      }
      return out;
    }

    return BackgroundModel._(
      cols,
      rows,
      cw,
      ch,
      smooth(l),
      smooth(a),
      smooth(b),
      valid,
    );
  }

  static int _bin(double l, double a, double b) =>
      (l / 4).floor().clamp(0, 25) * 10000 +
      ((a + 128) / 4).floor().clamp(0, 63) * 100 +
      ((b + 128) / 4).floor().clamp(0, 63);

  static List<double> _center(int key) => [
    (key ~/ 10000) * 4 + 2.0,
    ((key ~/ 100) % 100) * 4 - 128 + 2.0,
    (key % 100) * 4 - 128 + 2.0,
  ];

  /// Màu nền nội suy cho cả một hàng pixel của ảnh kích thước [width] ×
  /// [height] (có thể lớn hơn ảnh dùng để ước — tự đổi tỉ lệ).
  void fillRow(
    int y,
    int width,
    int height,
    double modelWidth,
    double modelHeight,
    Float32List outL,
    Float32List outA,
    Float32List outB,
  ) {
    final sy = modelHeight / height, sx = modelWidth / width;
    final gy = ((y + 0.5) * sy / cellH - 0.5).clamp(0.0, rows - 1.0);
    final r0 = gy.floor(), r1 = math.min(rows - 1, r0 + 1);
    final ty = gy - r0;
    for (var x = 0; x < width; x++) {
      final gx = ((x + 0.5) * sx / cellW - 0.5).clamp(0.0, cols - 1.0);
      final c0 = gx.floor(), c1 = math.min(cols - 1, c0 + 1);
      final tx = gx - c0;
      final i00 = r0 * cols + c0, i01 = r0 * cols + c1;
      final i10 = r1 * cols + c0, i11 = r1 * cols + c1;
      final w00 = (1 - tx) * (1 - ty), w01 = tx * (1 - ty);
      final w10 = (1 - tx) * ty, w11 = tx * ty;
      outL[x] = l[i00] * w00 + l[i01] * w01 + l[i10] * w10 + l[i11] * w11;
      outA[x] = a[i00] * w00 + a[i01] * w01 + a[i10] * w10 + a[i11] * w11;
      outB[x] = b[i00] * w00 + b[i01] * w01 + b[i10] * w10 + b[i11] * w11;
    }
  }

  /// Chênh độ sáng nền: (max − min) / max của L* trên các ô ước trực tiếp.
  double unevenness() {
    var maxL = -1.0, minL = 1e9;
    for (var i = 0; i < valid.length; i++) {
      if (valid[i] == 0) continue;
      maxL = math.max(maxL, l[i]);
      minL = math.min(minL, l[i]);
    }
    if (maxL <= 0) return 0;
    return (maxL - minL) / maxL;
  }
}
