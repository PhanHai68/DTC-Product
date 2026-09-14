/// Enum mức độ phù hợp của máy với yêu cầu
enum MatchLevel {
  /// Đáp ứng tất cả điều kiện, công suất gần nhất với yêu cầu
  bestMatch,

  /// Đáp ứng tất cả điều kiện, dư công suất < 50%
  suitable,

  /// Đáp ứng tất cả điều kiện, nhưng dư công suất ≥ 50%
  oversized,

  /// Không đáp ứng ít nhất một điều kiện bắt buộc
  notSuitable,
}

extension MatchLevelExtension on MatchLevel {
  String get label {
    switch (this) {
      case MatchLevel.bestMatch:
        return 'BEST MATCH';
      case MatchLevel.suitable:
        return 'SUITABLE';
      case MatchLevel.oversized:
        return 'OVERSIZED';
      case MatchLevel.notSuitable:
        return 'NOT SUITABLE';
    }
  }

  String get labelVi {
    switch (this) {
      case MatchLevel.bestMatch:
        return 'PHÙ HỢP NHẤT';
      case MatchLevel.suitable:
        return 'PHÙ HỢP';
      case MatchLevel.oversized:
        return 'DƯ CÔNG SUẤT';
      case MatchLevel.notSuitable:
        return 'KHÔNG PHÙ HỢP';
    }
  }

  int get sortPriority {
    switch (this) {
      case MatchLevel.bestMatch:
        return 0;
      case MatchLevel.suitable:
        return 1;
      case MatchLevel.oversized:
        return 2;
      case MatchLevel.notSuitable:
        return 3;
    }
  }

  int get starCount {
    switch (this) {
      case MatchLevel.bestMatch:
        return 5;
      case MatchLevel.suitable:
        return 4;
      case MatchLevel.oversized:
        return 3;
      case MatchLevel.notSuitable:
        return 1;
    }
  }
}

/// Kết quả match của một model máy với yêu cầu người dùng
class MachineMatchResult {
  final dynamic machine; // PackingMachine (tránh circular import)
  final MatchLevel matchLevel;

  /// Danh sách lý do phù hợp (dạng "✓ Phù hợp túi PE")
  final List<String> matchReasons;

  /// Danh sách lý do không phù hợp (dạng "✗ Không phù hợp khối lượng 10kg")
  final List<String> mismatchReasons;

  /// Score để sort trong cùng level (capacity gần nhất = score cao nhất)
  final double score;

  const MachineMatchResult({
    required this.machine,
    required this.matchLevel,
    required this.matchReasons,
    required this.mismatchReasons,
    required this.score,
  });
}
