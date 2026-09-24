import '../../../models/technical_conversion.dart';

/// Quy đổi xấp xỉ mesh ↔ micron dựa trên bảng chuẩn ASTM đã có sẵn trong
/// app (`TechnicalConversionData.meshList`, dùng chung với "Chuyển đổi đơn
/// vị") — nội suy tuyến tính giữa 2 mốc gần nhất, KHÔNG áp dụng cho đơn vị
/// "mm" (kích thước nghiền thô, không cùng bản chất với mesh/micron nghiền
/// mịn) theo đúng yêu cầu mục 6 "xây dựng utility chuyển đổi mesh/micron".
abstract final class GrindingFinenessConverter {
  static List<(double mesh, double micron)>? _table;

  static List<(double mesh, double micron)> _sortedTable() {
    return _table ??= TechnicalConversionData.meshList
        .map((item) => (double.parse(item.mesh), double.parse(item.micron)))
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
  }

  /// Micron xấp xỉ ứng với 1 giá trị mesh (mesh càng lớn -> micron càng
  /// nhỏ, quan hệ nghịch nên nội suy theo mesh rồi suy ra micron).
  static double meshToMicron(double mesh) {
    final table = _sortedTable();
    if (mesh <= table.first.$1) return table.first.$2;
    if (mesh >= table.last.$1) return table.last.$2;
    for (var i = 0; i < table.length - 1; i++) {
      final (m0, u0) = table[i];
      final (m1, u1) = table[i + 1];
      if (mesh >= m0 && mesh <= m1) {
        final t = (mesh - m0) / (m1 - m0);
        return u0 + (u1 - u0) * t;
      }
    }
    return table.last.$2;
  }

  /// Mesh xấp xỉ ứng với 1 giá trị micron.
  static double micronToMesh(double micron) {
    final table = _sortedTable();
    // table đang sắp theo mesh tăng dần -> micron GIẢM dần; đảo ngược để có
    // danh sách micron TĂNG dần, biên đầu là micron nhỏ nhất (mesh lớn nhất).
    final byMicron = table.reversed.toList();
    if (micron <= byMicron.first.$2) return byMicron.first.$1;
    if (micron >= byMicron.last.$2) return byMicron.last.$1;
    for (var i = 0; i < byMicron.length - 1; i++) {
      final (m0, u0) = byMicron[i];
      final (m1, u1) = byMicron[i + 1];
      if (micron >= u0 && micron <= u1) {
        final t = (micron - u0) / (u1 - u0);
        return m0 + (m1 - m0) * t;
      }
    }
    return byMicron.last.$1;
  }
}
