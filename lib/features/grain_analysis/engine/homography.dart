import 'dart:math' as math;

/// Phép biến đổi phối cảnh 3×3 (hàng trước), ánh xạ (x, y) → (x', y').
class Homography {
  const Homography(this.m);

  /// Ma trận 9 phần tử h00..h22, h22 thường = 1.
  final List<double> m;

  static const identity = Homography([1, 0, 0, 0, 1, 0, 0, 0, 1]);

  /// Tịnh tiến rồi co giãn: (x, y) → (x·scale + dx, y·scale + dy).
  factory Homography.scaleTranslate(double scale, double dx, double dy) =>
      Homography([scale, 0, dx, 0, scale, dy, 0, 0, 1]);

  /// Tìm phép biến đổi đưa 4 điểm [from] về 4 điểm [to]. Mỗi điểm là
  /// [x, y]. Trả về null nếu 4 điểm suy biến (thẳng hàng).
  static Homography? fromPoints(
    List<List<double>> from,
    List<List<double>> to,
  ) {
    assert(from.length == 4 && to.length == 4);
    // Hệ 8 phương trình 8 ẩn (h22 = 1).
    final a = List.generate(8, (_) => List<double>.filled(9, 0));
    for (var i = 0; i < 4; i++) {
      final x = from[i][0], y = from[i][1];
      final u = to[i][0], v = to[i][1];
      a[2 * i]
        ..[0] = x
        ..[1] = y
        ..[2] = 1
        ..[6] = -u * x
        ..[7] = -u * y
        ..[8] = u;
      a[2 * i + 1]
        ..[3] = x
        ..[4] = y
        ..[5] = 1
        ..[6] = -v * x
        ..[7] = -v * y
        ..[8] = v;
    }
    final h = _solve(a);
    if (h == null) return null;
    return Homography([...h, 1]);
  }

  /// Khử Gauss có chọn phần tử chính trên ma trận mở rộng n × (n+1).
  static List<double>? _solve(List<List<double>> a) {
    final n = a.length;
    for (var col = 0; col < n; col++) {
      var pivot = col;
      for (var r = col + 1; r < n; r++) {
        if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
      }
      if (a[pivot][col].abs() < 1e-12) return null;
      final tmp = a[col];
      a[col] = a[pivot];
      a[pivot] = tmp;
      for (var r = 0; r < n; r++) {
        if (r == col) continue;
        final factor = a[r][col] / a[col][col];
        if (factor == 0) continue;
        for (var c = col; c <= n; c++) {
          a[r][c] -= factor * a[col][c];
        }
      }
    }
    return [for (var i = 0; i < n; i++) a[i][n] / a[i][i]];
  }

  List<double> apply(double x, double y) {
    final w = m[6] * x + m[7] * y + m[8];
    return [(m[0] * x + m[1] * y + m[2]) / w, (m[3] * x + m[4] * y + m[5]) / w];
  }

  /// Ghép: kết quả = this ∘ other (áp [other] trước).
  Homography compose(Homography other) {
    final a = m, b = other.m;
    final r = List<double>.filled(9, 0);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        var s = 0.0;
        for (var k = 0; k < 3; k++) {
          s += a[i * 3 + k] * b[k * 3 + j];
        }
        r[i * 3 + j] = s;
      }
    }
    return Homography(r);
  }

  Homography? inverse() {
    final a = m;
    final det =
        a[0] * (a[4] * a[8] - a[5] * a[7]) -
        a[1] * (a[3] * a[8] - a[5] * a[6]) +
        a[2] * (a[3] * a[7] - a[4] * a[6]);
    if (det.abs() < 1e-15) return null;
    final inv = [
      (a[4] * a[8] - a[5] * a[7]) / det,
      (a[2] * a[7] - a[1] * a[8]) / det,
      (a[1] * a[5] - a[2] * a[4]) / det,
      (a[5] * a[6] - a[3] * a[8]) / det,
      (a[0] * a[8] - a[2] * a[6]) / det,
      (a[2] * a[3] - a[0] * a[5]) / det,
      (a[3] * a[7] - a[4] * a[6]) / det,
      (a[1] * a[6] - a[0] * a[7]) / det,
      (a[0] * a[4] - a[1] * a[3]) / det,
    ];
    return Homography(inv);
  }

  /// Góc (độ) giữa pháp tuyến mặt khay và trục quang của máy ảnh, từ phép
  /// biến đổi mm-trên-khay → pixel-ảnh. Giả định tâm ảnh là tâm quang học
  /// và tiêu cự [focalPx] (ước lượng; chỉ cần đủ để phát hiện chụp nghiêng).
  double tiltDegrees({
    required double focalPx,
    required double centerX,
    required double centerY,
  }) {
    // M = K⁻¹·H, cột 1 và 2 tỉ lệ với hai trục quay r1, r2.
    List<double> col(int j) => [
      (m[j] - centerX * m[6 + j]) / focalPx,
      (m[3 + j] - centerY * m[6 + j]) / focalPx,
      m[6 + j],
    ];
    final c1 = col(0), c2 = col(1);
    double norm(List<double> v) =>
        math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    final n1 = norm(c1), n2 = norm(c2);
    if (n1 == 0 || n2 == 0) return 90;
    final r1 = [c1[0] / n1, c1[1] / n1, c1[2] / n1];
    final r2 = [c2[0] / n2, c2[1] / n2, c2[2] / n2];
    final r3 = [
      r1[1] * r2[2] - r1[2] * r2[1],
      r1[2] * r2[0] - r1[0] * r2[2],
      r1[0] * r2[1] - r1[1] * r2[0],
    ];
    final n3 = norm(r3);
    if (n3 == 0) return 90;
    final cosTilt = (r3[2] / n3).abs().clamp(0.0, 1.0);
    return math.acos(cosTilt) * 180 / math.pi;
  }

  List<double> toList() => List.of(m);
}
