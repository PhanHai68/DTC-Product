import 'dart:math' as math;
import 'dart:typed_data';

/// Các phép xử lý ảnh nhị phân (0/1) dùng cho tách hạt. Ảnh là mảng
/// [Uint8List] độ dài width × height, xếp theo hàng.

/// Phép co (erosion) với phần tử cấu trúc vuông cạnh 2r+1.
Uint8List erode(Uint8List mask, int width, int height, int radius) =>
    _separable(mask, width, height, radius, erodeMode: true);

/// Phép giãn (dilation) với phần tử cấu trúc vuông cạnh 2r+1.
Uint8List dilate(Uint8List mask, int width, int height, int radius) =>
    _separable(mask, width, height, radius, erodeMode: false);

/// Mở = co rồi giãn: bỏ chấm nhiễu và cầu nối mảnh giữa các hạt.
Uint8List morphOpen(Uint8List mask, int width, int height, int radius) =>
    radius <= 0
    ? mask
    : dilate(erode(mask, width, height, radius), width, height, radius);

/// Đóng = giãn rồi co: lấp khe nhỏ trên hạt.
Uint8List morphClose(Uint8List mask, int width, int height, int radius) =>
    radius <= 0
    ? mask
    : erode(dilate(mask, width, height, radius), width, height, radius);

/// Hai lượt 1 chiều (ngang rồi dọc) bằng tổng dồn — O(N) bất kể bán kính.
Uint8List _separable(
  Uint8List mask,
  int width,
  int height,
  int radius, {
  required bool erodeMode,
}) {
  if (radius <= 0) return Uint8List.fromList(mask);
  final tmp = Uint8List(mask.length);
  final out = Uint8List(mask.length);
  final prefix = Int32List(math.max(width, height) + 1);

  for (var y = 0; y < height; y++) {
    final row = y * width;
    for (var x = 0; x < width; x++) {
      prefix[x + 1] = prefix[x] + mask[row + x];
    }
    for (var x = 0; x < width; x++) {
      final a = math.max(0, x - radius);
      final b = math.min(width, x + radius + 1);
      final ones = prefix[b] - prefix[a];
      tmp[row + x] = erodeMode ? (ones == b - a ? 1 : 0) : (ones > 0 ? 1 : 0);
    }
  }
  for (var x = 0; x < width; x++) {
    for (var y = 0; y < height; y++) {
      prefix[y + 1] = prefix[y] + tmp[y * width + x];
    }
    for (var y = 0; y < height; y++) {
      final a = math.max(0, y - radius);
      final b = math.min(height, y + radius + 1);
      final ones = prefix[b] - prefix[a];
      out[y * width + x] = erodeMode
          ? (ones == b - a ? 1 : 0)
          : (ones > 0 ? 1 : 0);
    }
  }
  return out;
}

/// Lấp lỗ bên trong vật thể: vùng nền không thông ra mép ảnh thành 1.
/// (Ví dụ chấm đen trên hạt gạo có màu gần nền tối.)
void fillHoles(Uint8List mask, int width, int height) {
  final reached = Uint8List(mask.length);
  final stack = Int32List(mask.length);
  var top = 0;
  void seed(int i) {
    if (mask[i] == 0 && reached[i] == 0) {
      reached[i] = 1;
      stack[top++] = i;
    }
  }

  for (var x = 0; x < width; x++) {
    seed(x);
    seed((height - 1) * width + x);
  }
  for (var y = 0; y < height; y++) {
    seed(y * width);
    seed(y * width + width - 1);
  }
  while (top > 0) {
    final i = stack[--top];
    final x = i % width;
    if (x > 0) seed(i - 1);
    if (x < width - 1) seed(i + 1);
    if (i >= width) seed(i - width);
    if (i < mask.length - width) seed(i + width);
  }
  for (var i = 0; i < mask.length; i++) {
    if (mask[i] == 0 && reached[i] == 0) mask[i] = 1;
  }
}

/// Thống kê một vùng liên thông.
class ComponentStats {
  ComponentStats(this.label);

  final int label;
  int area = 0;
  int minX = 1 << 30;
  int minY = 1 << 30;
  int maxX = -1;
  int maxY = -1;
  double sumX = 0;
  double sumY = 0;

  int get bboxWidth => maxX - minX + 1;
  int get bboxHeight => maxY - minY + 1;
  double get centroidX => sumX / area + 0.5;
  double get centroidY => sumY / area + 0.5;

  void add(int x, int y) {
    area++;
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
    sumX += x;
    sumY += y;
  }
}

class ComponentLabels {
  ComponentLabels(this.labels, this.stats);

  /// Nhãn của từng pixel: 0 = nền, k ≥ 1 = vùng stats[k - 1].
  final Int32List labels;
  final List<ComponentStats> stats;
}

/// Gán nhãn vùng liên thông 8 hướng (hai lượt + union-find).
ComponentLabels labelComponents(Uint8List mask, int width, int height) {
  final labels = Int32List(mask.length);
  var parent = Int32List(1024);
  var next = 1;

  int find(int a) {
    while (parent[a] != a) {
      parent[a] = parent[parent[a]];
      a = parent[a];
    }
    return a;
  }

  void union(int a, int b) {
    final ra = find(a), rb = find(b);
    if (ra == rb) return;
    if (ra < rb) {
      parent[rb] = ra;
    } else {
      parent[ra] = rb;
    }
  }

  for (var y = 0; y < height; y++) {
    final row = y * width;
    for (var x = 0; x < width; x++) {
      final i = row + x;
      if (mask[i] == 0) continue;
      var label = 0;
      void consider(int j) {
        final l = labels[j];
        if (l == 0) return;
        if (label == 0) {
          label = l;
        } else if (l != label) {
          union(label, l);
        }
      }

      if (x > 0) consider(i - 1);
      if (y > 0) {
        if (x > 0) consider(i - width - 1);
        consider(i - width);
        if (x < width - 1) consider(i - width + 1);
      }
      if (label == 0) {
        if (next >= parent.length) {
          final grown = Int32List(parent.length * 2)..setAll(0, parent);
          parent = grown;
        }
        parent[next] = next;
        label = next++;
      }
      labels[i] = label;
    }
  }

  // Lượt 2: rút gọn nhãn về 1..n và gom thống kê.
  final compact = Int32List(next);
  final stats = <ComponentStats>[];
  for (var y = 0; y < height; y++) {
    final row = y * width;
    for (var x = 0; x < width; x++) {
      final i = row + x;
      final l = labels[i];
      if (l == 0) continue;
      final root = find(l);
      var c = compact[root];
      if (c == 0) {
        stats.add(ComponentStats(stats.length + 1));
        c = compact[root] = stats.length;
      }
      labels[i] = c;
      stats[c - 1].add(x, y);
    }
  }
  return ComponentLabels(labels, stats);
}

/// Biến đổi khoảng cách Euclid chính xác (Felzenszwalb–Huttenlocher):
/// mỗi pixel 1 nhận khoảng cách tới pixel 0 gần nhất. Ngoài ảnh coi là 0.
Float32List distanceTransform(Uint8List mask, int width, int height) {
  const inf = 1e20;
  final f = Float64List(math.max(width, height) + 2);
  final d = Float64List(math.max(width, height) + 2);
  final v = Int32List(math.max(width, height) + 2);
  final z = Float64List(math.max(width, height) + 3);
  final grid = Float64List(mask.length);

  // Biến đổi 1 chiều trên n phần tử f[1..n], biên f[0] = f[n+1] = 0.
  void transform1d(int n) {
    final len = n + 2;
    var k = 0;
    v[0] = 0;
    z[0] = -inf;
    z[1] = inf;
    for (var q = 1; q < len; q++) {
      var s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]);
      while (s <= z[k]) {
        k--;
        s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k]);
      }
      k++;
      v[k] = q;
      z[k] = s;
      z[k + 1] = inf;
    }
    k = 0;
    for (var q = 0; q < len; q++) {
      while (z[k + 1] < q) {
        k++;
      }
      final dq = q - v[k];
      d[q] = dq * dq + f[v[k]];
    }
  }

  for (var x = 0; x < width; x++) {
    f[0] = 0;
    f[height + 1] = 0;
    for (var y = 0; y < height; y++) {
      f[y + 1] = mask[y * width + x] == 0 ? 0 : inf;
    }
    transform1d(height);
    for (var y = 0; y < height; y++) {
      grid[y * width + x] = d[y + 1];
    }
  }
  final out = Float32List(mask.length);
  for (var y = 0; y < height; y++) {
    f[0] = 0;
    f[width + 1] = 0;
    for (var x = 0; x < width; x++) {
      f[x + 1] = grid[y * width + x];
    }
    transform1d(width);
    for (var x = 0; x < width; x++) {
      out[y * width + x] = math.sqrt(d[x + 1]);
    }
  }
  return out;
}
