import '../models/grinding_machine.dart';
import '../models/grinding_recommendation.dart';
import '../models/grinding_selection_request.dart';
import '../models/grinding_series.dart';

/// Toàn bộ dữ liệu cần thiết để chấm điểm — Provider tập hợp từ Repository
/// rồi truyền vào, giữ Engine THUẦN DART (dễ test, không phụ thuộc SQLite).
class GrindingSelectionContext {
  const GrindingSelectionContext({
    required this.machines,
    required this.seriesByCode,
    required this.seriesTags,
    required this.materialScoreAdjustments,
    required this.materialName,
    required this.weights,
  });

  final List<GrindingMachine> machines;
  final Map<String, GrindingSeries> seriesByCode;

  /// seriesCode -> tập Selection Tags của dòng máy đó.
  final Map<String, Set<String>> seriesTags;

  /// seriesCode -> điểm điều chỉnh theo Material_Series_Map (CHỈ các dòng
  /// đã xác minh `status == 'Verified'` cho đúng 1 nguyên liệu đang xét).
  final Map<String, double> materialScoreAdjustments;

  final String materialName;

  /// Trọng số đọc từ bảng `grinding_ai_config` (sheet AI_Config) — KHÔNG
  /// hard-code trong code để sau này cập nhật database là đổi được ngay.
  final Map<String, num> weights;

  num _weight(String key, num fallback) => weights[key] ?? fallback;

  num get capacityWeight => _weight('capacity_weight', 40);
  num get inputSizeWeight => _weight('input_size_weight', 20);
  num get finenessWeight => _weight('fineness_weight', 40);
  num get materialAdjustmentMin => _weight('material_adjustment_min', -30);
  num get materialAdjustmentMax => _weight('material_adjustment_max', 20);
  num get candidateThreshold => _weight('candidate_threshold', 80);
}

/// Selection Engine tất định (mục 8) — implement lại chính xác logic mô tả
/// trong sheet `Selection_Rules`/`AI_Config`/`AI_Selection_Test` của
/// database Excel: capacity + fineness là hard filter (loại nếu không đạt
/// hoặc sai đơn vị), input size chỉ cảnh báo khi database thiếu dữ liệu,
/// material chỉ CỘNG/TRỪ điểm chứ không loại, Selection Tags đặc biệt là
/// hard filter (phải có đủ tag đã chọn). KHÔNG được để AI tự bịa model —
/// engine chỉ chấm điểm và lọc trên model có sẵn trong [context.machines].
abstract final class GrindingSelectionEngine {
  static List<GrindingRecommendation> recommend({
    required GrindingSelectionContext context,
    required GrindingSelectionRequest request,
    int maxResults = 3,
  }) {
    final results = <GrindingRecommendation>[];

    for (final machine in context.machines) {
      final capacityMatch =
          machine.capacityMinKgH != null &&
          machine.capacityMaxKgH != null &&
          request.capacityKgH >= machine.capacityMinKgH! &&
          request.capacityKgH <= machine.capacityMaxKgH!;
      if (!capacityMatch) continue; // TECH_CAPACITY: reject nếu không đạt.

      final finenessMatch =
          machine.finenessUnit == request.finenessUnit &&
          machine.finenessMin != null &&
          machine.finenessMax != null &&
          request.finenessValue >= machine.finenessMin! &&
          request.finenessValue <= machine.finenessMax!;
      if (!finenessMatch) continue; // TECH_FINENESS: reject nếu sai/không đạt.

      final warnings = <String>[];
      var inputMatch = true;
      if (request.inputSizeMm != null) {
        if (machine.inputSizeMaxMm != null) {
          inputMatch = request.inputSizeMm! <= machine.inputSizeMaxMm!;
          if (!inputMatch) continue; // Có dữ liệu và vượt giới hạn -> reject.
        } else {
          // TECH_INPUT: database không có dữ liệu -> không loại, chỉ cảnh báo.
          warnings.add(
            'Database chưa có dữ liệu giới hạn kích thước đầu vào cho model này — '
            'cần xác minh thêm trước khi xác nhận.',
          );
        }
      }

      final tags = context.seriesTags[machine.seriesCode] ?? const {};
      if (request.specialTags.isNotEmpty &&
          !request.specialTags.every(tags.contains)) {
        continue; // Selection Tags: thiếu tag yêu cầu -> reject.
      }

      final rawAdjustment =
          context.materialScoreAdjustments[machine.seriesCode];
      final materialAdjustment = rawAdjustment == null
          ? 0.0
          : rawAdjustment.clamp(
              context.materialAdjustmentMin.toDouble(),
              context.materialAdjustmentMax.toDouble(),
            );
      if (rawAdjustment == null) {
        warnings.add(
          'Database chưa có dữ liệu đã xác minh về mức độ phù hợp giữa '
          '"${context.materialName}" và dòng máy này — kết quả chỉ dựa trên '
          'thông số kỹ thuật (công suất/độ mịn/đầu vào).',
        );
      }

      final technicalScore =
          context.capacityWeight +
          context.finenessWeight +
          (inputMatch ? context.inputSizeWeight : 0);
      final totalScore = (technicalScore + materialAdjustment).clamp(0, 100);

      final reasons = <String>[
        'Công suất yêu cầu (${_fmt(request.capacityKgH)} kg/h) nằm trong dải '
            '${_fmt(machine.capacityMinKgH!)} - ${_fmt(machine.capacityMaxKgH!)} kg/h của model.',
        'Đạt độ mịn yêu cầu (${_fmt(request.finenessValue)} ${request.finenessUnit}) '
            'trong dải ${_fmt(machine.finenessMin!)} - ${_fmt(machine.finenessMax!)} ${machine.finenessUnit}.',
        if (request.inputSizeMm != null && inputMatch && machine.inputSizeMaxMm != null)
          'Kích thước đầu vào (${_fmt(request.inputSizeMm!)} mm) phù hợp giới hạn model.',
        if (materialAdjustment > 0)
          'Phù hợp với nguyên liệu "${context.materialName}" theo dữ liệu đã xác minh.',
        if (request.specialTags.isNotEmpty)
          'Đáp ứng yêu cầu đặc biệt đã chọn.',
      ];

      if (machine.seriesCode == 'BSK_JET') {
        warnings.add(
          'Dòng máy này cần hệ thống khí nén — vui lòng xác minh yêu cầu áp '
          'suất/lưu lượng khí nén trước khi lắp đặt.',
        );
      }
      if (machine.seriesCode == 'BS_CRYOGENIC') {
        warnings.add(
          'Dòng máy này cần nitơ lỏng để vận hành — vui lòng xác nhận điều '
          'kiện cấp nitơ lỏng tại nhà máy.',
        );
      }
      warnings.add(
        'Kết quả là ứng viên kỹ thuật dựa trên database — công suất/độ mịn '
        'thực tế vẫn có thể cần thử mẫu để xác nhận (theo ghi chú catalog).',
      );

      results.add(
        GrindingRecommendation(
          machine: machine,
          series: context.seriesByCode[machine.seriesCode],
          score: totalScore.toDouble(),
          isStrongCandidate: totalScore >= context.candidateThreshold,
          reasons: reasons,
          warnings: warnings,
        ),
      );
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(maxResults).toList();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
