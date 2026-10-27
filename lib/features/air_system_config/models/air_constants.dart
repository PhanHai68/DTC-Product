/// Hằng số tính toán cấu hình hệ thống khí nén —
/// `assets/database/air_compressor/air_system_constants.json`.
///
/// Kỹ thuật sửa tỷ lệ khí xả, tổn áp, hệ số công suất, dãy động cơ… trong file
/// JSON, không sửa code.
class AirSystemConstants {
  const AirSystemConstants({
    required this.purgeRates,
    required this.pressureDrops,
    required this.specificPower,
    required this.powerCorrectionPerBar,
    required this.powerReferencePressure,
    required this.motorSizesKw,
    required this.tankDesignPressure,
    required this.minPressure,
    required this.maxPressure,
    required this.marginOptions,
    required this.dryerMaxPressure,
    required this.maxLines,
  });

  /// Tỷ lệ khí xả tái sinh theo kiểu tái sinh (`heatless`, `heated`, `blower`).
  final Map<String, double> purgeRates;

  /// Tổn áp (bar) theo thiết bị (`afterCooler`, `waterSeparator`, …, `piping`).
  final Map<String, double> pressureDrops;

  /// kW cho mỗi m³/phút ở áp suất tham chiếu, theo loại máy nén.
  final Map<String, double> specificPower;
  final double powerCorrectionPerBar;
  final double powerReferencePressure;
  final List<double> motorSizesKw;

  /// (áp làm việc tối đa, áp thiết kế); `null` = còn lại.
  final List<(double?, double)> tankDesignPressure;
  final double minPressure;
  final double maxPressure;

  /// Các mức gợi ý (%) cho "Lưu lượng máy lớn hơn so với nhu cầu thực tế";
  /// mức đầu là mặc định. Khách hàng tự chọn, không có công thức cố định.
  final List<double> marginOptions;

  double get defaultMargin => marginOptions.first;

  /// Máy sấy lạnh tiêu chuẩn chịu tới mức áp này; cao hơn phải đặt riêng.
  final double dryerMaxPressure;
  final int maxLines;

  double drop(String key) => pressureDrops[key] ?? 0;

  double designPressureFor(double working) {
    for (final (maxWorking, design) in tankDesignPressure) {
      if (maxWorking == null || working <= maxWorking + 1e-9) return design;
    }
    return tankDesignPressure.last.$2;
  }

  factory AirSystemConstants.fromJson(Map<String, dynamic> json) {
    Map<String, double> doubles(String key) => {
      for (final e in (json[key] as Map).entries)
        e.key as String: (e.value as num).toDouble(),
    };
    List<double> range(String key) => [
      for (final v in json[key] as List) (v as num).toDouble(),
    ];
    final pressure = range('pressureRangeBar');
    return AirSystemConstants(
      purgeRates: doubles('purgeRates'),
      pressureDrops: doubles('pressureDropsBar'),
      specificPower: doubles('specificPowerKwPerM3min'),
      powerCorrectionPerBar: (json['powerPressureCorrectionPerBar'] as num)
          .toDouble(),
      powerReferencePressure: (json['powerReferencePressureBar'] as num)
          .toDouble(),
      motorSizesKw: [
        for (final v in json['motorSizesKw'] as List) (v as num).toDouble(),
      ]..sort(),
      tankDesignPressure: [
        for (final item in json['tankDesignPressureBar'] as List)
          (
            (item['maxWorkingBar'] as num?)?.toDouble(),
            (item['designBar'] as num).toDouble(),
          ),
      ],
      minPressure: pressure.first,
      maxPressure: pressure.last,
      marginOptions: range('marginOptionsPercent'),
      dryerMaxPressure:
          (json['refrigeratedDryerMaxPressureBar'] as num?)?.toDouble() ?? 10,
      maxLines: json['maxLines'] as int,
    );
  }
}
