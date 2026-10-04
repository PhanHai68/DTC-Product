/// Thời gian xử lý: nhập và hiển thị theo GIỜ (VD "1,5"), lưu trong
/// database theo phút (`duration_minutes`) để bản ghi cũ không phải đổi.
abstract final class FaultDuration {
  /// "1,5" / "1.5" / "2" -> số phút (90 / 90 / 120). Rỗng hoặc sai -> null.
  static int? parseHours(String input) {
    final text = input.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    final hours = double.tryParse(text);
    if (hours == null || hours <= 0) return null;
    return (hours * 60).round();
  }

  /// Số phút -> số giờ dạng chữ, dấu phẩy thập phân, tối đa 2 chữ số lẻ:
  /// 90 -> "1,5", 120 -> "2", 20 -> "0,33".
  static String hoursText(int minutes) {
    final text = (minutes / 60).toStringAsFixed(2);
    final trimmed = text.contains('.')
        ? text.replaceFirst(RegExp(r'\.?0+$'), '')
        : text;
    return trimmed.replaceAll('.', ',');
  }

  /// 90 -> "1,5 giờ".
  static String label(int minutes) => '${hoursText(minutes)} giờ';

  /// Số giờ (thập phân) cho ô số trong Excel.
  static double hours(int minutes) =>
      double.parse((minutes / 60).toStringAsFixed(2));
}
