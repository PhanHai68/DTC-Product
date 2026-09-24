/// Parse số dùng chung cho mọi form nhập tay trong module (Phase 11, mục
/// 22) — trước đây logic `double.tryParse(text.trim().replaceAll(',', '.'))`
/// bị lặp lại ở nhiều màn hình (Selector/Proposal Editor/Filter/List).
///
/// Quy ước GIỮ NGUYÊN hành vi cũ đã có từ Phase 1-10: dấu `,` được hiểu là
/// dấu thập phân (thay bằng `.`) — KHÔNG hỗ trợ `,` làm dấu phân cách hàng
/// nghìn (VD `"1,000"` sẽ ra `1.0`, không phải `1000`) vì đó là hành vi có
/// sẵn của toàn bộ form hiện tại; đổi sang hỗ trợ hàng nghìn sẽ tạo ambiguity
/// (không rõ `,` là thập phân hay hàng nghìn) và có nguy cơ đổi hành vi các
/// input đã hoạt động đúng — ngoài phạm vi Phase 11 ("không over-engineer
/// locale").
abstract final class GrindingNumberParser {
  /// `null` nếu rỗng, không parse được, hoặc kết quả NaN/Infinity (input
  /// dạng `"nan"`/`"infinity"` mà `double.tryParse` của Dart chấp nhận theo
  /// spec nhưng không có ý nghĩa nghiệp vụ ở đây).
  static double? parseDouble(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final value = double.tryParse(trimmed.replaceAll(',', '.'));
    if (value == null || value.isNaN || value.isInfinite) return null;
    return value;
  }

  /// `null` nếu rỗng hoặc không parse được. Không nhận số thập phân (dùng
  /// [parseDouble] rồi làm tròn ở caller nếu cần) — giữ đúng ngữ nghĩa số
  /// nguyên (VD số ngày hiệu lực).
  static int? parseInt(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }
}
