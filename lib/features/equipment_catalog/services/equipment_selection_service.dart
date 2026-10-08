import '../../grinding_machine/models/grinding_machine_match.dart';
import '../../grinding_machine/utils/grinding_format.dart';
import '../models/equipment_catalog.dart';

/// 1 model đã đối chiếu — cùng cấu trúc kết quả của máy nghiền
/// ([GrindingCriterionResult], [GrindingMatchLabel]) để hiển thị thống nhất.
class EquipmentMatch {
  const EquipmentMatch({
    required this.machine,
    required this.series,
    required this.criteria,
    required this.matchScore,
    required this.label,
  });

  final EquipmentMachine machine;
  final EquipmentSeries? series;
  final List<GrindingCriterionResult> criteria;
  final double matchScore;
  final GrindingMatchLabel label;

  int get notMatchedCount => criteria
      .where((c) => c.status == GrindingCriterionStatus.notMatch)
      .length;
  int get unknownCount =>
      criteria.where((c) => c.status == GrindingCriterionStatus.unknown).length;
}

/// Chọn máy theo đúng nguyên tắc bộ chọn máy nghiền: mỗi tiêu chí đối chiếu
/// độc lập thành MATCH / NOT_MATCH / UNKNOWN; thiếu dữ liệu catalog là
/// UNKNOWN (không tính là đạt, không loại máy). Mọi model đều có trong kết
/// quả, sắp: Phù hợp cao → Có thể phù hợp → Chưa đáp ứng đủ.
abstract final class EquipmentSelectionService {
  /// [requirements]: khoá tiêu chí → giá trị yêu cầu (String cho tiêu chí
  /// choice, double đã quy về đơn vị gốc cho tiêu chí số). Tiêu chí không có
  /// trong map thì không đối chiếu.
  static List<EquipmentMatch> evaluate({
    required List<SelectorCriterion> criteria,
    required Map<String, Object> requirements,
    required List<EquipmentMachine> machines,
    Map<String, EquipmentSeries> seriesByCode = const {},
  }) {
    final active = [
      for (final c in criteria)
        if (requirements.containsKey(c.key)) c,
    ];
    final results = <EquipmentMatch>[];
    for (final machine in machines) {
      final items = [
        for (final c in active) _evaluate(c, requirements[c.key]!, machine),
      ];
      results.add(
        EquipmentMatch(
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

  static GrindingCriterionResult _evaluate(
    SelectorCriterion c,
    Object required,
    EquipmentMachine machine,
  ) {
    final value = machine.selection[c.key];
    final unknownReason =
        machine.selectionNotes[c.key] ??
        'Catalog chưa có dữ liệu ${c.label.toLowerCase()} cho model này.';
    GrindingCriterionResult unknown(String requiredDisplay) =>
        GrindingCriterionResult(
          label: c.label,
          status: GrindingCriterionStatus.unknown,
          requiredDisplay: requiredDisplay,
          reason: unknownReason,
        );
    GrindingCriterionResult result(
      bool ok,
      String requiredDisplay,
      String actual,
      String reason,
    ) => GrindingCriterionResult(
      label: c.label,
      status: ok
          ? GrindingCriterionStatus.match
          : GrindingCriterionStatus.notMatch,
      requiredDisplay: requiredDisplay,
      actualDisplay: actual,
      reason: reason,
    );

    if (c.type == SelectorCriterionType.choice) {
      final option = required as String;
      final requiredDisplay = c.labelOf(option);
      final options = value?.options;
      if (options == null || options.isEmpty) return unknown(requiredDisplay);
      final ok = options.contains(option);
      return result(
        ok,
        requiredDisplay,
        options.map(c.labelOf).join(', '),
        ok
            ? 'Model đáp ứng: ${requiredDisplay.toLowerCase()}.'
            : 'Catalog không ghi model này dùng cho '
                  '"${requiredDisplay.toLowerCase()}".',
      );
    }

    final v = required as double;
    final unit = value?.unit;
    switch (c.type) {
      case SelectorCriterionType.range:
        final requiredDisplay = formatValue(c, v, unit);
        final max = value?.max;
        if (max == null) return unknown(requiredDisplay);
        final min = value!.min;
        final tooLow = min != null && v < min;
        final tooHigh = v > max;
        return result(
          !tooLow && !tooHigh,
          requiredDisplay,
          min == null
              ? '≤ ${formatValue(c, max, unit)}'
              : formatRange(c, min, max, unit),
          tooHigh
              ? 'Vượt mức tối đa của model.'
              : tooLow
              ? 'Nhỏ hơn mức tối thiểu của model.'
              : 'Nằm trong dải của model.',
        );
      case SelectorCriterionType.atLeast:
        final requiredDisplay = '≥ ${formatValue(c, v, unit)}';
        final max = value?.max;
        if (max != null) {
          final ok = max >= v;
          final note = c.matchNote == null ? '' : ' (${c.matchNote})';
          return result(
            ok,
            requiredDisplay,
            value!.min == null || value.min == max
                ? formatValue(c, max, unit)
                : formatRange(c, value.min!, max, unit),
            ok
                ? 'Model đáp ứng mức yêu cầu$note.'
                : 'Mức tối đa của model thấp hơn yêu cầu.',
          );
        }
        // Chỉ biết giới hạn trên (VD tổng dung tích thùng): vượt giới hạn
        // chắc chắn không đạt, còn lại chưa đủ dữ liệu để kết luận.
        final limit = value?.limit;
        if (limit != null && v > limit) {
          return result(
            false,
            requiredDisplay,
            '≤ ${formatValue(c, limit, unit)}',
            'Vượt giới hạn tối đa của model.',
          );
        }
        return unknown(requiredDisplay);
      case SelectorCriterionType.atMost:
        final requiredDisplay = '≤ ${formatValue(c, v, unit)}';
        final actual = value?.max;
        if (actual == null) return unknown(requiredDisplay);
        final ok = actual <= v;
        return result(
          ok,
          requiredDisplay,
          formatValue(c, actual, unit),
          ok ? 'Trong giới hạn cho phép.' : 'Vượt giới hạn cho phép.',
        );
      case SelectorCriterionType.choice:
        throw StateError('unreachable');
    }
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

  /// Đơn vị lớn nhất mà giá trị vẫn ≥ 1 (VD 1500 g → "1.5 kg").
  static SelectorUnit? _unitFor(SelectorCriterion c, double v) {
    SelectorUnit? best;
    for (final u in c.units) {
      if (best == null || v >= u.factor) best = u;
    }
    return best;
  }

  /// "500 g", "1.5 kg", "3000 L" — [unitOverride] là đơn vị riêng của
  /// model (không quy đổi).
  static String formatValue(
    SelectorCriterion c,
    double v, [
    String? unitOverride,
  ]) {
    if (unitOverride != null) return '${fmt(v)} $unitOverride';
    final unit = _unitFor(c, v);
    if (unit == null) return fmt(v);
    return '${fmt(v / unit.factor)} ${unit.label}';
  }

  /// Cả dải dùng 1 đơn vị theo mức thấp như catalog: "10 - 2000 g",
  /// "5 - 50 kg".
  static String formatRange(
    SelectorCriterion c,
    double min,
    double max, [
    String? unitOverride,
  ]) {
    if (unitOverride != null) return '${fmt(min)} - ${fmt(max)} $unitOverride';
    final unit = _unitFor(c, min);
    if (unit == null) return '${fmt(min)} - ${fmt(max)}';
    return '${fmt(min / unit.factor)} - ${fmt(max / unit.factor)} '
        '${unit.label}';
  }

  static String fmt(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}
