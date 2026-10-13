class MaterialModel {
  final int id;
  final String name;
  final double cm;
  final double optimalPressure;

  const MaterialModel({
    required this.id,
    required this.name,
    required this.cm,
    required this.optimalPressure,
  });

  /// Đọc một vật liệu từ assets/database/air_compressor/materials.json.
  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    return MaterialModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      cm: (json['cm'] as num).toDouble(),
      optimalPressure: (json['optimalPressure'] as num).toDouble(),
    );
  }
}
