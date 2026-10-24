/// Bình tích khí tiêu chuẩn — `air_compressor/air_tanks.json`.
class AirTankSpec {
  /// Mã hàng, ví dụ `V1000`.
  final String model;
  final double volumeLiters;
  final double designPressureKgfCm2;
  final double testPressureKgfCm2;
  final double diameterMm;
  final double weightKg;

  const AirTankSpec({
    required this.model,
    required this.volumeLiters,
    required this.designPressureKgfCm2,
    required this.testPressureKgfCm2,
    required this.diameterMm,
    required this.weightKg,
  });

  factory AirTankSpec.fromJson(Map<String, dynamic> json) {
    return AirTankSpec(
      model: json['model'] as String,
      volumeLiters: (json['volumeLiters'] as num).toDouble(),
      designPressureKgfCm2: (json['designPressureKgfCm2'] as num).toDouble(),
      testPressureKgfCm2: (json['testPressureKgfCm2'] as num).toDouble(),
      diameterMm: (json['diameterMm'] as num).toDouble(),
      weightKg: (json['weightKg'] as num).toDouble(),
    );
  }
}
