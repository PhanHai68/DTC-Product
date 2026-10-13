class AcompSpecModel {
  final String modelCode;
  final String series;
  final double powerKW;
  final double powerHP;
  final double flow7Bar;
  final double flow8Bar;
  final String airOutlet;
  final double lubricant;
  final double weight;
  final String dimensions;

  AcompSpecModel({
    required this.modelCode,
    required this.series,
    required this.powerKW,
    required this.powerHP,
    required this.flow7Bar,
    required this.flow8Bar,
    required this.airOutlet,
    required this.lubricant,
    required this.weight,
    required this.dimensions,
  });

  /// Đọc một model từ assets/database/air_compressor/specs.json.
  factory AcompSpecModel.fromJson(Map<String, dynamic> json) {
    return AcompSpecModel(
      modelCode: json['modelCode'] as String,
      series: json['series'] as String,
      powerKW: (json['powerKW'] as num).toDouble(),
      powerHP: (json['powerHP'] as num).toDouble(),
      flow7Bar: (json['flow7Bar'] as num).toDouble(),
      flow8Bar: (json['flow8Bar'] as num).toDouble(),
      airOutlet: json['airOutlet'] as String,
      lubricant: (json['lubricant'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
      dimensions: json['dimensions'] as String,
    );
  }
}
