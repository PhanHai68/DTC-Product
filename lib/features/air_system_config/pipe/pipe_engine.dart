import '../models/air_config.dart';
import '../models/air_result.dart';
import 'install_kit.dart';

/// Vật tư từ cụm máy đến thiết bị sử dụng khí nén theo định mức cho một bước
/// tuyến ống (15 m) — `air_compressor/pipe_run_kits.json`. Số lượng nhân theo
/// số bước: tổng chiều dài làm tròn lên bội số của bước (40 m → 45 m = 3
/// bước). Hàm thuần, không chứa chữ hiển thị.

/// Tên, mã, quy cách của vật tư ở một cỡ ống.
class PipeRunVariant {
  const PipeRunVariant({required this.name, this.code, this.spec});

  factory PipeRunVariant.fromJson(Map<String, dynamic> j) => PipeRunVariant(
    code: j['code'] as String?,
    name: j['name'] as String,
    spec: j['spec'] as String?,
  );

  final String? code;
  final String name;
  final String? spec;
}

/// Một vật tư của định mức: số lượng cho một bước; vật tư theo cỡ ống có
/// [sizes] (DN → tên, mã, quy cách), còn lại dùng [variant] chung.
class PipeRunItem {
  const PipeRunItem({
    required this.unit,
    required this.qty,
    this.variant,
    this.sizes = const {},
    this.barM,
    this.note,
  });

  factory PipeRunItem.fromJson(Map<String, dynamic> j) => PipeRunItem(
    unit: j['unit'] as String,
    qty: j['qty'] as num,
    variant: j['name'] == null ? null : PipeRunVariant.fromJson(j),
    sizes: {
      for (final e in (j['sizes'] as Map<String, dynamic>? ?? {}).entries)
        int.parse(e.key): PipeRunVariant.fromJson(
          e.value as Map<String, dynamic>,
        ),
    },
    barM: (j['barM'] as num?)?.toDouble(),
    note: j['note'] as String?,
  );

  final String unit;

  /// Số lượng cho một bước tuyến ống.
  final num qty;
  final PipeRunVariant? variant;
  final Map<int, PipeRunVariant> sizes;

  /// Mua theo cây dài [barM] (m): số mét làm tròn lên bội số của [barM].
  final double? barM;

  /// Ghi chú, vd "VT tiêu hao".
  final String? note;

  PipeRunVariant? variantFor(int dn) => sizes.isEmpty ? variant : sizes[dn];
}

class PipeRunKit {
  const PipeRunKit({
    required this.stepM,
    required this.dnByHp,
    required this.items,
  });

  factory PipeRunKit.fromJson(Map<String, dynamic> j) => PipeRunKit(
    stepM: (j['stepM'] as num).toDouble(),
    dnByHp: {
      for (final e in (j['dnByHp'] as Map<String, dynamic>).entries)
        int.parse(e.key): e.value as int,
    },
    items: [
      for (final i in j['items'] as List)
        PipeRunItem.fromJson(i as Map<String, dynamic>),
    ],
  );

  /// Chiều dài tuyến ống của định mức (m).
  final double stepM;

  /// Cỡ ống theo công suất bộ vật tư cụm máy (HP → DN).
  final Map<int, int> dnByHp;
  final List<PipeRunItem> items;

  /// Các cỡ ống có định mức, tăng dần.
  List<int> get sizes =>
      {for (final i in items) ...i.sizes.keys}.toList()..sort();
}

enum PipeWarningCode {
  /// Chưa nhập tổng chiều dài đường ống.
  missingLength,

  /// Chưa có định mức cho cỡ ống (params: dn — `null` khi chưa xác định được
  /// cỡ ống, sizes).
  noSize,
}

class PipeWarning {
  const PipeWarning(this.code, [this.params = const {}]);
  final PipeWarningCode code;
  final Map<String, Object?> params;
}

/// Một dòng vật tư đã nhân theo số bước. [key] cố định theo vị trí trong định
/// mức để gắn phần sửa tay.
class PipeRunLine {
  const PipeRunLine({
    required this.key,
    required this.name,
    required this.unit,
    required this.qty,
    this.code,
    this.spec,
    this.note,
  });
  final String key;
  final String? code;
  final String name;
  final String unit;
  final num qty;
  final String? spec;
  final String? note;
}

class PipeResult {
  const PipeResult({
    required this.lengthM,
    required this.stepM,
    required this.steps,
    required this.dn,
    required this.items,
    required this.warnings,
  });
  final double? lengthM;
  final double stepM;

  /// Số bước tuyến ống (0 khi chưa nhập chiều dài).
  final int steps;

  /// Cỡ ống dùng định mức; `null` khi chưa xác định.
  final int? dn;
  final List<PipeRunLine> items;
  final List<PipeWarning> warnings;

  /// Chiều dài tính vật tư (m): số bước × bước.
  double get coveredM => steps * stepM;
}

class PipeMaterialEngine {
  const PipeMaterialEngine({required this.kit, this.installKits});

  final PipeRunKit kit;

  /// Để lấy cỡ ống theo công suất bộ vật tư cụm máy.
  final InstallKits? installKits;

  PipeResult compute(AirConfig config, AirResult r) {
    final length = config.pipe.totalLengthM;
    final warnings = <PipeWarning>[];
    // Cỡ ống: theo công suất bộ vật tư cụm máy; công suất chưa có bộ vật tư
    // thì theo lỗ thoát khí máy nén.
    final hp = installKits?.forPowerKw(r.compressor?.powerKw)?.hp;
    final dn = kit.dnByHp[hp] ?? r.compressor?.model?.outletDn;

    PipeResult result({int steps = 0, List<PipeRunLine> items = const []}) =>
        PipeResult(
          lengthM: length,
          stepM: kit.stepM,
          steps: steps,
          dn: dn,
          items: items,
          warnings: warnings,
        );

    if (length == null || !length.isFinite || length <= 0) {
      warnings.add(const PipeWarning(PipeWarningCode.missingLength));
      return result();
    }
    final steps = (length / kit.stepM - 1e-9).ceil();
    if (dn == null || !kit.sizes.contains(dn)) {
      warnings.add(
        PipeWarning(PipeWarningCode.noSize, {'dn': dn, 'sizes': kit.sizes}),
      );
      return result(steps: steps);
    }

    final items = <PipeRunLine>[];
    for (final (k, item) in kit.items.indexed) {
      final v = item.variantFor(dn);
      if (v == null) continue;
      final raw = item.qty * steps;
      final bar = item.barM;
      // Ống mua nguyên cây; số lẻ (vd 0,5 cây × 3) làm tròn lên.
      final num qty = bar != null
          ? ((raw / bar - 1e-9).ceil() * bar).round()
          : (raw - raw.round()).abs() < 1e-9
          ? raw.round()
          : (raw - 1e-9).ceil();
      items.add(
        PipeRunLine(
          key: 'r$k',
          code: v.code,
          name: v.name,
          unit: item.unit,
          qty: qty,
          spec: v.spec,
          note: item.note,
        ),
      );
    }
    return result(steps: steps, items: items);
  }
}
