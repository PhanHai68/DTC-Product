import 'dart:math' as math;

/// Năng suất của máy với một dải kích thước hạt, đọc từ `capacity_display`
/// (dạng `0.7–1.2 mm: 5–7 t/h`, mỗi dải một dòng).
class MineralSizeBand {
  final double minMm;
  final double maxMm;
  final double minTph;
  final double maxTph;

  const MineralSizeBand(this.minMm, this.maxMm, this.minTph, this.maxTph);
}

final _bandPattern = RegExp(
  r'([\d.]+)\s*[–-]\s*([\d.]+)\s*mm\s*:\s*([\d.]+)\s*[–-]\s*([\d.]+)\s*t/h',
);

List<MineralSizeBand> parseMineralBands(String? capacityDisplay) {
  return [
    for (final match in _bandPattern.allMatches(capacityDisplay ?? ''))
      MineralSizeBand(
        double.parse(match.group(1)!),
        double.parse(match.group(2)!),
        double.parse(match.group(3)!),
        double.parse(match.group(4)!),
      ),
  ]..sort((a, b) => a.minMm.compareTo(b.minMm));
}

enum StoneCondition { dry, wet }

class MineralSelectionRequest {
  final double minMm;
  final double maxMm;
  final double tonsPerHour;
  final StoneCondition condition;

  const MineralSelectionRequest({
    required this.minMm,
    required this.maxMm,
    required this.tonsPerHour,
    required this.condition,
  });
}

enum MineralFit {
  /// Một máy đáp ứng đúng sản lượng.
  fits,

  /// Một máy dư công suất so với nhu cầu.
  oversized,

  /// Cần nhiều máy chạy song song.
  multiple,
}

class MineralMachineMatch {
  final Map<String, String> spec;

  /// Các dải kích thước của máy nằm trong yêu cầu.
  final List<MineralSizeBand> bands;

  /// Năng suất một máy với dải yêu cầu (dải khó nhất quyết định).
  final double minTph;
  final double maxTph;
  final int machineCount;
  final MineralFit fit;

  const MineralMachineMatch({
    required this.spec,
    required this.bands,
    required this.minTph,
    required this.maxTph,
    required this.machineCount,
    required this.fit,
  });

  String get model => spec['model'] ?? '';
}

/// Máy dùng được cho đá ướt: loại đá có chữ "ướt" (dòng "Đá ướt & khô").
bool mineralHandlesWetStone(Map<String, String> spec) =>
    (spec['stone_type'] ?? '').toLowerCase().contains('ướt');

const _eps = 1e-9;

/// Chọn máy theo tình trạng đá, dải kích thước hạt và sản lượng cần. Máy
/// phải phủ liên tục cả dải yêu cầu; kết quả xếp: vừa đúng nhu cầu (máy nhỏ
/// nhất trước) → dư công suất → cần nhiều máy (ít máy trước).
List<MineralMachineMatch> selectMineralSorters(
  List<Map<String, String>> specs,
  MineralSelectionRequest request,
) {
  final matches = <MineralMachineMatch>[];
  for (final spec in specs) {
    if (request.condition == StoneCondition.wet &&
        !mineralHandlesWetStone(spec)) {
      continue;
    }
    final overlapping = [
      for (final band in parseMineralBands(spec['capacity_display']))
        if (band.minMm <= request.maxMm + _eps &&
            band.maxMm >= request.minMm - _eps)
          band,
    ];
    if (overlapping.isEmpty) continue;

    // Phủ liên tục từ minMm đến maxMm, không có khoảng trống giữa các dải.
    var reached = request.minMm;
    var covered = true;
    for (final band in overlapping) {
      if (band.minMm > reached + _eps) {
        covered = false;
        break;
      }
      reached = math.max(reached, band.maxMm);
    }
    if (!covered || reached < request.maxMm - _eps) continue;

    final minTph = overlapping.map((b) => b.minTph).reduce(math.min);
    final maxTph = overlapping.map((b) => b.maxTph).reduce(math.min);
    final demand = request.tonsPerHour;
    final MineralFit fit;
    final int count;
    if (demand > maxTph + _eps) {
      fit = MineralFit.multiple;
      count = (demand / maxTph - _eps).ceil();
    } else {
      fit = demand < minTph - _eps ? MineralFit.oversized : MineralFit.fits;
      count = 1;
    }
    matches.add(
      MineralMachineMatch(
        spec: spec,
        bands: overlapping,
        minTph: minTph,
        maxTph: maxTph,
        machineCount: count,
        fit: fit,
      ),
    );
  }

  double power(MineralMachineMatch m) =>
      double.tryParse(m.spec['power_kw'] ?? '') ?? double.infinity;
  matches.sort((a, b) {
    final byFit = a.fit.index.compareTo(b.fit.index);
    if (byFit != 0) return byFit;
    return switch (a.fit) {
      MineralFit.fits => _thenBy(
        a.maxTph.compareTo(b.maxTph),
        power(a).compareTo(power(b)),
      ),
      MineralFit.oversized => _thenBy(
        a.minTph.compareTo(b.minTph),
        power(a).compareTo(power(b)),
      ),
      MineralFit.multiple => _thenBy(
        a.machineCount.compareTo(b.machineCount),
        b.maxTph.compareTo(a.maxTph),
      ),
    };
  });
  return matches;
}

int _thenBy(int first, int second) => first != 0 ? first : second;

/// Các dải kích thước (mm) mà ít nhất một máy xử lý được, gộp liền nhau —
/// để gợi ý khi không có máy phù hợp.
List<(double, double)> mineralSupportedRanges(
  List<Map<String, String>> specs,
  StoneCondition condition,
) {
  final bands = [
    for (final spec in specs)
      if (condition == StoneCondition.dry || mineralHandlesWetStone(spec))
        ...parseMineralBands(spec['capacity_display']),
  ]..sort((a, b) => a.minMm.compareTo(b.minMm));
  final merged = <(double, double)>[];
  for (final band in bands) {
    if (merged.isNotEmpty && band.minMm <= merged.last.$2 + _eps) {
      merged[merged.length - 1] = (
        merged.last.$1,
        math.max(merged.last.$2, band.maxMm),
      );
    } else {
      merged.add((band.minMm, band.maxMm));
    }
  }
  return merged;
}

/// Ảnh máy tách quang ASORT (`SA6-2C` → `asort_sa6-2c.jpg`).
String? asortSorterImagePath(String? model) {
  final m = (model ?? '').toLowerCase().trim();
  if (!RegExp(r'^sa\d+-\d[a-z]+$').hasMatch(m)) return null;
  return 'assets/images/color_sorter/asort_$m.jpg';
}
