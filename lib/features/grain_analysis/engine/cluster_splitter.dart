import 'dart:math' as math;
import 'dart:typed_data';

import 'binary_ops.dart';
import 'grain_analysis_config.dart';

/// Tách cụm hạt chạm nhau bằng distance transform + watershed (mục 7,
/// bước 3). [mask] là vùng của một cụm (1 = thuộc cụm) trong khung
/// [width] × [height]. Trả về các mặt nạ con cùng kích thước khung; chỉ một
/// phần tử nghĩa là không tách được.
List<Uint8List> splitCluster(
  Uint8List mask,
  int width,
  int height,
  double medianArea,
  GrainAnalysisConfig config,
) {
  var area = 0;
  for (final v in mask) {
    area += v;
  }
  final expected = math.max(1, (area / medianArea).round());
  if (expected < 2) return [mask];

  final dist = distanceTransform(mask, width, height);
  var maxDist = 0.0;
  for (final d in dist) {
    if (d > maxDist) maxDist = d;
  }
  if (maxDist <= 1) return [mask];

  // Thử các mức cắt, chọn mức cho số hạt giống gần ước lượng nhất.
  ComponentLabels? bestSeeds;
  var bestDiff = 1 << 30;
  for (final alpha in config.seedThresholds) {
    final cut = alpha * maxDist;
    final seedMask = Uint8List(mask.length);
    for (var i = 0; i < mask.length; i++) {
      if (dist[i] >= cut) seedMask[i] = 1;
    }
    final seeds = labelComponents(seedMask, width, height);
    final n = seeds.stats.length;
    final diff = (n - expected).abs();
    if (n >= 2 && diff < bestDiff) {
      bestDiff = diff;
      bestSeeds = seeds;
    }
  }
  if (bestSeeds == null) return [mask];

  final labels = _flood(mask, dist, bestSeeds.labels, width, height);
  final count = bestSeeds.stats.length;
  _mergeFragments(
    labels,
    width,
    height,
    count,
    config.minFragmentFraction * medianArea,
  );
  // Không tách nhiều mảnh hơn số hạt mà diện tích cụm cho phép (hai hạt
  // chạm đầu nhau có thể ra 3 hạt giống dọc sống hạt): gộp mảnh nhỏ nhất
  // vào mảnh kề có biên chung dài nhất cho tới khi đủ.
  final maxPieces = math.max(
    2,
    (area / medianArea + config.splitAreaSlack).floor(),
  );
  while (_regionCount(labels, count) > maxPieces) {
    if (!_mergeSmallest(labels, width, height, count)) break;
  }

  final regions = <Uint8List>[];
  for (var k = 1; k <= count; k++) {
    final region = Uint8List(mask.length);
    var n = 0;
    for (var i = 0; i < labels.length; i++) {
      if (labels[i] == k) {
        region[i] = 1;
        n++;
      }
    }
    if (n > 0) regions.add(region);
  }
  return regions.length >= 2 ? regions : [mask];
}

/// Loang từ hạt giống theo khoảng cách giảm dần (watershed trên −dist).
Int32List _flood(
  Uint8List mask,
  Float32List dist,
  Int32List seeds,
  int width,
  int height,
) {
  final labels = Int32List.fromList(seeds);
  // Hàng đợi ưu tiên theo xô: khóa = khoảng cách × 4 (độ mịn 0,25 px).
  var maxKey = 0;
  for (final d in dist) {
    final k = (d * 4).floor();
    if (k > maxKey) maxKey = k;
  }
  final buckets = List<List<int>>.generate(maxKey + 1, (_) => <int>[]);
  for (var i = 0; i < labels.length; i++) {
    if (labels[i] != 0) buckets[(dist[i] * 4).floor()].add(i);
  }
  for (var key = maxKey; key >= 0; key--) {
    final bucket = buckets[key];
    while (bucket.isNotEmpty) {
      final i = bucket.removeLast();
      final label = labels[i];
      final x = i % width, y = i ~/ width;
      for (var dy = -1; dy <= 1; dy++) {
        final ny = y + dy;
        if (ny < 0 || ny >= height) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx;
          if ((dx == 0 && dy == 0) || nx < 0 || nx >= width) continue;
          final j = ny * width + nx;
          if (mask[j] == 0 || labels[j] != 0) continue;
          labels[j] = label;
          buckets[math.min(key, (dist[j] * 4).floor())].add(j);
        }
      }
    }
  }
  return labels;
}

int _regionCount(Int32List labels, int count) {
  final seen = Uint8List(count + 1);
  for (final l in labels) {
    seen[l] = 1;
  }
  var n = 0;
  for (var k = 1; k <= count; k++) {
    n += seen[k];
  }
  return n;
}

/// Gộp vùng nhỏ nhất (có vùng kề) vào vùng kề có biên chung dài nhất.
/// Trả về false nếu không gộp được.
bool _mergeSmallest(Int32List labels, int width, int height, int count) {
  final areas = Int32List(count + 1);
  for (final l in labels) {
    areas[l]++;
  }
  final order = [
    for (var k = 1; k <= count; k++)
      if (areas[k] > 0) k,
  ]..sort((a, b) => areas[a].compareTo(areas[b]));
  for (final k in order) {
    final border = <int, int>{};
    for (var i = 0; i < labels.length; i++) {
      if (labels[i] != k) continue;
      final x = i % width, y = i ~/ width;
      for (final j in [
        if (x > 0) i - 1,
        if (x < width - 1) i + 1,
        if (y > 0) i - width,
        if (y < height - 1) i + width,
      ]) {
        final l = labels[j];
        if (l != 0 && l != k) border[l] = (border[l] ?? 0) + 1;
      }
    }
    if (border.isEmpty) continue;
    final target = border.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    for (var i = 0; i < labels.length; i++) {
      if (labels[i] == k) labels[i] = target;
    }
    return true;
  }
  return false;
}

/// Gộp mảnh nhỏ hơn [minArea] vào vùng kề có biên chung dài nhất.
void _mergeFragments(
  Int32List labels,
  int width,
  int height,
  int count,
  double minArea,
) {
  final isolated = <int>{};
  var changed = true;
  while (changed) {
    changed = false;
    final areas = Int32List(count + 1);
    for (final l in labels) {
      areas[l]++;
    }
    var smallest = 0;
    for (var k = 1; k <= count; k++) {
      if (!isolated.contains(k) &&
          areas[k] > 0 &&
          areas[k] < minArea &&
          (smallest == 0 || areas[k] < areas[smallest])) {
        smallest = k;
      }
    }
    if (smallest == 0) return;
    final border = <int, int>{};
    for (var i = 0; i < labels.length; i++) {
      if (labels[i] != smallest) continue;
      final x = i % width, y = i ~/ width;
      for (final j in [
        if (x > 0) i - 1,
        if (x < width - 1) i + 1,
        if (y > 0) i - width,
        if (y < height - 1) i + width,
      ]) {
        final l = labels[j];
        if (l != 0 && l != smallest) border[l] = (border[l] ?? 0) + 1;
      }
    }
    changed = true;
    if (border.isEmpty) {
      isolated.add(smallest); // mảnh rời, giữ nguyên
      continue;
    }
    final target = border.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    for (var i = 0; i < labels.length; i++) {
      if (labels[i] == smallest) labels[i] = target;
    }
  }
}
