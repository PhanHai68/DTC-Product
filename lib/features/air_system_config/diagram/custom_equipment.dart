import '../engine/air_engine.dart';
import '../engine/custom_calc.dart';
import '../l10n/air_strings.dart';
import '../models/air_config.dart';
import '../models/air_result.dart';
import '../models/catalog_compressor.dart';

/// Model, thông số và tên hiển thị cho thiết bị trong sơ đồ tuỳ chỉnh, lấy
/// từ dữ liệu của bộ tính (máy nén, bình, máy sấy lạnh, lọc đường ống).
class CustomEquipment {
  const CustomEquipment(this.engine, this.config, this.result, this.s);

  final AirEngine engine;
  final AirConfig config;
  final AirResult result;
  final AirStrings s;

  double get _bar => config.compressor.pressure ?? 8;

  /// Tên loại thiết bị.
  String kindName(CustomKind k) => s.customKindName(k);

  /// Model app đã tính cho loại thiết bị ([CustomUnit.model] `null`);
  /// [result] là kết quả của cấu hình tự động.
  String? defaultModel(CustomKind k) => customDefaultModel(k, result);

  String? modelOf(CustomStage stage, CustomUnit unit) =>
      unit.model ?? defaultModel(stage.kind);

  /// Lựa chọn model: (mã, thông số ngắn); rỗng = loại chưa có dữ liệu.
  List<(String, String)> options(CustomKind k) => switch (k) {
    CustomKind.compressor => [
      for (final m in engine.compressors) (m.modelCode, _compressorDetail(m)),
    ],
    CustomKind.tank => [
      for (final t in engine.tanks)
        (t.model, '${s.n2(t.volumeLiters / 1000)} m³'),
    ],
    CustomKind.refrigeratedDryer => [
      for (final d in engine.refrigeratedDryers)
        (d.model, s.flow(d.capacityM3min)),
    ],
    CustomKind.waterSeparator ||
    CustomKind.coarseFilter ||
    CustomKind.fineFilter ||
    CustomKind.ultraFineFilter ||
    CustomKind.carbonFilter => [
      for (final f in engine.lineFilters) (f.model, s.flow(f.capacityM3min)),
    ],
    CustomKind.afterCooler || CustomKind.desiccantDryer => const [],
  };

  String _compressorDetail(CatalogCompressor m) {
    final flow = m.flowAt(_bar) ?? m.flowAt(8);
    return [
      '${s.n2(m.powerKW)} kW',
      if (flow != null) s.flow(flow),
    ].join(' · ');
  }

  /// Thông số ngắn của model (để ghi trên sơ đồ và phiếu vật tư).
  String? detail(CustomKind k, String? model) {
    if (model == null) return null;
    for (final (code, d) in options(k)) {
      if (code == model) return d;
    }
    return null;
  }

  /// Công suất máy nén theo model (kW), `null` khi không có dữ liệu.
  double? compressorKw(String? model) => model == null
      ? null
      : engine.compressors
            .where((m) => m.modelCode == model)
            .firstOrNull
            ?.powerKW;

  /// Lưu lượng máy nén theo model ở áp làm việc (m³/phút).
  double? compressorFlow(String? model) {
    final m = model == null
        ? null
        : engine.compressors.where((c) => c.modelCode == model).firstOrNull;
    return m?.flowAt(_bar) ?? m?.flowAt(8);
  }
}

/// Sơ đồ tuỳ chỉnh dựng từ cấu hình tự động (điểm bắt đầu để sửa): máy nén
/// × số máy, after cooler, bình, lọc tách nước, máy sấy, các lọc sau sấy.
CustomLayout customLayoutFromResult(
  AirConfig config,
  AirResult r, {
  bool enabled = true,
}) {
  final pre = config.pretreat;
  final g = r.groups.firstOrNull;
  CustomStage stage(CustomKind k, [int qty = 1]) =>
      CustomStage(kind: k, units: [for (var i = 0; i < qty; i++) CustomUnit()]);
  final dryer = g == null ? null : r.dryerPicks[g.kind];
  return CustomLayout(
    enabled: enabled,
    stages: [
      stage(CustomKind.compressor, r.compressorQty < 1 ? 1 : r.compressorQty),
      if (pre.afterCooler != AfterCoolerType.none)
        stage(CustomKind.afterCooler),
      if (r.tank != null) stage(CustomKind.tank),
      if (pre.hasWaterSeparator) stage(CustomKind.waterSeparator),
      if (g != null && g.kind == DryerKind.refrigerated)
        stage(CustomKind.refrigeratedDryer, dryer?.units ?? 1),
      if (g != null && g.kind == DryerKind.desiccant)
        stage(CustomKind.desiccantDryer),
      if (g?.coarse ?? false) stage(CustomKind.coarseFilter),
      if (g?.fine ?? false) stage(CustomKind.fineFilter),
      if (g?.sterile ?? false) stage(CustomKind.ultraFineFilter),
      if (g?.carbon ?? false) stage(CustomKind.carbonFilter),
    ],
  );
}
