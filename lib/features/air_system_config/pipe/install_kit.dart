/// Vật tư lắp đặt cụm máy theo công suất máy nén —
/// `air_compressor/install_kits.json` (sinh từ các file PO bằng
/// `tool/data/build_install_kits.dart`). Áp dụng cho mọi model cùng công
/// suất động cơ.
class InstallKitItem {
  const InstallKitItem({
    required this.name,
    required this.unit,
    required this.qty,
    this.code,
    this.spec,
    this.note,
  });

  factory InstallKitItem.fromJson(Map<String, dynamic> j) => InstallKitItem(
    code: j['code'] as String?,
    name: j['name'] as String,
    unit: j['unit'] as String,
    qty: j['qty'] as num,
    spec: j['spec'] as String?,
    note: j['note'] as String?,
  );

  /// Mã vật tư (nếu file có).
  final String? code;
  final String name;
  final String unit;
  final num qty;

  /// Quy cách / yêu cầu.
  final String? spec;

  /// Ghi chú, vd "VT tiêu hao" (vật tư tiêu hao, gom cuối danh sách).
  final String? note;
}

/// Một mục vật tư: tiêu đề, ghi chú chung (nếu có), danh sách.
class InstallKitSection {
  const InstallKitSection({
    required this.title,
    required this.items,
    this.note,
  });

  factory InstallKitSection.fromJson(Map<String, dynamic> j) =>
      InstallKitSection(
        title: j['title'] as String,
        note: j['note'] as String?,
        items: [
          for (final i in j['items'] as List)
            InstallKitItem.fromJson(i as Map<String, dynamic>),
        ],
      );

  final String title;
  final String? note;
  final List<InstallKitItem> items;
}

class InstallKit {
  const InstallKit({
    required this.hp,
    required this.kw,
    required this.standard,
    required this.drain,
    required this.electric,
  });

  factory InstallKit.fromJson(Map<String, dynamic> j) => InstallKit(
    hp: j['hp'] as int,
    kw: (j['kw'] as num).toDouble(),
    standard: InstallKitSection.fromJson({
      'title': j['title'],
      'items': j['items'],
    }),
    drain: InstallKitSection.fromJson(j['drain'] as Map<String, dynamic>),
    electric: InstallKitSection.fromJson(j['electric'] as Map<String, dynamic>),
  );

  final int hp;

  /// Công suất động cơ (kW) để khớp với model máy nén.
  final double kw;

  /// "Vật tư lắp đặt bộ máy nén khí ...HP tiêu chuẩn theo sơ đồ".
  final InstallKitSection standard;

  /// Van xả tự động đáy bình tích khí (tùy chọn).
  final InstallKitSection drain;

  /// Vật tư điện tạm tính (tùy chọn).
  final InstallKitSection electric;
}

class InstallKits {
  const InstallKits(this.kits);

  factory InstallKits.fromJson(Map<String, dynamic> j) => InstallKits([
    for (final k in j['kits'] as List)
      InstallKit.fromJson(k as Map<String, dynamic>),
  ]);

  final List<InstallKit> kits;

  /// Bộ vật tư của công suất [kw]; `null` khi chưa cập nhật.
  InstallKit? forPowerKw(double? kw) => kw == null
      ? null
      : kits.where((k) => (k.kw - kw).abs() < 0.01).firstOrNull;
}
