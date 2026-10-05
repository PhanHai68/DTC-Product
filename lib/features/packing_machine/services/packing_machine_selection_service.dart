import '../../grinding_machine/models/grinding_machine_match.dart';
import '../../grinding_machine/utils/grinding_format.dart';
import '../models/packing_catalog.dart';

/// Yêu cầu khách hàng cho máy đóng gói — tiêu chí bỏ trống (`null`) thì
/// không đối chiếu.
class PackingSelectionCriteria {
  const PackingSelectionCriteria({
    this.form,
    this.packWeightG,
    this.speedPerMin,
    this.packaging,
    this.automation,
    this.maxPowerKw,
  });

  final PackingMaterialForm? form;

  /// Khối lượng mỗi gói/bao, quy về gam.
  final double? packWeightG;

  /// Tốc độ cần đạt (túi/gói/bao mỗi phút).
  final double? speedPerMin;
  final PackingPackaging? packaging;
  final PackingAutomation? automation;
  final double? maxPowerKw;

  bool get isEmpty =>
      form == null &&
      packWeightG == null &&
      speedPerMin == null &&
      packaging == null &&
      automation == null &&
      maxPowerKw == null;
}

/// 1 model đã đối chiếu — cùng cấu trúc kết quả của máy nghiền
/// ([GrindingCriterionResult], [GrindingMatchLabel]) để hiển thị thống nhất.
class PackingMachineMatch {
  const PackingMachineMatch({
    required this.machine,
    required this.series,
    required this.criteria,
    required this.matchScore,
    required this.label,
  });

  final PackingMachine machine;
  final PackingSeries? series;
  final List<GrindingCriterionResult> criteria;
  final double matchScore;
  final GrindingMatchLabel label;

  int get notMatchedCount => criteria
      .where((c) => c.status == GrindingCriterionStatus.notMatch)
      .length;
  int get unknownCount =>
      criteria.where((c) => c.status == GrindingCriterionStatus.unknown).length;
}

/// Chọn máy đóng gói theo đúng nguyên tắc bộ chọn máy nghiền: mỗi tiêu chí
/// đối chiếu độc lập thành MATCH / NOT_MATCH / UNKNOWN; thiếu dữ liệu catalog
/// là UNKNOWN (không tính là đạt, không loại máy). Mọi model đều có trong kết
/// quả, sắp: Phù hợp cao → Có thể phù hợp → Gần đúng nhất.
abstract final class PackingMachineSelectionService {
  static List<PackingMachineMatch> evaluate({
    required PackingSelectionCriteria criteria,
    required List<PackingMachine> machines,
    Map<String, PackingSeries> seriesByCode = const {},
  }) {
    final results = <PackingMachineMatch>[];
    for (final machine in machines) {
      final s = machine.selection;
      final items = <GrindingCriterionResult>[
        if (criteria.form case final form?) _form(s, form),
        if (criteria.packWeightG case final weight?) _weight(s, weight),
        if (criteria.speedPerMin case final speed?) _speed(s, speed),
        if (criteria.packaging case final packaging?)
          _packaging(s, packaging, seriesByCode[machine.seriesCode]),
        if (criteria.automation case final automation?)
          _automation(s, automation),
        if (criteria.maxPowerKw case final power?) _power(s, power),
      ];
      results.add(
        PackingMachineMatch(
          machine: machine,
          series: seriesByCode[machine.seriesCode],
          criteria: items,
          matchScore: _score(items),
          label: _label(items),
        ),
      );
    }
    results.sort((a, b) {
      final byLabel = a.label.index.compareTo(b.label.index);
      if (byLabel != 0) return byLabel;
      final byNotMatch = a.notMatchedCount.compareTo(b.notMatchedCount);
      if (byNotMatch != 0) return byNotMatch;
      final byScore = b.matchScore.compareTo(a.matchScore);
      if (byScore != 0) return byScore;
      final byUnknown = a.unknownCount.compareTo(b.unknownCount);
      if (byUnknown != 0) return byUnknown;
      return GrindingFormat.compareModel(a.machine.model, b.machine.model);
    });
    return results;
  }

  static GrindingCriterionResult _form(
    PackingSelectionData s,
    PackingMaterialForm form,
  ) {
    const label = 'Dạng nguyên liệu';
    final forms = s.forms;
    if (forms == null || forms.isEmpty) {
      return GrindingCriterionResult(
        label: label,
        status: GrindingCriterionStatus.unknown,
        requiredDisplay: form.label,
        reason: 'Catalog chưa ghi rõ dạng nguyên liệu cho model này.',
      );
    }
    final ok = forms.contains(form);
    return GrindingCriterionResult(
      label: label,
      status: ok
          ? GrindingCriterionStatus.match
          : GrindingCriterionStatus.notMatch,
      requiredDisplay: form.label,
      actualDisplay: forms.map((f) => f.label).join(', '),
      reason: ok
          ? 'Model đóng gói được nguyên liệu dạng ${form.label.toLowerCase()}.'
          : 'Catalog không ghi model này dùng cho dạng '
                '${form.label.toLowerCase()}.',
    );
  }

  /// Khối lượng yêu cầu phải nằm trong dải định lượng của máy. Máy chỉ ghi
  /// mức tối đa (VD "≤ 200 g") thì chỉ so với mức tối đa.
  static GrindingCriterionResult _weight(PackingSelectionData s, double g) {
    const label = 'Khối lượng mỗi gói';
    final required = formatWeight(g);
    final min = s.weightMinG;
    final max = s.weightMaxG;
    if (max == null) {
      return GrindingCriterionResult(
        label: label,
        status: GrindingCriterionStatus.unknown,
        requiredDisplay: required,
        reason: 'Catalog chưa có dải khối lượng cho model này.',
      );
    }
    // Cùng 1 đơn vị cho cả dải như catalog: "10 - 2000 g", "5 - 50 kg".
    final actual = min == null
        ? '≤ ${formatWeight(max)}'
        : min >= 1000
        ? '${_fmt(min / 1000)} - ${_fmt(max / 1000)} kg'
        : '${_fmt(min)} - ${_fmt(max)} g';
    final tooLight = min != null && g < min;
    final tooHeavy = g > max;
    return GrindingCriterionResult(
      label: label,
      status: tooLight || tooHeavy
          ? GrindingCriterionStatus.notMatch
          : GrindingCriterionStatus.match,
      requiredDisplay: required,
      actualDisplay: actual,
      reason: tooHeavy
          ? 'Vượt khối lượng tối đa của model.'
          : tooLight
          ? 'Nhỏ hơn khối lượng tối thiểu của model.'
          : 'Nằm trong dải khối lượng của model.',
    );
  }

  /// Đạt khi tốc độ tối đa của máy ≥ yêu cầu (tốc độ thực tế còn tùy
  /// nguyên liệu và khối lượng gói — catalog ghi rõ điều này).
  static GrindingCriterionResult _speed(PackingSelectionData s, double v) {
    const label = 'Tốc độ';
    final required = '≥ ${_fmt(v)} ${s.speedUnit}';
    final max = s.speedMax;
    if (max == null) {
      return GrindingCriterionResult(
        label: label,
        status: GrindingCriterionStatus.unknown,
        requiredDisplay: required,
        reason: 'Catalog chưa có tốc độ cho model này.',
      );
    }
    final min = s.speedMin;
    final actual = min == null || min == max
        ? '${_fmt(max)} ${s.speedUnit}'
        : '${_fmt(min)} - ${_fmt(max)} ${s.speedUnit}';
    final ok = max >= v;
    return GrindingCriterionResult(
      label: label,
      status: ok
          ? GrindingCriterionStatus.match
          : GrindingCriterionStatus.notMatch,
      requiredDisplay: required,
      actualDisplay: actual,
      reason: ok
          ? 'Tốc độ tối đa đạt yêu cầu (thực tế tùy nguyên liệu và khối '
                'lượng gói).'
          : 'Tốc độ tối đa của model thấp hơn yêu cầu.',
    );
  }

  static GrindingCriterionResult _packaging(
    PackingSelectionData s,
    PackingPackaging packaging,
    PackingSeries? series,
  ) {
    const label = 'Bao bì';
    final types = s.packaging;
    if (types == null || types.isEmpty) {
      return GrindingCriterionResult(
        label: label,
        status: GrindingCriterionStatus.unknown,
        requiredDisplay: packaging.label,
        reason:
            '${series?.nameVi ?? 'Model này'} là thiết bị định lượng, bao bì '
            'tùy máy đóng gói đi kèm.',
      );
    }
    final ok = types.contains(packaging);
    return GrindingCriterionResult(
      label: label,
      status: ok
          ? GrindingCriterionStatus.match
          : GrindingCriterionStatus.notMatch,
      requiredDisplay: packaging.label,
      actualDisplay: types.map((t) => t.label).join(', '),
      reason: ok
          ? 'Model đóng được loại bao bì này.'
          : 'Model không dùng cho loại bao bì này.',
    );
  }

  static GrindingCriterionResult _automation(
    PackingSelectionData s,
    PackingAutomation automation,
  ) {
    const label = 'Mức tự động';
    final actual = s.automation;
    if (actual == null) {
      return GrindingCriterionResult(
        label: label,
        status: GrindingCriterionStatus.unknown,
        requiredDisplay: automation.label,
        reason: 'Catalog chưa ghi rõ mức tự động của model này.',
      );
    }
    final ok = actual == automation;
    return GrindingCriterionResult(
      label: label,
      status: ok
          ? GrindingCriterionStatus.match
          : GrindingCriterionStatus.notMatch,
      requiredDisplay: automation.label,
      actualDisplay: actual.label,
      reason: ok
          ? 'Đúng mức tự động yêu cầu.'
          : 'Model là loại ${actual.label.toLowerCase()}.',
    );
  }

  static GrindingCriterionResult _power(PackingSelectionData s, double kw) {
    const label = 'Công suất điện';
    final required = '≤ ${_fmt(kw)} kW';
    final actual = s.powerKw;
    if (actual == null) {
      return GrindingCriterionResult(
        label: label,
        status: GrindingCriterionStatus.unknown,
        requiredDisplay: required,
        reason: 'Catalog chưa có công suất điện cho model này.',
      );
    }
    final ok = actual <= kw;
    return GrindingCriterionResult(
      label: label,
      status: ok
          ? GrindingCriterionStatus.match
          : GrindingCriterionStatus.notMatch,
      requiredDisplay: required,
      actualDisplay: '${_fmt(actual)} kW',
      reason: ok
          ? 'Công suất điện trong giới hạn cho phép.'
          : 'Công suất điện vượt giới hạn cho phép.',
    );
  }

  static double _score(List<GrindingCriterionResult> items) {
    if (items.isEmpty) return 0;
    final matched = items
        .where((c) => c.status == GrindingCriterionStatus.match)
        .length;
    return matched / items.length * 100;
  }

  static GrindingMatchLabel _label(List<GrindingCriterionResult> items) {
    if (items.any((c) => c.status == GrindingCriterionStatus.notMatch)) {
      return GrindingMatchLabel.closest;
    }
    if (items.any((c) => c.status == GrindingCriterionStatus.unknown)) {
      return GrindingMatchLabel.possible;
    }
    return GrindingMatchLabel.strong;
  }

  /// "500 g", "1.5 kg", "50 kg" — từ 1000 g trở lên đổi sang kg.
  static String formatWeight(double g) =>
      g >= 1000 ? '${_fmt(g / 1000)} kg' : '${_fmt(g)} g';

  static String _fmt(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}
