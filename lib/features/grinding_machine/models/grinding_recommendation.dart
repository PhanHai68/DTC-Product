import 'grinding_machine.dart';
import 'grinding_series.dart';

/// Kết quả đề xuất 1 model — điểm số + lý do + cảnh báo, hoàn toàn dựa trên
/// dữ liệu database thật (xem GrindingSelectionEngine).
class GrindingRecommendation {
  const GrindingRecommendation({
    required this.machine,
    this.series,
    required this.score,
    required this.isStrongCandidate,
    this.reasons = const [],
    this.warnings = const [],
  });

  final GrindingMachine machine;
  final GrindingSeries? series;

  /// 0-100.
  final double score;
  final bool isStrongCandidate;
  final List<String> reasons;
  final List<String> warnings;
}
