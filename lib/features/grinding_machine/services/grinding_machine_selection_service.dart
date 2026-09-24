import '../models/grinding_machine.dart';
import '../models/grinding_machine_match.dart';
import '../models/grinding_material_series_map.dart';
import '../models/grinding_selection_criteria.dart';
import '../models/grinding_series.dart';
import '../utils/grinding_fineness_converter.dart';
import '../utils/grinding_format.dart';

/// Selection Service minh bạch (Phase 6, mục 9-11) — khác
/// [GrindingSelectionEngine] (Phase 4): KHÔNG loại model khỏi kết quả chỉ vì
/// thiếu dữ liệu. Mỗi tiêu chí được đối chiếu độc lập thành đúng 1 trong 3
/// trạng thái MATCH / NOT_MATCH / UNKNOWN; 1 tiêu chí NOT_MATCH không được
/// làm mất thông tin của các tiêu chí còn lại. Thuần Dart, không đụng
/// database — Provider/UI tự tập hợp [machines]/[seriesByCode]/[seriesTags]/
/// [materialSeriesMap] rồi truyền vào.
abstract final class GrindingMachineSelectionService {
  static List<GrindingMachineMatch> evaluate({
    required GrindingSelectionCriteria criteria,
    required List<GrindingMachine> machines,
    Map<String, GrindingSeries> seriesByCode = const {},

    /// seriesCode -> tập Selection Tags của dòng máy — dùng đối chiếu
    /// [GrindingSelectionCriteria.application].
    Map<String, Set<String>> seriesTags = const {},

    /// Toàn bộ dòng Material_Series_Map ứng với
    /// [GrindingSelectionCriteria.materialId] (mọi status, service tự lọc
    /// `Verified`) — truyền rỗng nếu không chọn material từ database.
    List<GrindingMaterialSeriesMap> materialSeriesMap = const [],
  }) {
    final verifiedBySeries = {
      for (final m in materialSeriesMap)
        if (m.isVerified) m.seriesCode: m,
    };

    final results = <GrindingMachineMatch>[];
    for (final machine in machines) {
      final criteriaResults = <GrindingCriterionResult>[
        if (criteria.capacityKgH != null) _capacity(machine, criteria),
        if (criteria.finenessValue != null && criteria.finenessUnit != null)
          _fineness(machine, criteria),
        if (criteria.maxMotorKw != null) _motor(machine, criteria),
        if (criteria.feedSizeMm != null) _feedSize(machine, criteria),
        if (criteria.materialId != null)
          _material(machine, criteria, verifiedBySeries),
        if (criteria.application != null &&
            criteria.application!.trim().isNotEmpty)
          _application(machine, criteria, seriesTags),
      ];

      results.add(
        GrindingMachineMatch(
          machine: machine,
          series: seriesByCode[machine.seriesCode],
          criteria: criteriaResults,
          matchScore: _score(criteriaResults),
          label: _label(criteriaResults),
        ),
      );
    }

    results.sort((a, b) {
      final byLabel = a.label.index.compareTo(b.label.index);
      if (byLabel != 0) return byLabel;
      final byNotMatch = a.notMatched.length.compareTo(b.notMatched.length);
      if (byNotMatch != 0) return byNotMatch;
      final byScore = b.matchScore.compareTo(a.matchScore);
      if (byScore != 0) return byScore;
      return a.machine.model.compareTo(b.machine.model);
    });
    return results;
  }

  // ---------------------------------------------------------------------
  // Từng tiêu chí — mỗi hàm trả về ĐÚNG 1 GrindingCriterionResult, không
  // bao giờ throw/loại máy khỏi danh sách.
  // ---------------------------------------------------------------------

  static GrindingCriterionResult _capacity(
    GrindingMachine machine,
    GrindingSelectionCriteria criteria,
  ) {
    final required = criteria.capacityKgH!;
    final actual = machine.capacityMaxKgH ?? machine.capacityMinKgH;
    final requiredDisplay = '≥ ${_fmt(required)} kg/h';
    if (actual == null) {
      return GrindingCriterionResult(
        label: 'Công suất',
        status: GrindingCriterionStatus.unknown,
        requiredDisplay: requiredDisplay,
        reason: 'Database chưa có dữ liệu công suất cho model này.',
      );
    }
    final isMatch = actual >= required;
    return GrindingCriterionResult(
      label: 'Công suất',
      status: isMatch
          ? GrindingCriterionStatus.match
          : GrindingCriterionStatus.notMatch,
      requiredDisplay: requiredDisplay,
      actualDisplay: GrindingFormat.capacityRange(machine),
      reason: isMatch
          ? 'Model đạt công suất yêu cầu (${_fmt(required)} kg/h).'
          : 'Công suất model thấp hơn yêu cầu (${_fmt(required)} kg/h).',
    );
  }

  static GrindingCriterionResult _fineness(
    GrindingMachine machine,
    GrindingSelectionCriteria criteria,
  ) {
    final requiredValue = criteria.finenessValue!;
    final requiredUnit = criteria.finenessUnit!;
    final requiredDisplay = '${_fmt(requiredValue)} $requiredUnit';
    final unit = machine.finenessUnit;
    final min = machine.finenessMin;
    final max = machine.finenessMax;
    if (unit == null || min == null || max == null) {
      return GrindingCriterionResult(
        label: 'Độ mịn',
        status: GrindingCriterionStatus.unknown,
        requiredDisplay: requiredDisplay,
        reason: 'Database chưa có dữ liệu độ mịn cho model này.',
      );
    }
    double? converted;
    if (unit == requiredUnit) {
      converted = requiredValue;
    } else if (unit == 'mesh' && requiredUnit == 'µm') {
      converted = GrindingFinenessConverter.micronToMesh(requiredValue);
    } else if (unit == 'µm' && requiredUnit == 'mesh') {
      converted = GrindingFinenessConverter.meshToMicron(requiredValue);
    }
    if (converted == null) {
      // Đơn vị 'mm' (nghiền thô) không quy đổi chéo với mesh/µm — không đủ
      // dữ liệu để so sánh chính xác, không suy đoán.
      return GrindingCriterionResult(
        label: 'Độ mịn',
        status: GrindingCriterionStatus.unknown,
        requiredDisplay: requiredDisplay,
        actualDisplay: GrindingFormat.finenessRange(machine),
        reason:
            'Không thể quy đổi chính xác giữa đơn vị "$requiredUnit" và '
            '"$unit" của model này.',
      );
    }
    final isMatch = converted >= min && converted <= max;
    return GrindingCriterionResult(
      label: 'Độ mịn',
      status: isMatch
          ? GrindingCriterionStatus.match
          : GrindingCriterionStatus.notMatch,
      requiredDisplay: requiredDisplay,
      actualDisplay: GrindingFormat.finenessRange(machine),
      reason: isMatch
          ? 'Đạt độ mịn yêu cầu ($requiredDisplay).'
          : 'Độ mịn yêu cầu ($requiredDisplay) nằm ngoài dải model đạt được.',
    );
  }

  static GrindingCriterionResult _motor(
    GrindingMachine machine,
    GrindingSelectionCriteria criteria,
  ) {
    final required = criteria.maxMotorKw!;
    final actual = machine.mainMotorKwMax ?? machine.mainMotorKwMin;
    final requiredDisplay = '≤ ${_fmt(required)} kW';
    if (actual == null) {
      return GrindingCriterionResult(
        label: 'Công suất động cơ',
        status: GrindingCriterionStatus.unknown,
        requiredDisplay: requiredDisplay,
        reason: 'Database chưa có dữ liệu công suất động cơ cho model này.',
      );
    }
    final isMatch = actual <= required;
    return GrindingCriterionResult(
      label: 'Công suất động cơ',
      status: isMatch
          ? GrindingCriterionStatus.match
          : GrindingCriterionStatus.notMatch,
      requiredDisplay: requiredDisplay,
      actualDisplay: GrindingFormat.motorRange(machine),
      reason: isMatch
          ? 'Công suất động cơ trong giới hạn cho phép (${_fmt(required)} kW).'
          : 'Công suất động cơ vượt giới hạn cho phép (${_fmt(required)} kW).',
    );
  }

  static GrindingCriterionResult _feedSize(
    GrindingMachine machine,
    GrindingSelectionCriteria criteria,
  ) {
    final required = criteria.feedSizeMm!;
    final actual = machine.inputSizeMaxMm;
    final requiredDisplay = '${_fmt(required)} mm';
    if (actual == null) {
      return GrindingCriterionResult(
        label: 'Kích thước đầu vào',
        status: GrindingCriterionStatus.unknown,
        requiredDisplay: requiredDisplay,
        reason:
            'Database chưa có dữ liệu giới hạn kích thước đầu vào cho model này.',
      );
    }
    final isMatch = required <= actual;
    return GrindingCriterionResult(
      label: 'Kích thước đầu vào',
      status: isMatch
          ? GrindingCriterionStatus.match
          : GrindingCriterionStatus.notMatch,
      requiredDisplay: requiredDisplay,
      actualDisplay: GrindingFormat.inputSize(machine),
      reason: isMatch
          ? 'Kích thước nguyên liệu đầu vào phù hợp giới hạn model.'
          : 'Kích thước nguyên liệu đầu vào vượt giới hạn model.',
    );
  }

  static GrindingCriterionResult _material(
    GrindingMachine machine,
    GrindingSelectionCriteria criteria,
    Map<String, GrindingMaterialSeriesMap> verifiedBySeries,
  ) {
    final name = criteria.materialName ?? criteria.materialId!;
    final requiredDisplay = name;
    final entry = verifiedBySeries[machine.seriesCode];
    if (entry == null) {
      return GrindingCriterionResult(
        label: 'Nguyên liệu',
        status: GrindingCriterionStatus.unknown,
        requiredDisplay: requiredDisplay,
        reason:
            'Database chưa có dữ liệu đã xác minh về mức độ phù hợp giữa '
            '"$name" và dòng máy này.',
      );
    }
    final isMatch = entry.scoreAdjustment >= 0;
    return GrindingCriterionResult(
      label: 'Nguyên liệu',
      status: isMatch
          ? GrindingCriterionStatus.match
          : GrindingCriterionStatus.notMatch,
      requiredDisplay: requiredDisplay,
      actualDisplay: entry.reasonVi,
      reason: isMatch
          ? 'Phù hợp với nguyên liệu "$name" theo dữ liệu đã xác minh.'
          : 'Dữ liệu đã xác minh cho thấy dòng máy này không phù hợp với '
                '"$name".',
    );
  }

  static GrindingCriterionResult _application(
    GrindingMachine machine,
    GrindingSelectionCriteria criteria,
    Map<String, Set<String>> seriesTags,
  ) {
    final application = criteria.application!.trim();
    final requiredDisplay = application;
    final tags = seriesTags[machine.seriesCode];
    if (tags == null || tags.isEmpty) {
      return GrindingCriterionResult(
        label: 'Ứng dụng',
        status: GrindingCriterionStatus.unknown,
        requiredDisplay: requiredDisplay,
        reason: 'Database chưa ghi nhận Selection Tag nào cho dòng máy này.',
      );
    }
    final query = application.toLowerCase();
    final isMatch = tags.any((tag) {
      final tagLower = tag.toLowerCase();
      final labelLower = GrindingFormat.tagLabel(tag).toLowerCase();
      return tagLower == query ||
          labelLower == query ||
          tagLower.contains(query) ||
          query.contains(tagLower);
    });
    return GrindingCriterionResult(
      label: 'Ứng dụng',
      status: isMatch
          ? GrindingCriterionStatus.match
          : GrindingCriterionStatus.notMatch,
      requiredDisplay: requiredDisplay,
      actualDisplay: tags.map(GrindingFormat.tagLabel).join(', '),
      reason: isMatch
          ? 'Dòng máy có Selection Tag phù hợp ứng dụng "$application".'
          : 'Selection Tag của dòng máy chưa ghi nhận ứng dụng "$application".',
    );
  }

  // ---------------------------------------------------------------------

  static double _score(List<GrindingCriterionResult> criteria) {
    if (criteria.isEmpty) return 0;
    final matched = criteria
        .where((c) => c.status == GrindingCriterionStatus.match)
        .length;
    return matched / criteria.length * 100;
  }

  static GrindingMatchLabel _label(List<GrindingCriterionResult> criteria) {
    final hasNotMatch = criteria.any(
      (c) => c.status == GrindingCriterionStatus.notMatch,
    );
    if (hasNotMatch) return GrindingMatchLabel.closest;
    final hasUnknown = criteria.any(
      (c) => c.status == GrindingCriterionStatus.unknown,
    );
    return hasUnknown ? GrindingMatchLabel.possible : GrindingMatchLabel.strong;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
