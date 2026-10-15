/// Giả định tính điện năng máy nén khí biến tần và tốc độ cố định —
/// `assumptions` trong `air_compressor/vsd_compare.json`.
class AcompVsdAssumptions {
  /// Công suất khi chạy không tải, tính theo công suất đầy tải.
  final double unloadPowerRatio;

  /// Phần công suất cố định của máy biến tần (không phụ thuộc tải).
  final double vsdBaseRatio;

  /// Tải nhỏ nhất máy biến tần còn giảm tốc được; dưới mức này máy
  /// chạy có tải/không tải ở tốc độ tối thiểu.
  final double vsdMinLoad;

  /// Máy cố định phải đặt áp cao hơn máy biến tần trung bình bao nhiêu bar.
  final double fixedPressureBandBar;

  /// Điện năng tăng thêm cho mỗi 1 bar áp suất (0,07 = 7%).
  final double energyPerBar;

  const AcompVsdAssumptions({
    required this.unloadPowerRatio,
    required this.vsdBaseRatio,
    required this.vsdMinLoad,
    required this.fixedPressureBandBar,
    required this.energyPerBar,
  });

  factory AcompVsdAssumptions.fromJson(Map<String, dynamic> json) {
    return AcompVsdAssumptions(
      unloadPowerRatio: (json['unloadPowerRatio'] as num).toDouble(),
      vsdBaseRatio: (json['vsdBaseRatio'] as num).toDouble(),
      vsdMinLoad: (json['vsdMinLoad'] as num).toDouble(),
      fixedPressureBandBar: (json['fixedPressureBandBar'] as num).toDouble(),
      energyPerBar: (json['energyPerBar'] as num).toDouble(),
    );
  }

  AcompVsdAssumptions copyWith({
    double? unloadPowerRatio,
    double? vsdBaseRatio,
    double? vsdMinLoad,
    double? fixedPressureBandBar,
  }) {
    return AcompVsdAssumptions(
      unloadPowerRatio: unloadPowerRatio ?? this.unloadPowerRatio,
      vsdBaseRatio: vsdBaseRatio ?? this.vsdBaseRatio,
      vsdMinLoad: vsdMinLoad ?? this.vsdMinLoad,
      fixedPressureBandBar: fixedPressureBandBar ?? this.fixedPressureBandBar,
      energyPerBar: energyPerBar,
    );
  }
}

/// Cấu hình màn so sánh biến tần – cố định — `air_compressor/vsd_compare.json`.
class AcompVsdCompareConfig {
  final AcompVsdAssumptions assumptions;

  /// Hoàn vốn phần chênh giá trong số năm này thì khuyên chọn biến tần.
  final double paybackYears;

  /// Tải trung bình từ mức này (%) coi là gần đầy tải.
  final double nearFullLoadPercent;

  final List<String> vsdNotes;
  final List<String> fixedNotes;

  const AcompVsdCompareConfig({
    required this.assumptions,
    required this.paybackYears,
    required this.nearFullLoadPercent,
    required this.vsdNotes,
    required this.fixedNotes,
  });

  factory AcompVsdCompareConfig.fromJson(Map<String, dynamic> json) {
    final advice = json['advice'] as Map<String, dynamic>;
    final notes = json['notes'] as Map<String, dynamic>;
    return AcompVsdCompareConfig(
      assumptions: AcompVsdAssumptions.fromJson(
        json['assumptions'] as Map<String, dynamic>,
      ),
      paybackYears: (advice['paybackYears'] as num).toDouble(),
      nearFullLoadPercent: (advice['nearFullLoadPercent'] as num).toDouble(),
      vsdNotes: [for (final note in notes['vsd'] as List) note as String],
      fixedNotes: [for (final note in notes['fixed'] as List) note as String],
    );
  }
}
