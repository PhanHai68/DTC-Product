/// Bỏ dấu tiếng Việt để tìm kiếm: "Động cơ quá nhiệt" -> "dong co qua nhiet".
///
/// Dùng cho cột văn bản tìm kiếm (FTS) và cho chuỗi người dùng gõ vào, để
/// gõ có dấu hay không dấu đều ra cùng kết quả.
abstract final class VietnameseFold {
  static const _accented =
      'àáạảãâầấậẩẫăằắặẳẵ'
      'èéẹẻẽêềếệểễ'
      'ìíịỉĩ'
      'òóọỏõôồốộổỗơờớợởỡ'
      'ùúụủũưừứựửữ'
      'ỳýỵỷỹ'
      'đ';
  static const _plain =
      'aaaaaaaaaaaaaaaaa'
      'eeeeeeeeeee'
      'iiiii'
      'ooooooooooooooooo'
      'uuuuuuuuuuu'
      'yyyyy'
      'd';

  // Dấu kết hợp (khi chuỗi ở dạng tổ hợp NFD, VD gõ từ một số bàn phím):
  // huyền, sắc, ngã, hỏi, nặng, mũ, trăng, móc.
  static final _combiningMarks = RegExp(
    '[${String.fromCharCodes(const [0x0300, 0x0301, 0x0303, 0x0309, 0x0323, 0x0302, 0x0306, 0x031B])}]',
  );
  static final _spaces = RegExp(r'\s+');

  /// Chữ thường, bỏ dấu, gộp khoảng trắng. Giữ nguyên ký tự khác.
  static String fold(String input) {
    final lower = input.toLowerCase().replaceAll(_combiningMarks, '');
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      final index = _accented.indexOf(char);
      buffer.write(index >= 0 ? _plain[index] : char);
    }
    return buffer.toString().replaceAll(_spaces, ' ').trim();
  }

  /// Các từ khóa tìm kiếm: chỉ giữ chữ/số Latin sau khi bỏ dấu.
  /// "Động cơ (E-102)" -> ["dong", "co", "e", "102"].
  static List<String> tokens(String input) =>
      fold(input)
          .split(RegExp(r'[^a-z0-9]+'))
          .where((token) => token.isNotEmpty)
          .toList();

  /// Khóa so sánh tên gần giống: bỏ dấu, bỏ mọi ký tự không phải chữ/số.
  /// "SC16 Pro" và "sc16pro" cùng khóa "sc16pro".
  static String compactKey(String input) => tokens(input).join();
}
