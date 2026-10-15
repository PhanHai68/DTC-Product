import 'dart:math' as math;

import '../models/acomp_spec_model.dart';
import '../models/acomp_vsd_compare_config.dart';

/// Một cặp máy cùng cỡ: biến tần (`ACP-50PV`) và tốc độ cố định (`ACP-50F`).
class AcompSpeedPair {
  final AcompSpecModel vsd;
  final AcompSpecModel fixed;

  const AcompSpeedPair(this.vsd, this.fixed);

  /// Mã chung của cặp, ví dụ `ACP-50`.
  String get sizeCode => acompSizeCode(vsd.modelCode);

  double flowAt(AcompSpecModel model, int pressureBar) =>
      pressureBar == 7 ? model.flow7Bar : model.flow8Bar;

  /// Hai máy lệch công suất hoặc lưu lượng ở [pressureBar].
  bool isMismatched(int pressureBar) =>
      vsd.powerKW != fixed.powerKW ||
      flowAt(vsd, pressureBar) != flowAt(fixed, pressureBar);
}

/// `ACP-50PV` và `ACP-50F` cùng trả về `ACP-50`.
String acompSizeCode(String modelCode) =>
    modelCode.replaceFirst(RegExp(r'(PV|F)$'), '');

/// Ghép máy biến tần với máy cố định cùng mã cỡ, sắp theo HP của máy
/// biến tần. Model không có cặp thì bỏ qua.
List<AcompSpeedPair> buildAcompSpeedPairs(List<AcompSpecModel> specs) {
  final fixedBySize = {
    for (final spec in specs)
      if (spec.series == 'Fixed Speed') acompSizeCode(spec.modelCode): spec,
  };
  final pairs = [
    for (final spec in specs)
      if (spec.series == 'PM VSD')
        if (fixedBySize[acompSizeCode(spec.modelCode)] case final fixed?)
          AcompSpeedPair(spec, fixed),
  ];
  pairs.sort((a, b) => a.vsd.powerHP.compareTo(b.vsd.powerHP));
  return pairs;
}

/// Điều kiện vận hành khách hàng nhập.
class AcompOperatingInput {
  /// Nhu cầu khí trung bình, % lưu lượng của máy nhỏ hơn trong cặp.
  final double loadPercent;
  final int pressureBar;
  final double hoursPerDay;
  final double daysPerYear;
  final double electricityPrice;

  /// Giá mua (VNĐ); null nếu chưa nhập.
  final double? vsdPrice;
  final double? fixedPrice;

  const AcompOperatingInput({
    required this.loadPercent,
    required this.pressureBar,
    required this.hoursPerDay,
    required this.daysPerYear,
    required this.electricityPrice,
    this.vsdPrice,
    this.fixedPrice,
  });

  double get hoursPerYear => hoursPerDay * daysPerYear;
}

/// Kết quả của một máy.
class AcompMachineEnergy {
  final AcompSpecModel model;

  /// Tải của chính máy này (0–1).
  final double load;
  final double averageKW;
  final double kwhPerYear;
  final double costPerYear;

  const AcompMachineEnergy({
    required this.model,
    required this.load,
    required this.averageKW,
    required this.kwhPerYear,
    required this.costPerYear,
  });
}

class AcompSpeedComparison {
  final AcompSpeedPair pair;
  final AcompOperatingInput input;

  /// Nhu cầu khí trung bình (m³/phút) mà cả hai máy cùng phải cấp.
  final double demandFlow;
  final AcompMachineEnergy vsd;
  final AcompMachineEnergy fixed;

  const AcompSpeedComparison({
    required this.pair,
    required this.input,
    required this.demandFlow,
    required this.vsd,
    required this.fixed,
  });

  /// Tiền điện máy biến tần tiết kiệm được mỗi năm (âm nếu tốn hơn).
  double get savingsPerYear => fixed.costPerYear - vsd.costPerYear;

  double get savingsPercent =>
      fixed.costPerYear > 0 ? savingsPerYear / fixed.costPerYear * 100 : 0;

  double get kwhSavedPerYear => fixed.kwhPerYear - vsd.kwhPerYear;

  bool get hasPrices => input.vsdPrice != null && input.fixedPrice != null;

  /// Máy biến tần đắt hơn bao nhiêu (null nếu chưa nhập đủ giá).
  double? get priceDifference =>
      hasPrices ? input.vsdPrice! - input.fixedPrice! : null;

  /// Số năm để tiền điện tiết kiệm bù phần chênh giá. 0 nếu máy biến tần
  /// không đắt hơn; null nếu chưa có giá hoặc biến tần không tiết kiệm.
  double? get paybackYears {
    final difference = priceDifference;
    if (difference == null) return null;
    if (difference <= 0) return 0;
    if (savingsPerYear <= 0) return null;
    return difference / savingsPerYear;
  }

  /// Tổng chi phí (giá mua + tiền điện) sau [years] năm.
  double totalCostAfter(double years, {required bool vsdMachine}) {
    final price = (vsdMachine ? input.vsdPrice : input.fixedPrice) ?? 0;
    final energy = vsdMachine ? vsd.costPerYear : fixed.costPerYear;
    return price + energy * years;
  }

  /// Lợi thế lũy kế của máy biến tần sau [years] năm (đã trừ chênh giá).
  double netBenefitAfter(double years) =>
      savingsPerYear * years - (priceDifference ?? 0);
}

/// Tính điện năng theo mô hình trong `vsd_compare.json`. Công suất ghi trên
/// catalog (kW) được coi là công suất điện khi chạy đầy tải.
class AcompEnergyCalculator {
  final AcompVsdAssumptions assumptions;

  const AcompEnergyCalculator(this.assumptions);

  /// Công suất trung bình của máy cố định, theo phần công suất đầy tải.
  /// Có tải trong [load] thời gian, không tải phần còn lại; cộng phần điện
  /// do phải đặt dải áp cao hơn.
  double fixedPowerFraction(double load) {
    final l = load.clamp(0.0, 1.0);
    final a = assumptions;
    return (l + (1 - l) * a.unloadPowerRatio) *
        (1 + a.energyPerBar * a.fixedPressureBandBar);
  }

  /// Công suất trung bình của máy biến tần, theo phần công suất đầy tải.
  /// Từ tốc độ tối thiểu trở lên: công suất gần tỷ lệ với lưu lượng. Dưới
  /// tốc độ tối thiểu: chạy có tải/không tải ở tốc độ tối thiểu.
  double vsdPowerFraction(double load) {
    final l = load.clamp(0.0, 1.0);
    final a = assumptions;
    double modulating(double x) => a.vsdBaseRatio + (1 - a.vsdBaseRatio) * x;
    if (l >= a.vsdMinLoad || a.vsdMinLoad <= 0) return modulating(l);
    final atMin = modulating(a.vsdMinLoad);
    final loadedShare = l / a.vsdMinLoad;
    return atMin * loadedShare + atMin * a.unloadPowerRatio * (1 - loadedShare);
  }

  AcompSpeedComparison compare(AcompSpeedPair pair, AcompOperatingInput input) {
    final vsdFlow = pair.flowAt(pair.vsd, input.pressureBar);
    final fixedFlow = pair.flowAt(pair.fixed, input.pressureBar);
    final demand = input.loadPercent / 100 * math.min(vsdFlow, fixedFlow);

    AcompMachineEnergy energy(
      AcompSpecModel model,
      double flow,
      double Function(double) fraction,
    ) {
      final load = flow > 0 ? demand / flow : 0.0;
      final averageKW = model.powerKW * fraction(load);
      final kwh = averageKW * input.hoursPerYear;
      return AcompMachineEnergy(
        model: model,
        load: load,
        averageKW: averageKW,
        kwhPerYear: kwh,
        costPerYear: kwh * input.electricityPrice,
      );
    }

    return AcompSpeedComparison(
      pair: pair,
      input: input,
      demandFlow: demand,
      vsd: energy(pair.vsd, vsdFlow, vsdPowerFraction),
      fixed: energy(pair.fixed, fixedFlow, fixedPowerFraction),
    );
  }

  /// % tiết kiệm của máy biến tần theo từng mức tải (cho biểu đồ).
  List<(double loadPercent, double savingsPercent)> savingsCurve(
    AcompSpeedPair pair,
    AcompOperatingInput input, {
    double from = 10,
    double to = 100,
    double step = 5,
  }) {
    return [
      for (var load = from; load <= to + 1e-9; load += step)
        (
          load,
          compare(
            pair,
            AcompOperatingInput(
              loadPercent: load,
              pressureBar: input.pressureBar,
              hoursPerDay: input.hoursPerDay,
              daysPerYear: input.daysPerYear,
              electricityPrice: input.electricityPrice,
            ),
          ).savingsPercent,
        ),
    ];
  }
}

enum AcompAdviceLevel { vsd, fixed, consider }

class AcompAdvice {
  final AcompAdviceLevel level;
  final String title;
  final String detail;

  const AcompAdvice(this.level, this.title, this.detail);
}

/// Gợi ý lựa chọn theo quy tắc trong `advice` của `vsd_compare.json`.
AcompAdvice adviseAcompSpeed(
  AcompSpeedComparison result,
  AcompVsdCompareConfig config,
) {
  final load = result.input.loadPercent;
  if (result.savingsPerYear <= 0) {
    return const AcompAdvice(
      AcompAdviceLevel.fixed,
      'Nên chọn máy tốc độ cố định',
      'Ở mức tải này máy biến tần không tiết kiệm được điện so với máy cố định.',
    );
  }
  final payback = result.paybackYears;
  if (payback != null && payback <= config.paybackYears) {
    return AcompAdvice(
      AcompAdviceLevel.vsd,
      'Nên chọn máy biến tần',
      payback == 0
          ? 'Máy biến tần không đắt hơn và còn tiết kiệm điện mỗi năm.'
          : 'Tiền điện tiết kiệm bù phần chênh giá trong khoảng '
                '${payback.toStringAsFixed(1)} năm '
                '(dưới ${_plain(config.paybackYears)} năm).',
    );
  }
  if (load >= config.nearFullLoadPercent) {
    return AcompAdvice(
      AcompAdviceLevel.fixed,
      'Máy tốc độ cố định là đủ',
      'Nhu cầu khí gần đầy tải (≥ ${_plain(config.nearFullLoadPercent)}%) nên '
          'lợi thế điện của máy biến tần nhỏ; máy cố định có giá đầu tư thấp hơn.',
    );
  }
  if (payback != null) {
    return AcompAdvice(
      AcompAdviceLevel.consider,
      'Cân nhắc theo thời gian sử dụng',
      'Cần khoảng ${payback.toStringAsFixed(1)} năm để tiền điện bù phần chênh '
          'giá. Nếu khách dùng máy lâu dài thì máy biến tần vẫn có lợi.',
    );
  }
  return const AcompAdvice(
    AcompAdviceLevel.vsd,
    'Máy biến tần tiết kiệm điện ở mức tải này',
    'Nhập giá mua hai máy để tính thời gian hoàn vốn phần chênh lệch.',
  );
}

String _plain(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
