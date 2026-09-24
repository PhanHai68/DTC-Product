import 'grinding_machine.dart';
import 'grinding_series.dart';

/// Trạng thái đối chiếu 1 tiêu chí — mục 10: KHÔNG được gộp UNKNOWN vào
/// MATCH hay NOT_MATCH, phải phân biệt rõ cả 3.
enum GrindingCriterionStatus { match, notMatch, unknown }

/// Kết quả đối chiếu 1 tiêu chí (VD "Công suất") cho 1 model — giữ đủ dữ
/// liệu để UI giải thích được lý do cho kỹ sư, không chỉ 1 cờ đúng/sai.
class GrindingCriterionResult {
  const GrindingCriterionResult({
    required this.label,
    required this.status,
    required this.requiredDisplay,
    this.actualDisplay,
    required this.reason,
  });

  final String label;
  final GrindingCriterionStatus status;

  /// Giá trị yêu cầu, đã định dạng — VD "≥ 500 kg/h".
  final String requiredDisplay;

  /// Giá trị thực tế của model, `null` nếu database không có dữ liệu.
  final String? actualDisplay;

  /// Lý do ngắn gọn hiển thị cho kỹ sư — VD "Model đạt công suất yêu cầu.".
  final String reason;
}

/// Nhãn tổng hợp hiển thị UI (mục 11-12) — LUÔN tính từ [criteria], không
/// hard-code theo model/series nào.
enum GrindingMatchLabel {
  /// Mọi tiêu chí đã nhập đều MATCH, không có UNKNOWN/NOT_MATCH.
  strong,

  /// Không có tiêu chí NOT_MATCH nào, nhưng có ít nhất 1 UNKNOWN.
  possible,

  /// Có ít nhất 1 tiêu chí NOT_MATCH — vẫn hiển thị để kỹ sư biết đang thiếu
  /// gì, KHÔNG ẩn khỏi kết quả (mục 13 "Closest matches").
  closest,
}

/// 1 model đã được [GrindingMachineSelectionService] đối chiếu với
/// [GrindingSelectionCriteria] — luôn giữ đủ danh sách [criteria] theo từng
/// tiêu chí, không rút gọn thành 1 boolean tổng.
class GrindingMachineMatch {
  const GrindingMachineMatch({
    required this.machine,
    this.series,
    required this.criteria,
    required this.matchScore,
    required this.label,
  });

  final GrindingMachine machine;
  final GrindingSeries? series;
  final List<GrindingCriterionResult> criteria;

  /// 0-100, chỉ tính trên tiêu chí người dùng đã nhập; UNKNOWN không được
  /// tính là MATCH (mục 11) — điểm chỉ để hỗ trợ sắp xếp, không thay thế
  /// việc hiển thị từng tiêu chí.
  final double matchScore;
  final GrindingMatchLabel label;

  List<GrindingCriterionResult> get matched => criteria
      .where((c) => c.status == GrindingCriterionStatus.match)
      .toList();
  List<GrindingCriterionResult> get notMatched => criteria
      .where((c) => c.status == GrindingCriterionStatus.notMatch)
      .toList();
  List<GrindingCriterionResult> get unknown => criteria
      .where((c) => c.status == GrindingCriterionStatus.unknown)
      .toList();
}
