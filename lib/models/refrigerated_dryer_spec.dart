/// Máy sấy khí tác nhân lạnh — `air_compressor/refrigerated_dryers.json`
/// (catalog OPPAIR, mã hãng `OFD` đổi thành `ACD`).
class RefrigeratedDryerSpec {
  const RefrigeratedDryerSpec({
    required this.model,
    required this.capacityM3min,
    required this.compressorKw,
    required this.fanW,
    required this.airOutlet,
    required this.lengthMm,
    required this.widthMm,
    required this.heightMm,
    required this.weightKg,
    required this.workingPressure,
    required this.dewPoint,
    required this.operatingTemperature,
    required this.voltage,
    this.maxInletTempC,
    this.refrigerant,
    this.matchingCompressorKw = const [],
  });

  /// Mã model, ví dụ `ACD-10`.
  final String model;

  /// Lưu lượng xử lý (m³/phút).
  final double capacityM3min;

  /// Công suất máy nén lạnh (kW).
  final double compressorKw;

  /// Công suất quạt (W).
  final double fanW;
  final String airOutlet;
  final double lengthMm;
  final double widthMm;
  final double heightMm;
  final double weightKg;

  /// Nhiệt độ khí vào tối đa (°C); `null` khi bảng hãng chưa có.
  final double? maxInletTempC;

  /// Môi chất lạnh, ví dụ `R410a`.
  final String? refrigerant;

  /// Công suất máy nén khí tương ứng (kW), ví dụ `[7.5, 11]`; rỗng khi bảng
  /// hãng chưa có. Cấu hình hệ thống chọn máy sấy theo giá trị lớn nhất.
  final List<double> matchingCompressorKw;

  // Thông số chung theo nhóm model (dòng nhỏ 1 pha / dòng lớn 3 pha).
  final String workingPressure;
  final String dewPoint;
  final String operatingTemperature;
  final String voltage;

  /// Đọc file JSON: mỗi nhóm có thông số chung và danh sách model.
  static List<RefrigeratedDryerSpec> listFromJson(Map<String, dynamic> json) =>
      [
        for (final group in json['groups'] as List)
          for (final m in (group as Map)['models'] as List)
            RefrigeratedDryerSpec(
              model: m['model'] as String,
              capacityM3min: (m['capacityM3min'] as num).toDouble(),
              compressorKw: (m['compressorKw'] as num).toDouble(),
              fanW: (m['fanW'] as num).toDouble(),
              airOutlet: m['airOutlet'] as String,
              lengthMm: (m['lengthMm'] as num).toDouble(),
              widthMm: (m['widthMm'] as num).toDouble(),
              heightMm: (m['heightMm'] as num).toDouble(),
              weightKg: (m['weightKg'] as num).toDouble(),
              workingPressure: group['workingPressure'] as String,
              dewPoint: group['dewPoint'] as String,
              operatingTemperature: group['operatingTemperature'] as String,
              voltage: group['voltage'] as String,
              maxInletTempC: (m['maxInletTempC'] as num?)?.toDouble(),
              refrigerant: m['refrigerant'] as String?,
              matchingCompressorKw: [
                for (final kw in (m['matchingCompressorKw'] as List?) ?? [])
                  (kw as num).toDouble(),
              ],
            ),
      ];
}
