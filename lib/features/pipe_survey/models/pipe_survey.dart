import 'package:uuid/uuid.dart';

import '../../air_system_config/models/air_config.dart';

/// Khảo sát tuyến ống khí nén tại công trình: thông tin chung, sơ đồ (điểm +
/// đoạn ống, toạ độ mét trên lưới), phần sửa tay danh sách vật tư. Lớp
/// mutable: màn hình sửa trực tiếp rồi lưu cả khối JSON.
class PipeSurvey {
  PipeSurvey({
    String? id,
    this.name = '',
    this.customer = '',
    this.address = '',
    this.surveyor = '',
    DateTime? surveyDate,
    this.buildingLengthM,
    this.buildingWidthM,
    this.hangHeightM,
    this.defaultDn = 50,
    this.drawingTitle = '',
    List<SurveyNode>? nodes,
    List<SurveySegment>? segments,
    List<SurveyShape>? shapes,
    Map<String, MaterialListEdit>? edits,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       surveyDate = surveyDate ?? DateTime.now(),
       nodes = nodes ?? [],
       segments = segments ?? [],
       shapes = shapes ?? [],
       edits = edits ?? {},
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;
  String customer;
  String address;
  String surveyor;
  DateTime surveyDate;

  /// Nhà xưởng (m) — khung tường bao trên sơ đồ, không bắt buộc.
  double? buildingLengthM;
  double? buildingWidthM;

  /// Độ cao treo ống (m), nhập tay theo thực tế.
  double? hangHeightM;

  /// Cỡ ống mặc định cho đoạn mới (DN).
  int defaultDn;

  /// Tên bản vẽ trong khung tên; trống = [defaultDrawingTitle].
  String drawingTitle;
  static const defaultDrawingTitle = 'SƠ ĐỒ TUYẾN ỐNG KHÍ NÉN';
  String get drawingTitleOrDefault =>
      drawingTitle.trim().isEmpty ? defaultDrawingTitle : drawingTitle.trim();

  final List<SurveyNode> nodes;
  final List<SurveySegment> segments;

  /// Hình nền (tường, cột, chướng ngại, ghi chú) — chỉ để thể hiện hiện
  /// trạng, không tính vật tư.
  final List<SurveyShape> shapes;

  /// Sửa tay danh sách vật tư (khóa `survey`), cùng kiểu Cấu hình khí nén.
  final Map<String, MaterialListEdit> edits;
  final DateTime createdAt;
  DateTime updatedAt;

  SurveyNode? node(String id) => nodes.where((n) => n.id == id).firstOrNull;

  /// Đoạn ống nối vào [nodeId].
  List<SurveySegment> segmentsAt(String nodeId) => [
    for (final s in segments)
      if (s.a == nodeId || s.b == nodeId) s,
  ];

  Iterable<SurveyNode> get usePoints =>
      nodes.where((n) => n.kind == SurveyNodeKind.usePoint);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'customer': customer,
    'address': address,
    'surveyor': surveyor,
    'surveyDate': surveyDate.toIso8601String(),
    'buildingLengthM': buildingLengthM,
    'buildingWidthM': buildingWidthM,
    'hangHeightM': hangHeightM,
    'defaultDn': defaultDn,
    'drawingTitle': drawingTitle,
    'nodes': [for (final n in nodes) n.toJson()],
    'segments': [for (final s in segments) s.toJson()],
    'shapes': [for (final s in shapes) s.toJson()],
    'edits': {
      for (final e in edits.entries)
        if (!e.value.isEmpty) e.key: e.value.toJson(),
    },
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory PipeSurvey.fromJson(Map<String, dynamic> j) => PipeSurvey(
    id: j['id'] as String?,
    name: j['name'] as String? ?? '',
    customer: j['customer'] as String? ?? '',
    address: j['address'] as String? ?? '',
    surveyor: j['surveyor'] as String? ?? '',
    surveyDate: DateTime.tryParse(j['surveyDate'] as String? ?? ''),
    buildingLengthM: (j['buildingLengthM'] as num?)?.toDouble(),
    buildingWidthM: (j['buildingWidthM'] as num?)?.toDouble(),
    hangHeightM: (j['hangHeightM'] as num?)?.toDouble(),
    defaultDn: (j['defaultDn'] as num?)?.toInt() ?? 50,
    drawingTitle: j['drawingTitle'] as String? ?? '',
    nodes: [
      for (final n in j['nodes'] as List? ?? const [])
        SurveyNode.fromJson(n as Map<String, dynamic>),
    ],
    shapes: [
      for (final s in j['shapes'] as List? ?? const [])
        SurveyShape.fromJson(s as Map<String, dynamic>),
    ],
    segments: [
      for (final s in j['segments'] as List? ?? const [])
        SurveySegment.fromJson(s as Map<String, dynamic>),
    ],
    edits: {
      for (final e in (j['edits'] as Map<String, dynamic>? ?? {}).entries)
        e.key: MaterialListEdit.fromJson(e.value as Map<String, dynamic>),
    },
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
  );

  /// Bản sao độc lập (qua JSON) — dùng cho hoàn tác.
  PipeSurvey copy() => PipeSurvey.fromJson(toJson());
}

enum SurveyNodeKind {
  /// Điểm nối / góc rẽ trên tuyến ống.
  junction,

  /// Cụm máy (điểm xuất phát).
  compressor,

  /// Điểm sử dụng khí (máy tách màu, thiết bị khác).
  usePoint,
}

/// Một điểm trên sơ đồ (toạ độ m, gốc góc trên trái).
class SurveyNode {
  SurveyNode({
    String? id,
    required this.x,
    required this.y,
    this.kind = SurveyNodeKind.junction,
    this.name = '',
    this.hangHeightM,
    this.connectionHeightM,
    this.dropDn,
    List<String>? photos,
    this.note = '',
    this.plant,
  }) : id = id ?? const Uuid().v4(),
       photos = photos ?? [];

  final String id;
  double x;
  double y;
  SurveyNodeKind kind;
  String name;

  /// Cao độ ống tại điểm này (m); `null` = độ cao treo ống của công trình.
  /// Hai điểm liền nhau khác cao độ: có ống đứng đổi cao độ.
  double? hangHeightM;

  /// Cao độ đầu nối ở máy (m); `null` = mặc định (2,5 m).
  double? connectionHeightM;

  /// Cỡ ống đứng xuống máy; `null` = cỡ nhỏ nhất của ống tại điểm.
  int? dropDn;

  /// Ảnh hiện trường (đường dẫn file), tuỳ chọn.
  final List<String> photos;
  String note;

  /// Cụm máy vẽ theo kích thước thật (như mặt bằng phòng lắp đặt); `null` =
  /// ký hiệu MN.
  SurveyPlant? plant;

  Map<String, dynamic> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'kind': kind.name,
    'name': name,
    'hangHeightM': hangHeightM,
    'connectionHeightM': connectionHeightM,
    'dropDn': dropDn,
    'photos': photos,
    'note': note,
    if (plant != null) 'plant': plant!.toJson(),
  };

  factory SurveyNode.fromJson(Map<String, dynamic> j) => SurveyNode(
    id: j['id'] as String?,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    kind:
        SurveyNodeKind.values.where((k) => k.name == j['kind']).firstOrNull ??
        SurveyNodeKind.junction,
    name: j['name'] as String? ?? '',
    hangHeightM: (j['hangHeightM'] as num?)?.toDouble(),
    connectionHeightM: (j['connectionHeightM'] as num?)?.toDouble(),
    dropDn: (j['dropDn'] as num?)?.toInt(),
    photos: [for (final p in j['photos'] as List? ?? const []) p as String],
    note: j['note'] as String? ?? '',
    plant: j['plant'] is Map<String, dynamic>
        ? SurveyPlant.fromJson(j['plant'] as Map<String, dynamic>)
        : null,
  );
}

/// Nguồn thiết bị của cụm máy: chọn nhanh model, hoặc lấy từ một cấu hình hệ
/// thống khí nén đã lưu.
enum SurveyPlantSource { quick, config }

/// Hướng ống ra khỏi cụm máy trên sơ đồ; `auto` = theo đoạn ống nối vào.
enum SurveyPlantDir { auto, right, down, left, up }

/// Cụm máy theo kích thước thật: thiết bị (máy nén, bình, máy sấy, lọc) xếp
/// như phòng lắp đặt tối thiểu theo một trong 3 phương án.
class SurveyPlant {
  SurveyPlant({
    this.source = SurveyPlantSource.quick,
    this.type = CompressorType.pmVsd,
    this.modelCode,
    this.pressure = 8,
    this.configId,
    this.configName = '',
    this.configJson,
    this.style = RoomStyle.option1,
    this.dir = SurveyPlantDir.auto,
    this.flip = false,
  });

  SurveyPlantSource source;

  /// Chọn nhanh: loại máy, model, áp suất làm việc (bar).
  CompressorType type;
  String? modelCode;
  double pressure;

  /// Cấu hình đã lưu: id, tên và bản chụp lúc chọn (vẫn vẽ được khi cấu hình
  /// gốc bị xoá).
  String? configId;
  String configName;
  Map<String, dynamic>? configJson;

  RoomStyle style;
  SurveyPlantDir dir;

  /// Đặt thiết bị sang phía bên kia đường ống.
  bool flip;

  /// Đủ dữ liệu để tính.
  bool get ready => switch (source) {
    SurveyPlantSource.quick => modelCode != null,
    SurveyPlantSource.config => configJson != null,
  };

  /// Cấu hình dùng để tính thiết bị và phòng tối thiểu theo [style] (bỏ phòng
  /// thực tế, vị trí kéo tay); `null` khi chưa đủ dữ liệu.
  AirConfig? airConfig() {
    final AirConfig config;
    switch (source) {
      case SurveyPlantSource.quick:
        if (modelCode == null) return null;
        config = AirConfig(
          compressor: CompressorConfig(
            type: type,
            pressure: pressure,
            source: CompressorSource.catalog,
            modelCode: modelCode,
          ),
        );
      case SurveyPlantSource.config:
        final j = configJson;
        if (j == null) return null;
        config = AirConfig.fromJson(j);
    }
    config.room
      ..lengthM = null
      ..widthM = null
      ..heightM = null
      ..style = style
      ..positions.clear()
      ..turned.clear();
    return config;
  }

  Map<String, dynamic> toJson() => {
    'source': source.name,
    'type': type.name,
    'modelCode': modelCode,
    'pressure': pressure,
    'configId': configId,
    'configName': configName,
    'configJson': configJson,
    'style': style.name,
    'dir': dir.name,
    'flip': flip,
  };

  factory SurveyPlant.fromJson(Map<String, dynamic> j) => SurveyPlant(
    source:
        SurveyPlantSource.values
            .where((v) => v.name == j['source'])
            .firstOrNull ??
        SurveyPlantSource.quick,
    type: CompressorType.fromJson(j['type'], null),
    modelCode: j['modelCode'] as String?,
    pressure: (j['pressure'] as num?)?.toDouble() ?? 8,
    configId: j['configId'] as String?,
    configName: j['configName'] as String? ?? '',
    configJson: j['configJson'] as Map<String, dynamic>?,
    style:
        RoomStyle.values.where((v) => v.name == j['style']).firstOrNull ??
        RoomStyle.option1,
    dir:
        SurveyPlantDir.values.where((v) => v.name == j['dir']).firstOrNull ??
        SurveyPlantDir.auto,
    flip: j['flip'] as bool? ?? false,
  );

  /// Bản sao (bản chụp cấu hình dùng chung, không sửa tại chỗ).
  SurveyPlant copy() => SurveyPlant.fromJson(toJson());
}

/// Một đoạn ống thẳng giữa hai điểm.
class SurveySegment {
  SurveySegment({
    String? id,
    required this.a,
    required this.b,
    this.dn,
    this.measuredM,
    this.note = '',
    this.obstacles = 0,
    this.obstacleRiseM,
  }) : id = id ?? const Uuid().v4();

  final String id;
  String a;
  String b;

  /// Cỡ ống; `null` = cỡ mặc định của công trình.
  int? dn;

  /// Chiều dài đo thực tế (m); `null` = theo hình vẽ.
  double? measuredM;
  String note;

  /// Số lần vượt chướng ngại trên đoạn (lên / xuống rồi trở lại cao độ cũ).
  int obstacles;

  /// Chênh cao mỗi lần vượt (m): dương = vượt lên, âm = vượt xuống.
  double? obstacleRiseM;

  /// Có vượt chướng ngại tính được vật tư.
  bool get hasObstacles => obstacles > 0 && (obstacleRiseM ?? 0).abs() > 1e-9;

  String other(String nodeId) => nodeId == a ? b : a;

  Map<String, dynamic> toJson() => {
    'id': id,
    'a': a,
    'b': b,
    'dn': dn,
    'measuredM': measuredM,
    'note': note,
    'obstacles': obstacles,
    'obstacleRiseM': obstacleRiseM,
  };

  factory SurveySegment.fromJson(Map<String, dynamic> j) => SurveySegment(
    id: j['id'] as String?,
    a: j['a'] as String,
    b: j['b'] as String,
    dn: (j['dn'] as num?)?.toInt(),
    measuredM: (j['measuredM'] as num?)?.toDouble(),
    note: j['note'] as String? ?? '',
    obstacles: (j['obstacles'] as num?)?.toInt() ?? 0,
    obstacleRiseM: (j['obstacleRiseM'] as num?)?.toDouble(),
  );
}

enum SurveyShapeKind {
  /// Tường: đoạn thẳng (x1, y1) – (x2, y2), dày [SurveyShape.sizeM].
  wall,

  /// Cột: hình chữ nhật tâm (x1, y1), rộng [SurveyShape.sizeM] × sâu
  /// [SurveyShape.size2M].
  column,

  /// Chướng ngại: hình chữ nhật góc (x1, y1) – (x2, y2), có tên.
  obstacle,

  /// Ghi chú: chữ [SurveyShape.label] tại (x1, y1).
  note,

  /// Chú thích mũi tên: mũi tên chỉ vào (x1, y1), chữ tại (x2, y2).
  leader,

  /// Tên vùng / khu vực: chữ lớn căn giữa tại (x1, y1), cao
  /// [SurveyShape.sizeM] m.
  area,
}

/// Một hình nền trên sơ đồ (toạ độ m).
class SurveyShape {
  SurveyShape({
    String? id,
    required this.kind,
    required this.x1,
    required this.y1,
    double? x2,
    double? y2,
    this.label = '',
    this.sizeM,
    this.size2M,
  }) : id = id ?? const Uuid().v4(),
       x2 = x2 ?? x1,
       y2 = y2 ?? y1;

  final String id;
  final SurveyShapeKind kind;
  double x1;
  double y1;
  double x2;
  double y2;
  String label;

  /// Tường: độ dày; cột: chiều rộng; tên vùng: chiều cao chữ (m).
  /// `null` = mặc định.
  double? sizeM;

  /// Cột: chiều sâu (m). `null` = bằng chiều rộng.
  double? size2M;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'x1': x1,
    'y1': y1,
    'x2': x2,
    'y2': y2,
    'label': label,
    'sizeM': sizeM,
    'size2M': size2M,
  };

  factory SurveyShape.fromJson(Map<String, dynamic> j) => SurveyShape(
    id: j['id'] as String?,
    kind:
        SurveyShapeKind.values.where((k) => k.name == j['kind']).firstOrNull ??
        SurveyShapeKind.note,
    x1: (j['x1'] as num).toDouble(),
    y1: (j['y1'] as num).toDouble(),
    x2: (j['x2'] as num?)?.toDouble(),
    y2: (j['y2'] as num?)?.toDouble(),
    label: j['label'] as String? ?? '',
    sizeM: (j['sizeM'] as num?)?.toDouble(),
    size2M: (j['size2M'] as num?)?.toDouble(),
  );
}
