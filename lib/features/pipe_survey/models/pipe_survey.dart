import 'package:uuid/uuid.dart';

import '../../air_system_config/models/air_config.dart' show MaterialListEdit;

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
    List<SurveyNode>? nodes,
    List<SurveySegment>? segments,
    Map<String, MaterialListEdit>? edits,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? const Uuid().v4(),
       surveyDate = surveyDate ?? DateTime.now(),
       nodes = nodes ?? [],
       segments = segments ?? [],
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

  final List<SurveyNode> nodes;
  final List<SurveySegment> segments;

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
    'nodes': [for (final n in nodes) n.toJson()],
    'segments': [for (final s in segments) s.toJson()],
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
    nodes: [
      for (final n in j['nodes'] as List? ?? const [])
        SurveyNode.fromJson(n as Map<String, dynamic>),
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
  }) : id = id ?? const Uuid().v4(),
       photos = photos ?? [];

  final String id;
  double x;
  double y;
  SurveyNodeKind kind;
  String name;

  /// Độ cao treo ống tại điểm này (m); `null` = theo công trình.
  double? hangHeightM;

  /// Cao độ đầu nối ở máy (m); `null` = mặc định (2,5 m).
  double? connectionHeightM;

  /// Cỡ ống đứng xuống máy; `null` = cỡ nhỏ nhất của ống tại điểm.
  int? dropDn;

  /// Ảnh hiện trường (đường dẫn file), tuỳ chọn.
  final List<String> photos;
  String note;

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
  );
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
  }) : id = id ?? const Uuid().v4();

  final String id;
  String a;
  String b;

  /// Cỡ ống; `null` = cỡ mặc định của công trình.
  int? dn;

  /// Chiều dài đo thực tế (m); `null` = theo hình vẽ.
  double? measuredM;
  String note;

  String other(String nodeId) => nodeId == a ? b : a;

  Map<String, dynamic> toJson() => {
    'id': id,
    'a': a,
    'b': b,
    'dn': dn,
    'measuredM': measuredM,
    'note': note,
  };

  factory SurveySegment.fromJson(Map<String, dynamic> j) => SurveySegment(
    id: j['id'] as String?,
    a: j['a'] as String,
    b: j['b'] as String,
    dn: (j['dn'] as num?)?.toInt(),
    measuredM: (j['measuredM'] as num?)?.toDouble(),
    note: j['note'] as String? ?? '',
  );
}
