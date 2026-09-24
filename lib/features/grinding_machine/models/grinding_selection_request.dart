/// Yêu cầu khách hàng nhập vào form "Chọn máy phù hợp" (mục 7).
class GrindingSelectionRequest {
  const GrindingSelectionRequest({
    required this.materialId,
    required this.capacityKgH,
    required this.finenessValue,
    required this.finenessUnit,
    this.inputSizeMm,
    this.specialTags = const {},
  });

  final String materialId;

  /// Đã quy đổi sẵn về kg/h (UI cho nhập kg/h hoặc t/h).
  final double capacityKgH;

  final double finenessValue;

  /// 'mm' | 'mesh' | 'µm'.
  final String finenessUnit;

  /// Kích thước nguyên liệu đầu vào — tuỳ chọn, để trống nếu chưa biết.
  final double? inputSizeMm;

  /// Các Selection Tag yêu cầu đặc biệt (lấy từ database, không hard-code).
  final Set<String> specialTags;
}
