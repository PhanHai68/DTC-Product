/// Lọc đường ống — `air_compressor/line_filters.json` (catalog ACOMP).
class LineFilterSpec {
  const LineFilterSpec({
    required this.model,
    required this.capacityM3min,
    required this.port,
    required this.levels,
    this.dimensionsMm,
  });

  /// Kích thước thân lọc dài × rộng × cao (mm), trường `dimensions` dạng
  /// "160x160x500"; `null` khi chưa có dữ liệu.
  final (double, double, double)? dimensionsMm;

  /// Mã model, ví dụ `015`.
  final String model;

  /// Lưu lượng xử lý tối đa (m³/phút).
  final double capacityM3min;

  /// Đường kính đầu vào / đầu ra, ví dụ `1 1/2" = DN40`.
  final String port;

  /// Các cấp lọc của model: tách nước → tách thô → tách tinh.
  final List<LineFilterLevel> levels;

  factory LineFilterSpec.fromJson(Map<String, dynamic> json) => LineFilterSpec(
    model: json['model'] as String,
    capacityM3min: (json['capacityM3min'] as num).toDouble(),
    port: json['port'] as String,
    levels: [
      for (final l in json['levels'] as List)
        LineFilterLevel.fromJson(l as Map<String, dynamic>),
    ],
    dimensionsMm: _dimensions(json['dimensions'] as String?),
  );

  static (double, double, double)? _dimensions(String? text) {
    final parts = (text ?? '')
        .split(RegExp(r'\s*[xX×*]\s*'))
        .map((p) => double.tryParse(p.trim()))
        .toList();
    if (parts.length != 3 || parts.any((p) => p == null || p <= 0)) {
      return null;
    }
    return (parts[0]!, parts[1]!, parts[2]!);
  }
}

class LineFilterLevel {
  const LineFilterLevel({
    required this.level,
    required this.function,
    required this.micron,
  });

  /// Ký hiệu cấp lọc, ví dụ `Q`, `P`, `S`.
  final String level;

  /// Chức năng: tách nước / tách thô / tách tinh.
  final String function;

  /// Hiệu suất lọc (µm).
  final double micron;

  factory LineFilterLevel.fromJson(Map<String, dynamic> json) =>
      LineFilterLevel(
        level: json['level'] as String,
        function: json['function'] as String,
        micron: (json['micron'] as num).toDouble(),
      );
}
