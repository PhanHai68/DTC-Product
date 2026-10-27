/// Dung tích bình chứa khí lý thuyết (lít) — dùng chung cho màn "Tính thể
/// tích bình chứa" và "Cấu hình hệ thống khí nén".
///
/// V_th = (0.25 · (Q_c · 1000) · (T_0 + 273.15)) /
///        ((60 / t_c) · ΔP · (T_1 + 273.15))
///
/// [qc] lưu lượng máy nén (m³/phút), [tc] chu kỳ nạp/xả (giây), [deltaP] độ
/// chênh áp (bar), [t0] nhiệt độ trong bình và [t1] nhiệt độ đầu hút (°C).
double airTankTheoreticalLiters({
  required double qc,
  double tc = airTankDefaultCycleSeconds,
  double deltaP = airTankDefaultDeltaPBar,
  double t0 = airTankDefaultTankTempC,
  double t1 = airTankDefaultInletTempC,
}) {
  final numerator = 0.25 * (qc * 1000) * (t0 + 273.15);
  final denominator = (60 / tc) * deltaP * (t1 + 273.15);
  return numerator / denominator;
}

// Giá trị mặc định của màn "Tính thể tích bình chứa".
const airTankDefaultCycleSeconds = 20.0;
const airTankDefaultDeltaPBar = 0.5;
const airTankDefaultTankTempC = 45.0;
const airTankDefaultInletTempC = 35.0;
