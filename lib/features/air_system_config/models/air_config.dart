import 'package:uuid/uuid.dart';

/// Cấu hình hệ thống khí nén do người dùng nhập. Cấu trúc JSON:
/// `project, compressor, tank, pretreat, desiccant, lines[]`, thêm
/// `overrides`/`extraItems` cho phần sửa tay danh mục thiết bị.
///
/// Các lớp cấu hình là mutable: màn nhập liệu sửa trực tiếp rồi tính lại;
/// [AirConfig.copy] tạo bản sao độc lập qua JSON.

/// Loại máy nén theo "Danh mục máy nén khí" (Máy nén khí → Thông số kỹ thuật).
enum CompressorType {
  pmVsd,
  fixedSpeed,
  fourInOne,
  oilFree,
  twoStage;

  bool get isOilFree => this == oilFree;

  /// Các `series` trong `air_compressor/specs.json`; rỗng = chưa có dữ liệu.
  List<String> get catalogSeries => switch (this) {
    pmVsd => const ['PM VSD'],
    fixedSpeed => const ['Fixed Speed'],
    fourInOne => const ['4-IN-1 Fixed', '4-IN-1 VSD'],
    oilFree => const ['Oil-Free F', 'Oil-Free PV'],
    twoStage => const [],
  };

  bool get hasCatalog => catalogSeries.isNotEmpty;

  /// Đọc cả tên loại cũ (trước khi đổi theo danh mục máy nén).
  static CompressorType fromJson(Object? name, Object? oldSeries) =>
      switch (name) {
        'oilFreeWater' || 'oilFreeDry' => oilFree,
        'oilInjected' => oldSeries == 'Fixed Speed' ? fixedSpeed : pmVsd,
        _ => values.where((v) => v.name == name).firstOrNull ?? pmVsd,
      };
}

enum AfterCoolerType { none, air, water }

enum RegenType { heatless, heated, blower }

/// Điểm sương yêu cầu của line; [none] = không sấy.
enum LinePdp {
  m70(-70),
  m40(-40),
  m20(-20),

  /// Máy sấy tác nhân lạnh: điểm sương 2–10 °C (theo máy ACD); tính theo
  /// mức xấu nhất 10 °C. Cấu hình cũ "+7 °C" đọc thành mức này.
  p3(10),
  none(null);

  const LinePdp(this.celsius);
  final int? celsius;

  bool get isDesiccant => celsius != null && celsius! <= -20;
  bool get isRefrigerated => celsius != null && celsius! > 0;
}

/// Cách chọn máy nén: [demand] đề xuất model theo nhu cầu khách hàng (dư
/// 15–25%), [catalog] chọn thẳng model trong dữ liệu, [manual] nhập tay máy
/// ngoài dữ liệu (lựa chọn phụ).
enum CompressorSource {
  demand,
  catalog,
  manual;

  /// `auto` của cấu hình cũ = đề xuất theo nhu cầu.
  static CompressorSource fromJson(Object? name) => name == 'auto'
      ? demand
      : values.where((v) => v.name == name).firstOrNull ?? demand;
}

T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.where((v) => v.name == name).firstOrNull ?? fallback;

double? _double(Object? v) => (v as num?)?.toDouble();

class AirProject {
  AirProject({this.name = ''});
  String name;

  Map<String, dynamic> toJson() => {'name': name};
  factory AirProject.fromJson(Map<String, dynamic> j) =>
      AirProject(name: j['name'] as String? ?? '');
}

class CompressorConfig {
  CompressorConfig({
    this.type = CompressorType.pmVsd,
    this.pressure = 8,
    this.demand,
    this.marginPercent = 15,
    this.source = CompressorSource.demand,
    this.modelCode,
    this.manualName = '',
    this.manualPowerKw,
    this.manualFad,
  });

  CompressorType type;

  /// Áp suất làm việc (bar); `null` = ô đang trống/sai.
  double? pressure;

  /// Nhu cầu khách hàng (m³/phút) để đề xuất model; `null` = lấy tổng các
  /// line + khí xả tái sinh.
  double? demand;

  /// Lưu lượng máy lớn hơn nhu cầu thực tế bao nhiêu % (khách hàng tự chọn,
  /// gợi ý 15 / 20 / 25 / 30).
  double? marginPercent;
  CompressorSource source;
  String? modelCode;
  String manualName;
  double? manualPowerKw;
  double? manualFad;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'pressure': pressure,
    'demand': demand,
    'marginPercent': marginPercent,
    'source': source.name,
    'modelCode': modelCode,
    'manualName': manualName,
    'manualPowerKw': manualPowerKw,
    'manualFad': manualFad,
  };

  factory CompressorConfig.fromJson(Map<String, dynamic> j) => CompressorConfig(
    type: CompressorType.fromJson(j['type'], j['series']),
    pressure: _double(j['pressure']),
    demand: _double(j['demand']),
    marginPercent: j.containsKey('marginPercent')
        ? _double(j['marginPercent'])
        : 15,
    source: CompressorSource.fromJson(j['source']),
    modelCode: j['modelCode'] as String?,
    manualName: j['manualName'] as String? ?? '',
    manualPowerKw: _double(j['manualPowerKw']),
    manualFad: _double(j['manualFad']),
  );
}

class TankConfig {
  TankConfig({this.enabled = true, this.manualVolumeM3});
  bool enabled;
  double? manualVolumeM3;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'manualVolumeM3': manualVolumeM3,
  };
  factory TankConfig.fromJson(Map<String, dynamic> j) => TankConfig(
    enabled: j['enabled'] as bool? ?? true,
    manualVolumeM3: _double(j['manualVolumeM3']),
  );
}

/// "Lọc đường ống". Hệ tiêu chuẩn: máy nén → bình tích khí → lọc tách nước
/// 3 µm → máy sấy → tách thô 1 µm → tách tinh 0,01 µm (tách thô/tinh lắp sau
/// từng máy sấy). Bỏ tick [standard] thì bật/tắt từng lọc. Phần "Nâng cao":
/// after cooling và lọc sau bình tích khí (1 = tách thô, 2 = thêm tách tinh).
class PretreatConfig {
  PretreatConfig({
    this.standard = true,
    this.waterSeparator = true,
    this.coarseFilter = true,
    this.fineFilter = true,
    this.afterCooler = AfterCoolerType.none,
    this.tankFilter = false,
    this.tankFilterQty = 2,
    this.autoDrain = true,
  });

  /// Theo tiêu chuẩn lọc đường ống: đủ 3 lọc (số lượng tối thiểu).
  bool standard;
  bool waterSeparator;
  bool coarseFilter;
  bool fineFilter;
  AfterCoolerType afterCooler;
  bool tankFilter;

  /// 1 hoặc 2 lọc sau bình tích khí.
  int tankFilterQty;
  bool autoDrain;

  bool get hasWaterSeparator => standard || waterSeparator;
  bool get hasCoarse => standard || coarseFilter;
  bool get hasFine => standard || fineFilter;

  /// Số lọc sau bình (0 khi tắt).
  int get tankFilters => tankFilter ? tankFilterQty.clamp(1, 2) : 0;

  Map<String, dynamic> toJson() => {
    'standard': standard,
    'waterSeparator': waterSeparator,
    'coarseFilter': coarseFilter,
    'fineFilter': fineFilter,
    'afterCooler': afterCooler.name,
    'tankFilter': tankFilter,
    'tankFilterQty': tankFilterQty,
    'autoDrain': autoDrain,
  };

  /// Cấu hình cũ (lọc bụi / lọc tách dầu) đọc thành hệ tiêu chuẩn.
  factory PretreatConfig.fromJson(Map<String, dynamic> j) => PretreatConfig(
    standard: j['standard'] as bool? ?? true,
    waterSeparator: j['waterSeparator'] as bool? ?? true,
    coarseFilter: j['coarseFilter'] as bool? ?? true,
    fineFilter: j['fineFilter'] as bool? ?? true,
    afterCooler: _enum(
      AfterCoolerType.values,
      j['afterCooler'],
      AfterCoolerType.none,
    ),
    tankFilter: j['tankFilter'] as bool? ?? false,
    tankFilterQty: (j['tankFilterQty'] as num?)?.toInt() ?? 2,
    autoDrain: j['autoDrain'] as bool? ?? true,
  );
}

/// Nơi dùng khí (máy tách màu, máy cân đóng gói…): chỉ tên, nhập tay, để
/// hiện trên sơ đồ. Không tham gia tính toán.
class AirLine {
  AirLine({String? id, this.name = 'Line 1'}) : id = id ?? const Uuid().v4();

  final String id;
  String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory AirLine.fromJson(Map<String, dynamic> j) =>
      AirLine(id: j['id'] as String?, name: j['name'] as String? ?? '');
}

/// Xử lý khí chung cho cả hệ thống: điểm sương (chọn máy sấy) và áp suất
/// thiết bị sử dụng cần.
class AirTreatment {
  AirTreatment({this.pdp = LinePdp.p3, this.usePressure = 8});

  LinePdp pdp;

  /// Áp suất sử dụng (bar); `null` = ô trống/sai.
  double? usePressure;

  Map<String, dynamic> toJson() => {
    'pdp': pdp.name,
    'usePressure': usePressure,
  };

  factory AirTreatment.fromJson(Map<String, dynamic> j) => AirTreatment(
    pdp: _enum(LinePdp.values, j['pdp'], LinePdp.p3),
    usePressure: _double(j['usePressure']) ?? 8,
  );

  /// Cấu hình cũ (mỗi line có lưu lượng, áp, điểm sương, lọc): điểm sương
  /// thấp nhất, áp = áp max cao nhất.
  factory AirTreatment.fromOldLines(List lines) {
    final pdps = [
      for (final l in lines)
        _enum(LinePdp.values, (l as Map)['pdp'], LinePdp.p3),
    ];
    final dried = [
      for (final p in pdps)
        if (p.celsius != null) p,
    ]..sort((a, b) => a.celsius!.compareTo(b.celsius!));
    final pMax = [for (final l in lines) _double((l as Map)['pMax'])].nonNulls;
    return AirTreatment(
      pdp: dried.isNotEmpty
          ? dried.first
          : pdps.isEmpty
          ? LinePdp.p3
          : LinePdp.none,
      usePressure: pMax.isEmpty ? 8 : pMax.reduce((a, b) => a > b ? a : b),
    );
  }
}

/// Phương án lắp đặt (cả 3 đều một hàng dọc tường sau): [option1] máy nén
/// và máy sấy dọc tường; [option2] máy sấy xoay 90°; [option3] máy nén và
/// máy sấy xoay 90°.
enum RoomStyle { option1, option2, option3 }

/// Tường đặt cửa ra vào (nhìn mặt bằng: sau = tường dãy thiết bị dựa vào).
enum RoomDoorWall { front, left, right }

/// Phòng lắp đặt (tab "Phòng lắp đặt"). Kích thước phòng thực tế (m) để
/// trống thì app tự tính phòng tối thiểu.
class RoomConfig {
  RoomConfig({
    this.lengthM,
    this.widthM,
    this.heightM,
    this.door = RoomDoorWall.front,
    this.style = RoomStyle.option1,
    this.outsideTempC,
    this.inletMaxTempC,
    Map<String, (double, double)>? positions,
    Set<String>? turned,
    List<RoomMeasure>? measures,
  }) : positions = positions ?? {},
       turned = turned ?? {},
       measures = measures ?? [];

  double? lengthM;
  double? widthM;
  double? heightM;
  RoomDoorWall door;
  RoomStyle style;

  /// Thông gió: T1 nhiệt độ ngoài phòng, T2 nhiệt độ khí vào máy nén tối đa
  /// (°C); `null` = mặc định trong `room_layout_constants.json`.
  double? outsideTempC;
  double? inletMaxTempC;

  /// Vị trí chỉnh tay (góc trên trái khối, mm) theo khóa thiết bị
  /// (`compressor_0`, `tank_0`…); trống = vị trí tự động.
  final Map<String, (double, double)> positions;

  /// Thiết bị xoay tay 90° so với phương án đang chọn (khóa thiết bị).
  final Set<String> turned;

  /// Các phép đo trên mặt bằng (mm).
  final List<RoomMeasure> measures;

  /// Đã nhập đủ dài và rộng phòng thực tế.
  bool get hasActual => (lengthM ?? 0) > 0 && (widthM ?? 0) > 0;

  Map<String, dynamic> toJson() => {
    'lengthM': lengthM,
    'widthM': widthM,
    'heightM': heightM,
    'door': door.name,
    'style': style.name,
    'outsideTempC': outsideTempC,
    'inletMaxTempC': inletMaxTempC,
    'positions': {
      for (final e in positions.entries) e.key: [e.value.$1, e.value.$2],
    },
    'turned': turned.toList()..sort(),
    'measures': [for (final m in measures) m.toJson()],
  };

  factory RoomConfig.fromJson(Map<String, dynamic> j) => RoomConfig(
    lengthM: _double(j['lengthM']),
    widthM: _double(j['widthM']),
    heightM: _double(j['heightM']),
    door: _enum(RoomDoorWall.values, j['door'], RoomDoorWall.front),
    style: _enum(RoomStyle.values, j['style'], RoomStyle.option1),
    outsideTempC: _double(j['outsideTempC']),
    inletMaxTempC: _double(j['inletMaxTempC']),
    positions: {
      for (final e in ((j['positions'] as Map?) ?? const {}).entries)
        if (e.value is List && (e.value as List).length == 2)
          e.key as String: (
            ((e.value as List)[0] as num).toDouble(),
            ((e.value as List)[1] as num).toDouble(),
          ),
    },
    turned: {for (final k in (j['turned'] as List?) ?? const []) k as String},
    measures: [
      for (final m in (j['measures'] as List?) ?? const [])
        RoomMeasure.fromJson((m as Map).cast<String, dynamic>()),
    ],
  );
}

/// Vật tư đường ống (tab "Vật tư đường ống"): tuyến thẳng từ phòng máy tới
/// máy tách màu. `null` = dùng mặc định trong `pipe_material_constants.json`.
class PipeConfig {
  PipeConfig({
    this.totalLengthM,
    this.drainKit = false,
    this.electricKit = false,
    Map<String, MaterialListEdit>? edits,
  }) : edits = edits ?? {};

  /// Tổng chiều dài đường ống (m) — bắt buộc để tính vật tư (nhân theo bước
  /// 15 m).
  double? totalLengthM;

  /// Vật tư lắp đặt cụm máy: kèm danh sách van xả tự động đáy bình tích khí
  /// và vật tư điện tạm tính.
  bool drainKit;
  bool electricKit;

  /// Sửa tay các danh sách vật tư của tab, theo khóa danh sách (`kit`,
  /// `drain`, `electric`, `pipe`).
  final Map<String, MaterialListEdit> edits;

  Map<String, dynamic> toJson() => {
    'totalLengthM': totalLengthM,
    'drainKit': drainKit,
    'electricKit': electricKit,
    'edits': {
      for (final e in edits.entries)
        if (!e.value.isEmpty) e.key: e.value.toJson(),
    },
  };

  factory PipeConfig.fromJson(Map<String, dynamic> j) => PipeConfig(
    totalLengthM: _double(j['totalLengthM']),
    drainKit: j['drainKit'] == true,
    electricKit: j['electricKit'] == true,
    edits: {
      for (final e in (j['edits'] as Map<String, dynamic>? ?? {}).entries)
        e.key: MaterialListEdit.fromJson(e.value as Map<String, dynamic>),
    },
  );
}

/// Sửa tay một dòng vật tư tự tính: trường `null` = giữ giá trị tự tính.
class MaterialEdit {
  MaterialEdit({
    this.name,
    this.spec,
    this.unit,
    this.qty,
    this.removed = false,
  });
  String? name;
  String? spec;
  String? unit;
  double? qty;

  /// Đã xoá khỏi danh sách.
  bool removed;

  bool get isEmpty =>
      !removed && name == null && spec == null && unit == null && qty == null;

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (spec != null) 'spec': spec,
    if (unit != null) 'unit': unit,
    if (qty != null) 'qty': qty,
    if (removed) 'removed': true,
  };

  factory MaterialEdit.fromJson(Map<String, dynamic> j) => MaterialEdit(
    name: j['name'] as String?,
    spec: j['spec'] as String?,
    unit: j['unit'] as String?,
    qty: _double(j['qty']),
    removed: j['removed'] == true,
  );
}

/// Vật tư thêm tay vào một danh sách.
class MaterialExtra {
  MaterialExtra({
    String? id,
    this.name = '',
    this.spec = '',
    this.unit = '',
    this.qty = 1,
  }) : id = id ?? const Uuid().v4();
  final String id;
  String name;
  String spec;
  String unit;
  double qty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'spec': spec,
    'unit': unit,
    'qty': qty,
  };

  factory MaterialExtra.fromJson(Map<String, dynamic> j) => MaterialExtra(
    id: j['id'] as String?,
    name: j['name'] as String? ?? '',
    spec: j['spec'] as String? ?? '',
    unit: j['unit'] as String? ?? '',
    qty: _double(j['qty']) ?? 1,
  );
}

/// Phần sửa tay của một danh sách vật tư: sửa / xoá dòng tự tính (theo khóa
/// dòng) và vật tư thêm tay.
class MaterialListEdit {
  MaterialListEdit({
    Map<String, MaterialEdit>? rows,
    List<MaterialExtra>? extras,
  }) : rows = rows ?? {},
       extras = extras ?? [];
  final Map<String, MaterialEdit> rows;
  final List<MaterialExtra> extras;

  bool get isEmpty => rows.values.every((r) => r.isEmpty) && extras.isEmpty;

  Map<String, dynamic> toJson() => {
    'rows': {
      for (final e in rows.entries)
        if (!e.value.isEmpty) e.key: e.value.toJson(),
    },
    'extras': [for (final x in extras) x.toJson()],
  };

  factory MaterialListEdit.fromJson(Map<String, dynamic> j) => MaterialListEdit(
    rows: {
      for (final e in (j['rows'] as Map<String, dynamic>? ?? {}).entries)
        e.key: MaterialEdit.fromJson(e.value as Map<String, dynamic>),
    },
    extras: [
      for (final x in j['extras'] as List? ?? const [])
        MaterialExtra.fromJson(x as Map<String, dynamic>),
    ],
  );
}

/// Một phép đo giữa hai điểm trên mặt bằng phòng (mm).
class RoomMeasure {
  const RoomMeasure(this.ax, this.ay, this.bx, this.by);
  final double ax;
  final double ay;
  final double bx;
  final double by;

  Map<String, dynamic> toJson() => {
    'a': [ax, ay],
    'b': [bx, by],
  };

  factory RoomMeasure.fromJson(Map<String, dynamic> j) {
    final a = j['a'] as List;
    final b = j['b'] as List;
    return RoomMeasure(
      (a[0] as num).toDouble(),
      (a[1] as num).toDouble(),
      (b[0] as num).toDouble(),
      (b[1] as num).toDouble(),
    );
  }
}

/// Sửa tay tên/thông số một dòng thiết bị tự sinh (khóa theo `EquipmentItem.key`).
class EquipmentOverride {
  EquipmentOverride({this.name, this.spec});
  String? name;
  String? spec;

  bool get isEmpty =>
      (name ?? '').trim().isEmpty && (spec ?? '').trim().isEmpty;

  Map<String, dynamic> toJson() => {'name': name, 'spec': spec};
  factory EquipmentOverride.fromJson(Map<String, dynamic> j) =>
      EquipmentOverride(name: j['name'] as String?, spec: j['spec'] as String?);
}

/// Thiết bị người dùng tự thêm vào danh mục.
class ExtraEquipment {
  ExtraEquipment({String? id, this.name = '', this.spec = '', this.qty = 1})
    : id = id ?? const Uuid().v4();
  final String id;
  String name;
  String spec;
  int qty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'spec': spec,
    'qty': qty,
  };
  factory ExtraEquipment.fromJson(Map<String, dynamic> j) => ExtraEquipment(
    id: j['id'] as String?,
    name: j['name'] as String? ?? '',
    spec: j['spec'] as String? ?? '',
    qty: (j['qty'] as num?)?.toInt() ?? 1,
  );
}

class AirConfig {
  AirConfig({
    String? id,
    AirProject? project,
    CompressorConfig? compressor,
    TankConfig? tank,
    PretreatConfig? pretreat,
    AirTreatment? treatment,
    RoomConfig? room,
    PipeConfig? pipe,
    this.regen = RegenType.heatless,
    List<AirLine>? lines,
    Map<String, EquipmentOverride>? overrides,
    List<ExtraEquipment>? extraItems,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       project = project ?? AirProject(),
       // Cấu hình mới: mặc định "Chọn model".
       compressor =
           compressor ?? CompressorConfig(source: CompressorSource.catalog),
       tank = tank ?? TankConfig(),
       pretreat = pretreat ?? PretreatConfig(),
       treatment = treatment ?? AirTreatment(),
       room = room ?? RoomConfig(),
       pipe = pipe ?? PipeConfig(),
       lines = lines ?? [AirLine()],
       overrides = overrides ?? {},
       extraItems = extraItems ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// 2: line chỉ còn tên; điểm sương, lọc, áp sử dụng chuyển vào `treatment`.
  static const schemaVersion = 2;

  String id;
  final AirProject project;
  final CompressorConfig compressor;
  final TankConfig tank;
  final PretreatConfig pretreat;
  final AirTreatment treatment;
  final RoomConfig room;
  final PipeConfig pipe;
  RegenType regen;
  final List<AirLine> lines;
  final Map<String, EquipmentOverride> overrides;
  final List<ExtraEquipment> extraItems;
  DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'schema': 'dtc.air-config',
    'version': schemaVersion,
    'id': id,
    'project': project.toJson(),
    'compressor': compressor.toJson(),
    'tank': tank.toJson(),
    'pretreat': pretreat.toJson(),
    'treatment': treatment.toJson(),
    'room': room.toJson(),
    'pipe': pipe.toJson(),
    'desiccant': {'regen': regen.name},
    'lines': [for (final l in lines) l.toJson()],
    'overrides': {
      for (final e in overrides.entries)
        if (!e.value.isEmpty) e.key: e.value.toJson(),
    },
    'extraItems': [for (final x in extraItems) x.toJson()],
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Đọc JSON đã xuất; ném [FormatException] khi không đúng cấu trúc.
  factory AirConfig.fromJson(Map<String, dynamic> j) {
    if (j['lines'] is! List || j['compressor'] is! Map) {
      throw const FormatException('Không phải file cấu hình khí nén.');
    }
    Map<String, dynamic> map(String key) =>
        (j[key] as Map?)?.cast<String, dynamic>() ?? const {};
    final oldLines = j['lines'] as List;
    final hasTreatment = j['treatment'] is Map;
    // Cấu hình cũ: nhu cầu = tổng lưu lượng các line nếu chưa nhập.
    final compressor = CompressorConfig.fromJson(map('compressor'));
    if (!hasTreatment && compressor.demand == null) {
      final sum = oldLines.fold<double>(
        0,
        (s, l) => s + ((((l as Map)['flow']) as num?)?.toDouble() ?? 0),
      );
      if (sum > 0) compressor.demand = sum;
    }
    return AirConfig(
      id: j['id'] as String?,
      project: AirProject.fromJson(map('project')),
      compressor: compressor,
      tank: TankConfig.fromJson(map('tank')),
      pretreat: PretreatConfig.fromJson(map('pretreat')),
      treatment: hasTreatment
          ? AirTreatment.fromJson(map('treatment'))
          : AirTreatment.fromOldLines(oldLines),
      room: RoomConfig.fromJson(map('room')),
      pipe: PipeConfig.fromJson(map('pipe')),
      regen: _enum(
        RegenType.values,
        map('desiccant')['regen'],
        RegenType.heatless,
      ),
      lines: [
        for (final l in j['lines'] as List)
          AirLine.fromJson((l as Map).cast<String, dynamic>()),
      ],
      overrides: {
        for (final e in map('overrides').entries)
          e.key: EquipmentOverride.fromJson(
            (e.value as Map).cast<String, dynamic>(),
          ),
      },
      extraItems: [
        for (final x in (j['extraItems'] as List?) ?? const [])
          ExtraEquipment.fromJson((x as Map).cast<String, dynamic>()),
      ],
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
    );
  }

  AirConfig copy() => AirConfig.fromJson(toJson());

  /// Bản sao có id mới (nhân bản cấu hình).
  AirConfig duplicate({String? name}) {
    final now = DateTime.now();
    return copy()
      ..id = const Uuid().v4()
      ..createdAt = now
      ..updatedAt = now
      ..project.name = name ?? project.name;
  }
}
