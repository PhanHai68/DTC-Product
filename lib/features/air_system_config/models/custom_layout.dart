import 'package:uuid/uuid.dart';

/// Loại thiết bị trong sơ đồ tuỳ chỉnh.
enum CustomKind {
  compressor,
  afterCooler,
  tank,
  waterSeparator,
  refrigeratedDryer,
  desiccantDryer,
  coarseFilter,
  fineFilter,
  ultraFineFilter,
  carbonFilter;

  bool get isFilter => switch (this) {
    waterSeparator ||
    coarseFilter ||
    fineFilter ||
    ultraFineFilter ||
    carbonFilter => true,
    _ => false,
  };

  bool get isDryer => this == refrigeratedDryer || this == desiccantDryer;

  /// Có nước ngưng (vẽ van xả khi bật xả tự động).
  bool get drains => switch (this) {
    compressor || desiccantDryer || carbonFilter => false,
    _ => true,
  };
}

/// Một máy trong tầng: model chọn riêng (`null` = model app đã tính).
class CustomUnit {
  CustomUnit({this.model});
  String? model;

  Map<String, dynamic> toJson() => {'model': model};
  factory CustomUnit.fromJson(Map<String, dynamic> j) =>
      CustomUnit(model: j['model'] as String?);
}

/// Cách nối ống từ tầng trước vào tầng.
enum CustomConnection {
  /// Gộp các đầu ra vào ống góp chung rồi chia tới từng máy.
  merged,

  /// Máy cùng thứ tự nối riêng với nhau (cùng số lượng).
  paired,

  /// Từng đường ống chọn tay ([CustomStage.links]).
  custom,
}

/// Một tầng theo dòng khí: các máy cùng loại đặt song song.
class CustomStage {
  CustomStage({
    String? id,
    required this.kind,
    List<CustomUnit>? units,
    this.paired = false,
    this.links,
  }) : id = id ?? const Uuid().v4(),
       units = units ?? [CustomUnit()];

  final String id;
  CustomKind kind;
  final List<CustomUnit> units;

  /// Nối riêng từng máy với máy cùng thứ tự ở tầng trước (cùng số lượng),
  /// vd máy nén 1 → bình 1, máy nén 2 → bình 2; không thì gộp ống chung.
  bool paired;

  /// Đường ống chọn tay từ tầng trước: (máy tầng trước, máy tầng này), chỉ
  /// số từ 0; `null` = tự động theo [paired].
  List<(int, int)>? links;

  int get qty => units.length;

  /// Bỏ đường ống trỏ tới máy không còn (sau khi bớt số lượng).
  void pruneLinks(int prevQty) => links?.removeWhere(
    (l) => l.$1 >= prevQty || l.$2 >= qty || l.$1 < 0 || l.$2 < 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'units': [for (final u in units) u.toJson()],
    'paired': paired,
    if (links != null)
      'links': [
        for (final (a, b) in links!) [a, b],
      ],
  };

  factory CustomStage.fromJson(Map<String, dynamic> j) => CustomStage(
    id: j['id'] as String?,
    kind:
        CustomKind.values.where((k) => k.name == j['kind']).firstOrNull ??
        CustomKind.compressor,
    units: [
      for (final u in (j['units'] as List?) ?? const [])
        CustomUnit.fromJson((u as Map).cast<String, dynamic>()),
    ],
    paired: j['paired'] as bool? ?? false,
    links: j['links'] is List
        ? [
            for (final l in j['links'] as List)
              if (l is List && l.length == 2)
                ((l[0] as num).toInt(), (l[1] as num).toInt()),
          ]
        : null,
  );
}

/// Sơ đồ tuỳ chỉnh: danh sách tầng theo dòng khí, từ máy nén tới line sử
/// dụng. [enabled] = dùng thay sơ đồ tự động (sơ đồ, file xuất, danh mục
/// thiết bị trong phiếu đề nghị vật tư).
class CustomLayout {
  CustomLayout({this.enabled = false, List<CustomStage>? stages})
    : stages = stages ?? [];

  bool enabled;
  final List<CustomStage> stages;

  bool get active => enabled && stages.any((s) => s.qty > 0);

  /// Tầng [k] nối riêng từng nhánh với tầng trước được không (cùng số
  /// lượng, nhiều hơn 1 máy).
  bool canPair(int k) =>
      k > 0 && stages[k].qty > 1 && stages[k].qty == stages[k - 1].qty;

  /// Có thực sự nối riêng (đã chọn và còn hợp lệ).
  bool isPaired(int k) =>
      stages[k].links == null && stages[k].paired && canPair(k);

  /// Cách nối ống vào tầng [k].
  CustomConnection connection(int k) => stages[k].links != null
      ? CustomConnection.custom
      : isPaired(k)
      ? CustomConnection.paired
      : CustomConnection.merged;

  /// Các đường ống từ tầng k − 1 vào tầng [k] (máy trước, máy sau).
  List<(int, int)> linksFor(int k) {
    if (k <= 0) return const [];
    final prev = stages[k - 1].qty, cur = stages[k].qty;
    return switch (connection(k)) {
      CustomConnection.custom => [
        for (final l in stages[k].links!)
          if (l.$1 < prev && l.$2 < cur) l,
      ],
      CustomConnection.paired => [for (var i = 0; i < cur; i++) (i, i)],
      CustomConnection.merged => [
        for (var i = 0; i < prev; i++)
          for (var j = 0; j < cur; j++) (i, j),
      ],
    };
  }

  /// Đổi cách nối tầng [k]; chuyển sang tuỳ chỉnh thì bắt đầu từ đường ống
  /// hiện có.
  void setConnection(int k, CustomConnection c) {
    final st = stages[k];
    switch (c) {
      case CustomConnection.custom:
        st.links ??= linksFor(k).toList();
      case CustomConnection.paired:
        st
          ..links = null
          ..paired = true;
      case CustomConnection.merged:
        st
          ..links = null
          ..paired = false;
    }
  }

  /// Bỏ đường ống không còn hợp lệ sau khi đổi số lượng / thứ tự / xoá
  /// tầng (tầng đầu không có ống vào).
  void prune() {
    for (var k = 0; k < stages.length; k++) {
      if (k == 0) {
        stages[k].links = null;
      } else {
        stages[k].pruneLinks(stages[k - 1].qty);
      }
    }
  }

  /// Máy tầng [k] chưa có ống vào / ống ra (chỉ số máy).
  (List<int>, List<int>) unlinked(int k) {
    final st = stages[k];
    final inLinks = linksFor(k);
    final outLinks = k + 1 < stages.length ? linksFor(k + 1) : null;
    return (
      [
        if (k > 0)
          for (var i = 0; i < st.qty; i++)
            if (!inLinks.any((l) => l.$2 == i)) i,
      ],
      [
        if (outLinks != null)
          for (var i = 0; i < st.qty; i++)
            if (!outLinks.any((l) => l.$1 == i)) i,
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'stages': [for (final s in stages) s.toJson()],
  };

  factory CustomLayout.fromJson(Map<String, dynamic> j) => CustomLayout(
    enabled: j['enabled'] as bool? ?? false,
    stages: [
      for (final s in (j['stages'] as List?) ?? const [])
        CustomStage.fromJson((s as Map).cast<String, dynamic>()),
    ],
  );
}
