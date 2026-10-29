import '../../../models/acomp_spec_model.dart';
import '../../../models/oil_free_spec.dart';

/// Model máy nén trong dữ liệu, dạng chung cho bộ tính cấu hình: ACP/ACA
/// (`specs.json`, lưu lượng 7 và 8 bar) và AFR (`oil_free_specs.json`,
/// lưu lượng 8 / 10 / 12,5 bar).
class CatalogCompressor {
  const CatalogCompressor({
    required this.modelCode,
    required this.series,
    required this.powerKW,
    required this.curve,
    this.isVsd = false,
    this.isFourInOne = false,
    this.airTank,
    this.dimensionsMm,
    this.outletDn,
  });

  factory CatalogCompressor.fromAcomp(AcompSpecModel m) => CatalogCompressor(
    modelCode: m.modelCode,
    series: m.series,
    powerKW: m.powerKW,
    curve: [(7, m.flow7Bar), (8, m.flow8Bar)],
    isVsd: m.isVsd,
    isFourInOne: m.isFourInOne,
    airTank: m.airTank,
    dimensionsMm: parseDimensionsMm(m.dimensions),
    outletDn: parseDn(m.airOutlet),
  );

  factory CatalogCompressor.fromOilFree(OilFreeSpec s) => CatalogCompressor(
    modelCode: s.code,
    series: 'Oil-Free ${s.series}',
    powerKW: s.powerKW,
    curve: [for (final e in s.flow.entries) (e.key, e.value)],
    isVsd: s.isVsd,
    dimensionsMm: parseDimensionsMm(s.dimensions),
    outletDn: parseDn(s.airOutlet),
  );

  final String modelCode;

  /// `PM VSD`, `Fixed Speed`, `4-IN-1 Fixed`, `4-IN-1 VSD`, `Oil-Free F`,
  /// `Oil-Free PV`.
  final String series;
  final double powerKW;

  /// (áp suất bar, lưu lượng định mức m³/phút), áp tăng dần.
  final List<(double, double)> curve;
  final bool isVsd;
  final bool isFourInOne;

  /// Bình chứa tích hợp (lít), chỉ máy 4 trong 1.
  final double? airTank;

  /// Kích thước dài × rộng × cao (mm) theo catalog; `null` khi thiếu.
  final (double, double, double)? dimensionsMm;

  /// Cỡ lỗ thoát khí (DN) theo catalog, vd 50 với "DN50"; `null` khi thiếu.
  final int? outletDn;

  double get maxPressure => curve.last.$1;

  /// Lưu lượng ở áp làm việc: lấy mức áp kế trên trong bảng (an toàn, ví dụ
  /// 7,5 bar dùng lưu lượng 8 bar); `null` khi vượt mức áp cao nhất.
  double? flowAt(double pressure) {
    for (final (bar, flow) in curve) {
      if (pressure <= bar + 1e-9) return flow;
    }
    return null;
  }
}

/// Đọc chuỗi kích thước catalog "1300x850x1150" (mm) thành (dài, rộng, cao).
(double, double, double)? parseDimensionsMm(String? text) {
  final parts = (text ?? '')
      .toLowerCase()
      .split(RegExp(r'\s*[x×*]\s*'))
      .map((p) => double.tryParse(p.replaceAll(RegExp(r'[^0-9.]'), '')))
      .toList();
  if (parts.length != 3 || parts.any((p) => p == null || p <= 0)) return null;
  return (parts[0]!, parts[1]!, parts[2]!);
}

/// Đọc cỡ ống "DN50" → 50; `null` khi không đúng dạng.
int? parseDn(String? text) {
  final m = RegExp(r'DN\s*(\d+)', caseSensitive: false).firstMatch(text ?? '');
  return m == null ? null : int.parse(m.group(1)!);
}
