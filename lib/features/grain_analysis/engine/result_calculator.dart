import '../models/grain.dart';

/// Các công thức tổng hợp kết quả (mục 8 tài liệu yêu cầu) — giai đoạn 1:
/// tỉ lệ theo số hạt và theo diện tích.
abstract final class GrainResultCalculator {
  /// Tổng số hạt (bỏ vật thể đã xóa; cụm tính theo số hạt ước tính).
  static int countOf(Iterable<Grain> grains) =>
      grains.fold(0, (sum, g) => sum + g.countedGrains);

  /// Tổng diện tích hạt: mm² nếu có [pixelsPerMm], ngược lại pixel².
  static double areaOf(Iterable<Grain> grains, double? pixelsPerMm) {
    var px = 0.0;
    for (final g in grains) {
      if (!g.removed) px += g.areaPx;
    }
    return pixelsPerMm == null ? px : px / (pixelsPerMm * pixelsPerMm);
  }

  /// P = 100 · part / total (chưa làm tròn); total = 0 thì trả 0.
  static double percent(num part, num total) =>
      total == 0 ? 0 : 100 * part / total;

  /// Kết quả của phiên đếm hạt thường: một dòng cho cả mẫu.
  static List<ClassResult> countResults(Iterable<Grain> grains) => [
    ClassResult(
      classId: ClassResult.allId,
      grainCount: countOf(grains),
      countPercent: 100,
      areaPercent: 100,
    ),
  ];

  /// Đếm nhanh không cần hồ sơ (luồng C, FR-06): so ảnh nhóm đã tách tay
  /// với ảnh cả mẫu. Diện tích so theo mm² khi cả hai ảnh có pixelsPerMm;
  /// ngược lại so theo pixel (giả định chụp cùng khoảng cách).
  static QuickCountResult quickCount({
    required Iterable<Grain> wholeGrains,
    required double? wholePixelsPerMm,
    required Iterable<Grain> groupGrains,
    required double? groupPixelsPerMm,
  }) {
    final byMm = wholePixelsPerMm != null && groupPixelsPerMm != null;
    final wholeCount = countOf(wholeGrains);
    final groupCount = countOf(groupGrains);
    final wholeArea = areaOf(wholeGrains, byMm ? wholePixelsPerMm : null);
    final groupArea = areaOf(groupGrains, byMm ? groupPixelsPerMm : null);
    return QuickCountResult(
      wholeCount: wholeCount,
      groupCount: groupCount,
      countPercent: percent(groupCount, wholeCount),
      areaPercent: percent(groupArea, wholeArea),
      areaInMm: byMm,
    );
  }

  /// Làm tròn các tỉ lệ đến [decimals] chữ số để hiển thị, sao cho tổng
  /// bằng đúng tổng đã làm tròn của dữ liệu gốc (thường là 100,0). Chênh
  /// lệch do làm tròn dồn vào phần tử lớn nhất (mục 8, "Làm tròn").
  static List<double> roundForDisplay(List<double> values, {int decimals = 1}) {
    if (values.isEmpty) return const [];
    var factor = 1;
    for (var i = 0; i < decimals; i++) {
      factor *= 10;
    }
    final units = [for (final v in values) (v * factor).round()];
    final targetUnits = (values.fold(0.0, (a, b) => a + b) * factor).round();
    final diff = targetUnits - units.fold<int>(0, (a, b) => a + b);
    if (diff != 0) {
      var largest = 0;
      for (var i = 1; i < values.length; i++) {
        if (values[i] > values[largest]) largest = i;
      }
      units[largest] += diff;
    }
    return [for (final u in units) u / factor];
  }
}

class QuickCountResult {
  const QuickCountResult({
    required this.wholeCount,
    required this.groupCount,
    required this.countPercent,
    required this.areaPercent,
    required this.areaInMm,
  });

  final int wholeCount;
  final int groupCount;
  final double countPercent;
  final double areaPercent;

  /// false: % diện tích so theo pixel vì một trong hai ảnh thiếu mốc khay.
  final bool areaInMm;

  /// Hai dòng kết quả: nhóm đã tách và phần còn lại của mẫu.
  List<ClassResult> toClassResults() => [
    ClassResult(
      classId: ClassResult.groupId,
      grainCount: groupCount,
      countPercent: countPercent,
      areaPercent: areaPercent,
    ),
    ClassResult(
      classId: ClassResult.restId,
      grainCount: wholeCount - groupCount,
      countPercent: 100 - countPercent,
      areaPercent: 100 - areaPercent,
    ),
  ];
}
