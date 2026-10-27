/// Máy nén khí trục vít không dầu phun nước, áp suất thường —
/// `air_compressor/oil_free_specs.json` (catalog OPPAIR Oil-Free, mã hãng
/// `OFR` đổi thành `AFR`).
class OilFreeSpec {
  const OilFreeSpec({
    required this.model,
    required this.series,
    required this.powerKW,
    required this.powerHP,
    required this.flow,
    required this.flowMin,
    required this.airOutlet,
    required this.waterPipe,
    required this.noiseDb,
    required this.coolingWaterTH,
    required this.lubricatingWaterL,
    required this.dimensions,
    required this.dimensionsWater,
    required this.weightKg,
    required this.weightWaterKg,
    this.variant,
  });

  /// Mã model, ví dụ `AFR-50PV`.
  final String model;

  /// Phân biệt 2 phiên bản cùng model (theo cỡ ống ra khí, ví dụ `DN125`).
  final String? variant;

  /// `F` (tốc độ cố định) hoặc `PV` (biến tần).
  final String series;
  final double powerKW;
  final double powerHP;

  /// Lưu lượng định mức (m³/phút) theo áp suất làm việc (bar), tăng dần.
  final Map<double, double> flow;

  /// Lưu lượng nhỏ nhất (máy biến tần), cùng các mức áp với [flow].
  final Map<double, double> flowMin;
  final String airOutlet;

  /// Đường kính ống nước vào/ra.
  final String waterPipe;
  final double noiseDb;

  /// Lưu lượng nước làm mát (t/h, nước vào 32 °C).
  final double coolingWaterTH;

  /// Nước bôi trơn (lít).
  final double lubricatingWaterL;

  /// D×R×C (mm); khi có 2 bản thì đây là bản giải nhiệt gió (A).
  final String dimensions;

  /// D×R×C bản giải nhiệt nước (W), nếu có.
  final String? dimensionsWater;
  final double weightKg;

  /// Trọng lượng bản giải nhiệt nước (W), nếu khác bản A.
  final double? weightWaterKg;

  bool get isVsd => series == 'PV';

  /// Mã hiển thị, kèm phiên bản khi cùng model có 2 bản.
  String get code => variant == null ? model : '$model ($variant)';

  factory OilFreeSpec.fromJson(Map<String, dynamic> json) {
    Map<double, double> curve(Object? raw) {
      final entries = [
        for (final e in ((raw as Map?) ?? const {}).entries)
          if (e.value != null)
            MapEntry(
              double.parse(e.key as String),
              (e.value as num).toDouble(),
            ),
      ]..sort((a, b) => a.key.compareTo(b.key));
      return Map.fromEntries(entries);
    }

    return OilFreeSpec(
      model: json['model'] as String,
      variant: json['variant'] as String?,
      series: json['series'] as String,
      powerKW: (json['powerKW'] as num).toDouble(),
      powerHP: (json['powerHP'] as num).toDouble(),
      flow: curve(json['flow']),
      flowMin: curve(json['flowMin']),
      airOutlet: json['airOutlet'] as String,
      waterPipe: json['waterPipe'] as String,
      noiseDb: (json['noiseDb'] as num).toDouble(),
      coolingWaterTH: (json['coolingWaterTH'] as num).toDouble(),
      lubricatingWaterL: (json['lubricatingWaterL'] as num).toDouble(),
      dimensions: (json['dimensions'] ?? json['dimensionsAir']) as String,
      dimensionsWater: json['dimensionsWater'] as String?,
      weightKg: (json['weightKg'] as num).toDouble(),
      weightWaterKg: (json['weightWaterKg'] as num?)?.toDouble(),
    );
  }
}
