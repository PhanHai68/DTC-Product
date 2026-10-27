import 'dart:math' as math;

/// Đường kính trong ống khí nén tối thiểu (mm) — dùng chung cho màn "Tính
/// toán đường ống khí nén" và "Tính toán phòng lắp đặt".
///
/// d = ((1,6 · (V/60)^1,85 · L · 10^8) / (Δp · P_max))^(1/5)
///
/// [flow] lưu lượng (m³/phút), [lengthM] chiều dài ống (m), [dropBar] độ sụt
/// áp cho phép (bar), [maxPressureBar] áp suất làm việc (bar).
double airPipeDiameterMm({
  required double flow,
  double lengthM = airPipeDefaultLengthM,
  double dropBar = airPipeDefaultDropBar,
  double maxPressureBar = airPipeDefaultPressureBar,
}) {
  final vS = flow / 60.0;
  final part1 = 1.6 * math.pow(vS, 1.85) * lengthM * math.pow(10, 8);
  final part2 = dropBar * maxPressureBar;
  return math.pow(part1 / part2, 0.2).toDouble();
}

/// Ống tiêu chuẩn nhỏ nhất có đường kính trong ≥ [diameterMm] trong
/// `pipe_standard.json`; `null` khi vượt bảng.
Map<String, dynamic>? standardPipeFor(
  double diameterMm,
  List<Map<String, dynamic>> pipes,
) {
  for (final pipe in pipes) {
    if ((pipe['mm'] as num).toDouble() >= diameterMm) return pipe;
  }
  return null;
}

// Giá trị mặc định của màn "Tính toán đường ống khí nén".
const airPipeDefaultLengthM = 50.0;
const airPipeDefaultDropBar = 0.1;
const airPipeDefaultPressureBar = 7.0;
