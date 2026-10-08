/// Kích thước tấm nền (khay chuẩn) in ra giấy — dùng chung cho việc sinh
/// file PDF và cho bước nắn ảnh, để hai bên luôn khớp số đo.
///
/// Mọi tọa độ tính bằng mm theo trang giấy, gốc ở góc trên-trái, trục y
/// hướng xuống. Bố cục (khổ đứng):
///
/// ```
/// ┌─────────────────────────────┐
/// │ ■   [ô trắng chuẩn]       ■ │  ← dải trắng trên: 2 mốc + ô trắng
/// │ ┌─────────────────────────┐ │
/// │ │  nền màu                │ │
/// │ │  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐  │ │  ← vùng rải mẫu (đường nét đứt)
/// │ │  │                   │  │ │
/// │ │  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘  │ │
/// │ └─────────────────────────┘ │
/// │ ■                         ■ │  ← dải trắng dưới: 2 mốc
/// └─────────────────────────────┘
/// ```
library;

class MmRect {
  const MmRect(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  MmRect inflate(double delta) =>
      MmRect(left - delta, top - delta, right + delta, bottom + delta);

  @override
  String toString() => 'MmRect($left, $top, $right, $bottom)';
}

class MmPoint {
  const MmPoint(this.x, this.y);
  final double x;
  final double y;
}

class TrayLayout {
  const TrayLayout({
    required this.id,
    required this.name,
    required this.pageWidthMm,
    required this.pageHeightMm,
    required this.marginMm,
    required this.markerSizeMm,
    required this.gapMm,
    required this.roiInsetMm,
  }) : hasMarkers = true,
       rimHeightMm = 0,
       excludedRects = const [],
       logoTemplate = const [];

  /// Khay thật không in mốc: app tìm 4 cạnh viền ngoài của khay (khay sáng
  /// đặt trên mặt bàn sẫm). [pageWidthMm] × [pageHeightMm] là kích thước
  /// viền ngoài, khổ đứng; [roiInsetMm] tính từ viền ngoài vào.
  const TrayLayout.plain({
    required this.id,
    required this.name,
    required this.pageWidthMm,
    required this.pageHeightMm,
    required this.roiInsetMm,
    required this.rimHeightMm,
    this.excludedRects = const [],
    this.logoTemplate = const [],
  }) : hasMarkers = false,
       marginMm = 0,
       markerSizeMm = 0,
       gapMm = 0;

  /// Khay A4 cho mẫu 20 g hạt nhỏ (gạo).
  static const a4 = TrayLayout(
    id: 'a4',
    name: 'A4',
    pageWidthMm: 210,
    pageHeightMm: 297,
    marginMm: 8,
    markerSizeMm: 18,
    gapMm: 5,
    roiInsetMm: 6,
  );

  /// Khay A3 cho mẫu 500 g hạt lớn (điều).
  static const a3 = TrayLayout(
    id: 'a3',
    name: 'A3',
    pageWidthMm: 297,
    pageHeightMm: 420,
    marginMm: 10,
    markerSizeMm: 24,
    gapMm: 6,
    roiInsetMm: 8,
  );

  /// Khay nhựa trắng AnySort, viền ngoài 150 × 210 mm, có logo in xám ở
  /// một đầu (vùng logo không phân tích). Thành khay cao 12–15 mm (người dùng đo,
  /// lấy 13,5); vùng logo đo trên ảnh chụp khay ngày 08/10/2026.
  static const anysort = TrayLayout.plain(
    id: 'anysort',
    name: 'AnySort 21×15 cm',
    pageWidthMm: 150,
    pageHeightMm: 210,
    roiInsetMm: 6,
    rimHeightMm: 13.5,
    excludedRects: [MmRect(8, 12, 46, 67)],
    // Hình logo trên lưới ô 2 mm phủ đúng vùng excludedRects.first (khổ
    // đứng): '#' nét logo, '+' nét logo trên một trong hai ảnh mẫu (khay
    // trắng trống 08/10/2026 và khay đen IMG_6146), '.' nền.
    logoTemplate: [
      '...................',
      '...................',
      '...................',
      '...............#+..',
      '...............#++.',
      '...............#...',
      '....++.........+#+.',
      '...###++.......##+.',
      '..#..+##+..+...###.',
      '..+...+##+.....###.',
      '..++...+##+....#+#.',
      '..#+...+###....#+#.',
      '.+#+....+++....+##.',
      '..#+....+..+...+##.',
      '..+#....+..#+..###.',
      '..+#..+.+.+##..#+#.',
      '..+..++...+##..#+..',
      '...++#+....##+.+++.',
      '...++#+....###.+++.',
      '....+##+...###.#+..',
      '.....+#++..##+.+#+.',
      '......+#+++##+.##+.',
      '......+++#+#+..##+.',
      '........++++...+++.',
      '...............++..',
      '...............##+.',
      '...............++#.',
    ],
  );

  /// Các tấm nền in ra giấy (có file PDF).
  static const printable = [a4, a3];

  static const all = [a4, a3, anysort];

  static TrayLayout byId(String? id) =>
      all.firstWhere((l) => l.id == id, orElse: () => a4);

  final String id;
  final String name;
  final double pageWidthMm;
  final double pageHeightMm;

  /// true: tấm nền in có 4 mốc đen. false: khay thật, tìm theo viền ngoài.
  final bool hasMarkers;

  /// Khay không mốc: chiều cao thành khay (mm), từ đáy tới mặt viền trên.
  /// Viền ở gần máy hơn đáy nên trông to hơn — dùng để quy tỉ lệ về mặt đáy.
  final double rimHeightMm;

  /// Vùng không phân tích (logo in trên đáy khay), tọa độ mm theo khổ đứng.
  /// Khay xoay 180° thì vùng này nằm ở góc đối diện — app tự nhận ra.
  final List<MmRect> excludedRects;

  /// Hình logo trên lưới ô [logoCellMm] phủ vùng `excludedRects.first`, mỗi
  /// chuỗi là một hàng từ trên xuống: '#' nét logo, '+' có thể là nét,
  /// '.' nền. Dùng để biết logo nằm ở đầu nào của khay (so tương quan).
  final List<String> logoTemplate;

  static const logoCellMm = 2.0;

  /// Lề giấy tới mép ngoài mốc.
  final double marginMm;

  /// Cạnh mốc vuông đen. Ô trắng giữa mốc có cạnh = [markerHoleRatio] × cạnh.
  final double markerSizeMm;

  /// Khoảng trắng giữa mốc và nền màu (để mốc không dính vào nền tối).
  final double gapMm;

  /// Vùng rải mẫu thụt vào trong nền màu một khoảng này.
  final double roiInsetMm;

  static const markerHoleRatio = 8 / 18;

  double get markerHoleMm => markerSizeMm * markerHoleRatio;

  /// Tâm 4 mốc theo thứ tự trên-trái, trên-phải, dưới-phải, dưới-trái.
  List<MmPoint> get markerCenters {
    final c = marginMm + markerSizeMm / 2;
    return [
      MmPoint(c, c),
      MmPoint(pageWidthMm - c, c),
      MmPoint(pageWidthMm - c, pageHeightMm - c),
      MmPoint(c, pageHeightMm - c),
    ];
  }

  /// Hình vuông của từng mốc (cùng thứ tự với [markerCenters]).
  List<MmRect> get markerRects => [
    for (final p in markerCenters)
      MmRect(
        p.x - markerSizeMm / 2,
        p.y - markerSizeMm / 2,
        p.x + markerSizeMm / 2,
        p.y + markerSizeMm / 2,
      ),
  ];

  /// Khoảng cách tâm-tâm giữa các mốc theo chiều ngang / dọc.
  double get markerSpacingXMm => pageWidthMm - 2 * marginMm - markerSizeMm;
  double get markerSpacingYMm => pageHeightMm - 2 * marginMm - markerSizeMm;

  /// Nền màu tương phản với hạt. Khay không mốc: cả viền ngoài khay.
  MmRect get backgroundRect => MmRect(
    marginMm,
    marginMm + markerSizeMm + gapMm,
    pageWidthMm - marginMm,
    pageHeightMm - marginMm - markerSizeMm - gapMm,
  );

  /// Vùng rải mẫu — cũng là vùng ảnh được phân tích sau khi nắn.
  MmRect get roiRect => backgroundRect.inflate(-roiInsetMm);

  /// Ô trắng chuẩn để cân bằng trắng, nằm trong dải trắng phía trên. Khay
  /// không mốc: dải mặt viền trên (tọa độ theo mặt viền, không theo đáy).
  MmRect get whitePatchRect {
    if (!hasMarkers) return MmRect(20, -0.5, pageWidthMm - 20, 6.5);
    final left = marginMm + markerSizeMm + 12;
    return MmRect(
      left,
      marginMm + 2,
      left + markerSpacingXMm * 0.32,
      marginMm + markerSizeMm - 2,
    );
  }
}
