/// Yêu cầu khách hàng nhập vào màn "Machine Selector" (Phase 6, mục 8) —
/// khác [GrindingSelectionRequest] (Phase 4, dùng cho GrindingSelectionEngine
/// cũ, mọi field required + hard filter): ở đây MỌI field đều optional, vì
/// GrindingMachineSelectionService (mục 9-10) không loại máy khỏi kết quả
/// chỉ vì thiếu dữ liệu — chỉ đánh dấu UNKNOWN cho đúng tiêu chí không kiểm
/// tra được, các tiêu chí khác vẫn được đối chiếu bình thường.
class GrindingSelectionCriteria {
  const GrindingSelectionCriteria({
    this.materialId,
    this.materialName,
    this.capacityKgH,
    this.finenessValue,
    this.finenessUnit,
    this.feedSizeMm,
    this.maxMotorKw,
    this.application,
    this.notes,
  });

  /// Chọn từ danh sách nguyên liệu database — chỉ khi có [materialId] mới
  /// đối chiếu được với Material_Series_Map (dữ liệu đã xác minh).
  final String? materialId;

  /// Tên hiển thị tương ứng [materialId], hoặc do người dùng tự nhập tự do
  /// (không khớp material nào trong database) — chỉ để hiển thị lại, không
  /// dùng để đối chiếu.
  final String? materialName;

  final double? capacityKgH;
  final double? finenessValue;

  /// 'mm' | 'mesh' | 'µm' — bắt buộc đi kèm [finenessValue].
  final String? finenessUnit;

  final double? feedSizeMm;
  final double? maxMotorKw;

  /// Ứng dụng/quy trình — đối chiếu với Selection Tags của dòng máy.
  final String? application;

  final String? notes;
}
