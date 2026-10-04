/// Nhóm lỗi cố định. Chọn "KHÁC" thì nhập tên nhóm mới; nhóm tự thêm được
/// lấy lại từ các bản ghi đã lưu để hiện trong danh sách chọn và bộ lọc.
abstract final class FaultGroups {
  static const other = 'KHÁC';

  static const fixed = <String>[
    'ĐIỆN NGUỒN',
    'KHÍ NÉN',
    'KÍNH BẢO VỆ',
    'SÚNG',
    'ĐÈN',
    'CAMERA',
    'LCD & MAINBOARD',
    'PHẦN MỀM',
    'CHẾ ĐỘ PHÂN LOẠI',
  ];

  /// Viết hoa, gộp khoảng trắng — để nhóm tự thêm đồng bộ với danh sách cố
  /// định ("băng  tải" -> "BĂNG TẢI").
  static String normalize(String input) =>
      input.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

  /// Danh sách chọn: nhóm cố định, rồi nhóm tự thêm (sắp xếp), cuối cùng
  /// là "KHÁC".
  static List<String> options(Iterable<String> customGroups) {
    final custom =
        customGroups
            .map(normalize)
            .where((g) => g.isNotEmpty && !fixed.contains(g) && g != other)
            .toSet()
            .toList()
          ..sort();
    return [...fixed, ...custom, other];
  }
}
