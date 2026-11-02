import '../../../models/air_tank_spec.dart';
import '../../../models/line_filter_spec.dart';
import '../../../models/refrigerated_dryer_spec.dart';
import 'air_config.dart';
import 'catalog_compressor.dart';

/// Kết quả tính của [AirConfig]. Không chứa chữ hiển thị: tên, thông số,
/// cảnh báo được dựng từ mã + tham số ở `AirStrings` để đổi ngôn ngữ được.

enum DryerKind { desiccant, refrigerated, none }

/// Một nhóm xử lý khí (gom line theo điểm sương).
class AirGroup {
  AirGroup({
    required this.kind,
    required this.lineIndexes,
    required this.demand,
    required this.purge,
    required this.pdp,
    required this.coarse,
    required this.fine,
    required this.carbon,
    required this.sterile,
    required this.pressureDrop,
  });

  final DryerKind kind;
  final List<int> lineIndexes;

  /// Tổng lưu lượng các line trong nhóm (m³/phút).
  final double demand;

  /// Khí xả tái sinh (chỉ nhóm sấy hấp thụ).
  final double purge;

  /// Điểm sương thực tế của máy sấy (mức thấp nhất trong nhóm).
  final int? pdp;

  /// Tách thô 1 µm và tách tinh 0,01 µm sau máy sấy (lọc đường ống).
  final bool coarse;
  final bool fine;
  final bool carbon;
  final bool sterile;
  final double pressureDrop;

  double get dryerInlet => demand + purge;
  bool get hasDryer => kind != DryerKind.none;
  bool get hasPostFilters => coarse || fine || carbon || sterile;

  /// Số lọc sau máy sấy của nhóm.
  int get postFilterCount =>
      [coarse, fine, carbon, sterile].where((on) => on).length;
}

/// Chất lượng khí ISO 8573-1 của một line, dạng [Hạt : Nước : Dầu].
class LineQuality {
  const LineQuality({
    required this.lineIndex,
    required this.group,
    required this.particle,
    required this.water,
    required this.oil,
    this.actualWater,
  });

  final int lineIndex;
  final DryerKind group;

  /// `null` = không xác định (không có lọc nào).
  final int? particle;

  /// `null` = không sấy (X).
  final int? water;
  final int oil;

  /// Lớp nước thực tế khi máy sấy chung cho điểm sương thấp hơn yêu cầu.
  final int? actualWater;

  String get code => '[${particle ?? '–'}:${water ?? 'X'}:$oil]';
}

enum WarningLevel { error, caution, note }

enum AirWarningCode {
  invalidInput,
  oilNoOilFilter,
  desiccantNoOilFilter,
  powerOver,
  noTank,
  purge,
  fourInOneIntegrated,
  dryerPressureHigh,
  noDryerModel,
  modelFlowLow,
  noCatalogModel,
  catalogPressure,
  tankTooLarge,
  tankDesignHigh,
  tankManualNotInCatalog,

  /// Sơ đồ tuỳ chỉnh: một máy (bình, máy sấy, lọc) nhỏ hơn lượng khí đi qua.
  customUnitLow,
}

class AirWarning {
  const AirWarning(this.level, this.code, [this.params = const {}]);
  final WarningLevel level;
  final AirWarningCode code;
  final Map<String, Object?> params;
}

enum EquipmentKind {
  compressor,
  tank,
  afterCooler,
  waterSeparator,
  desiccantDryer,
  refrigeratedDryer,
  coarseFilter,
  fineFilter,
  carbonFilter,
  sterileFilter,
  autoDrain,
  oilWaterSeparator,
  mccb,
  cable,
  extra,
}

/// Một dòng danh mục thiết bị. [key] cố định để gắn phần sửa tay.
class EquipmentItem {
  const EquipmentItem({
    required this.key,
    required this.kind,
    required this.qty,
    this.group,
    this.params = const {},
  });

  final String key;
  final EquipmentKind kind;
  final int qty;
  final DryerKind? group;
  final Map<String, Object?> params;
}

/// Máy nén được chọn để đối chiếu (từ dữ liệu hoặc nhập tay).
class CompressorPick {
  const CompressorPick({
    this.model,
    this.units = 1,
    this.flowAtPressure,
    this.manualName,
    this.manualPowerKw,
  });

  final CatalogCompressor? model;

  /// Số máy chạy (chưa tính máy dự phòng).
  final int units;

  /// Lưu lượng 1 máy ở áp suất làm việc (m³/phút), nếu biết.
  final double? flowAtPressure;
  final String? manualName;
  final double? manualPowerKw;

  double? get powerKw => model?.powerKW ?? manualPowerKw;
}

class TankPick {
  const TankPick({
    required this.volumeM3,
    required this.requiredM3,
    required this.designPressure,
    this.spec,
    this.manual = false,
    this.tooLarge = false,
  });

  /// Bình trong dữ liệu `air_tanks.json`; `null` khi nhập tay lệch cỡ hoặc
  /// vượt dải.
  final AirTankSpec? spec;
  final double volumeM3;
  final double requiredM3;

  /// Áp suất thiết kế cần theo áp làm việc.
  final double designPressure;
  final bool manual;
  final bool tooLarge;

  bool get designInsufficient =>
      spec != null && spec!.designPressureKgfCm2 + 1e-9 < designPressure;
}

/// Máy sấy lạnh ACD chọn cho nhóm sấy lạnh (`refrigerated_dryers.json`).
class DryerPick {
  const DryerPick({
    required this.spec,
    required this.units,
    required this.inlet,
    this.compressorKw,
  });
  final RefrigeratedDryerSpec spec;

  /// Công suất máy nén (kW) khi chọn theo bảng máy nén tương ứng; `null` khi
  /// chọn theo lưu lượng.
  final double? compressorKw;

  /// Số máy (nhiều máy khi vượt model lớn nhất).
  final int units;

  /// Lưu lượng dùng để chọn (m³/phút): phần khí của nhánh khi máy nén chạy
  /// hết công suất, không nhỏ hơn nhu cầu nhánh.
  final double inlet;

  double get capacity => spec.capacityM3min * units;
}

/// Model lọc đường ống chọn theo lưu lượng máy nén (`line_filters.json`).
class LineFilterPick {
  const LineFilterPick({
    required this.spec,
    required this.units,
    required this.levels,
  });
  final LineFilterSpec spec;

  /// Số bộ lọc song song mỗi cấp (nhiều bộ khi vượt model lớn nhất).
  final int units;

  /// Các cấp lọc có trong hệ thống (tách nước / tách thô / tách tinh).
  final List<LineFilterLevel> levels;
}

class AirResult {
  AirResult({
    required this.lines,
    required this.validLines,
    required this.demand,
    required this.purge,
    required this.purgeRate,
    required this.customerDemand,
    required this.required,
    required this.flow,
    required this.flowFromModel,
    this.demandBased = true,
    required this.pressure,
    required this.pressureNeed,
    required this.pretreatDrop,
    required this.powerEstimate,
    required this.motorKw,
    required this.compressor,
    required this.compressorQty,
    required this.tank,
    this.dryerPicks = const {},
    this.lineFilter,
    this.electrical,
    required this.groups,
    required this.quality,
    required this.equipment,
    required this.warnings,
    this.custom,
  });

  /// Kết quả theo sơ đồ tuỳ chỉnh: thay các trường tính theo thiết bị
  /// (máy nén, bình, máy sấy, lọc, áp suất cần, cảnh báo), giữ phần còn lại.
  AirResult withCustom({
    required CustomCalc custom,
    required double flow,
    required double powerEstimate,
    required CompressorPick? compressor,
    required int compressorQty,
    required TankPick? tank,
    required Map<DryerKind, DryerPick> dryerPicks,
    required LineFilterPick? lineFilter,
    required Map<String, String>? electrical,
    required double pressureNeed,
    required List<AirGroup> groups,
    required List<LineQuality> quality,
    required List<AirWarning> warnings,
  }) => AirResult(
    lines: lines,
    validLines: validLines,
    demand: demand,
    purge: purge,
    purgeRate: purgeRate,
    customerDemand: customerDemand,
    required: required,
    flow: flow,
    flowFromModel: flowFromModel || custom.flow > 0,
    demandBased: demandBased,
    pressure: pressure,
    pressureNeed: pressureNeed,
    pretreatDrop: pretreatDrop,
    powerEstimate: powerEstimate,
    motorKw: motorKw,
    compressor: compressor,
    compressorQty: compressorQty,
    tank: tank,
    dryerPicks: dryerPicks,
    lineFilter: lineFilter,
    electrical: electrical,
    groups: groups,
    quality: quality,
    equipment: equipment,
    warnings: warnings,
    custom: custom,
  );

  /// Các line của cấu hình (giữ thứ tự nhập).
  final List<AirLine> lines;

  /// Chỉ số các line hợp lệ đã đưa vào tính.
  final List<int> validLines;
  final double demand;
  final double purge;
  final double purgeRate;

  /// Nhu cầu khách hàng đã nhập (chế độ theo nhu cầu), nếu có.
  final double? customerDemand;

  /// Nhu cầu dùng để chọn máy (m³/phút): nhu cầu khách hàng, không nhỏ hơn
  /// tổng các line + khí xả tái sinh.
  final double required;

  /// Lưu lượng máy nén (m³/phút): của máy được chọn (số máy × lưu lượng);
  /// chưa có máy thì lấy nhu cầu cộng mức dư tối thiểu.
  final double flow;

  /// [flow] lấy từ máy được chọn (dữ liệu hoặc nhập tay).
  final bool flowFromModel;

  /// Máy chọn theo nhu cầu khách hàng (chế độ "Theo nhu cầu").
  final bool demandBased;

  /// Tổng các line + khí xả tái sinh.
  double get linesNeed => demand + purge;

  /// Mức dư của máy so với nhu cầu (0,18 = +18%); `null` khi chưa có máy.
  double? get margin =>
      demandBased && flowFromModel && required > 0 ? flow / required - 1 : null;
  final double pressure;

  /// Áp suất cần (bar), đã làm tròn 0,1.
  final double pressureNeed;
  final double pretreatDrop;
  final double powerEstimate;

  /// `null` khi vượt dãy động cơ.
  final double? motorKw;
  final CompressorPick? compressor;
  final int compressorQty;
  final TankPick? tank;

  /// Máy sấy chọn từ dữ liệu theo nhóm (hiện chỉ nhóm sấy lạnh).
  final Map<DryerKind, DryerPick> dryerPicks;

  /// Lọc đường ống; `null` khi không có lọc nào hoặc chưa có dữ liệu.
  final LineFilterPick? lineFilter;

  /// Dòng của model máy nén trong `mccb_cable.json` (MCCB, cáp máy nén, MCB
  /// và cáp máy sấy — như màn "Chọn MCCB và dây điện"); `null` khi model
  /// không có trong bảng.
  final Map<String, String>? electrical;
  final List<AirGroup> groups;
  final List<LineQuality> quality;
  final List<EquipmentItem> equipment;

  /// Đã xếp: lỗi → lưu ý → ghi chú.
  final List<AirWarning> warnings;

  /// Tính theo sơ đồ tuỳ chỉnh (đang bật); `null` = cấu hình tự động.
  final CustomCalc? custom;

  bool get hasErrors => warnings.any((w) => w.level == WarningLevel.error);

  AirGroup? groupOf(int lineIndex) =>
      groups.where((g) => g.lineIndexes.contains(lineIndex)).firstOrNull;

  LineQuality? qualityOf(int lineIndex) =>
      quality.where((q) => q.lineIndex == lineIndex).firstOrNull;
}

/// Một máy trong sơ đồ tuỳ chỉnh: model, dữ liệu catalog và lượng khí đi qua
/// (chia đều đầu ra của máy trước theo các ống nối).
class CustomUnitCalc {
  const CustomUnitCalc({
    required this.stage,
    required this.index,
    required this.kind,
    required this.model,
    required this.inflow,
    this.compressor,
    this.tank,
    this.dryer,
    this.filter,
  });

  /// Chỉ số tầng và chỉ số máy trong tầng (từ 0).
  final int stage;
  final int index;
  final CustomKind kind;

  /// Model đang dùng (chọn riêng hoặc model app đã tính); `null` = chưa có.
  final String? model;

  /// Khí đi vào máy (m³/phút); máy nén là lưu lượng của chính máy.
  final double inflow;

  final CatalogCompressor? compressor;
  final AirTankSpec? tank;
  final RefrigeratedDryerSpec? dryer;
  final LineFilterSpec? filter;

  /// Lưu lượng định mức (máy sấy lạnh, lọc); `null` khi không áp dụng.
  double? get capacity => dryer?.capacityM3min ?? filter?.capacityM3min;
}

/// Tổng hợp sơ đồ tuỳ chỉnh dùng cho kết quả, phòng lắp đặt và vật tư.
class CustomCalc {
  const CustomCalc({
    required this.units,
    required this.flow,
    required this.kw,
    required this.electrical,
  });

  /// Mọi máy theo thứ tự tầng.
  final List<CustomUnitCalc> units;

  /// Tổng lưu lượng các máy nén (m³/phút), tổng công suất (kW).
  final double flow;
  final double kw;

  /// MCCB / cáp theo từng model máy nén (không trùng model).
  final List<(String, Map<String, String>)> electrical;

  Iterable<CustomUnitCalc> of(CustomKind kind) =>
      units.where((u) => u.kind == kind);

  bool has(CustomKind kind) => units.any((u) => u.kind == kind);
}
