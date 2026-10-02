import 'dart:math' as math;

enum SiteDimensionUnit {
  meter('m', 1000, 3),
  centimeter('cm', 10, 1),
  millimeter('mm', 1, 1);

  const SiteDimensionUnit(this.symbol, this.millimetersPerUnit, this.decimals);

  final String symbol;
  final double millimetersPerUnit;
  final int decimals;

  double toMillimeters(double value) => value * millimetersPerUnit;

  double fromMillimeters(double value) => value / millimetersPerUnit;

  double? parseToMillimeters(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    return parsed == null ? null : toMillimeters(parsed);
  }

  String formatValue(double millimeters) {
    var value = fromMillimeters(millimeters).toStringAsFixed(decimals);
    while (value.contains('.') && value.endsWith('0')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.endsWith('.')) value = value.substring(0, value.length - 1);
    return value;
  }

  String format(double millimeters) => '${formatValue(millimeters)} $symbol';

  static SiteDimensionUnit fromStorage(Object? value) => values.firstWhere(
    (unit) => unit.name == value,
    orElse: () => SiteDimensionUnit.meter,
  );
}

enum SiteObjectType {
  wall('Tường'),
  column('Cột'),
  door('Cửa'),
  bucketElevator('Gàu tải'),
  walkway('Lối đi'),
  line('Đường thẳng'),
  restrictedArea('Vùng cấm'),
  existingMachine('Máy hiện hữu'),
  obstacle('Chướng ngại vật');

  const SiteObjectType(this.label);
  final String label;
}

extension SiteObjectTypeGeometry on SiteObjectType {
  bool get isLinear =>
      this == SiteObjectType.wall ||
      this == SiteObjectType.door ||
      this == SiteObjectType.walkway ||
      this == SiteObjectType.line;
}

enum EditorTool {
  select('Chọn'),
  pan('Di chuyển'),
  wall('Tường'),
  column('Cột'),
  door('Cửa'),
  bucketElevator('Gàu tải'),
  walkway('Lối đi'),
  line('Đường thẳng'),
  restrictedArea('Vùng cấm'),
  obstacle('Chướng ngại'),
  existingMachine('Máy hiện hữu'),
  trim('Cắt'),
  measure('Đo'),
  note('Ghi chú'),
  photoMarker('Đánh dấu ảnh');

  const EditorTool(this.label);
  final String label;
}

enum LayoutWarningType {
  physicalOverlap,
  clearance,
  outOfBounds,
  height,
  missingData,
}

int _lastGeneratedSiteLayoutId = 0;

String newSiteLayoutId(String prefix) {
  final now = DateTime.now().microsecondsSinceEpoch;
  _lastGeneratedSiteLayoutId = math.max(now, _lastGeneratedSiteLayoutId + 1);
  return '${prefix}_$_lastGeneratedSiteLayoutId';
}

class SiteLayoutProject {
  const SiteLayoutProject({
    required this.id,
    required this.name,
    this.customer = '',
    this.location = '',
    this.surveyor = '',
    required this.surveyDate,
    this.notes = '',
    required this.siteWidthMm,
    required this.siteLengthMm,
    this.ceilingHeightMm,
    this.lowestBeamHeightMm,
    this.dimensionTextScale = 1.5,
    this.dimensionUnit = SiteDimensionUnit.meter,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String customer;
  final String location;
  final String surveyor;
  final DateTime surveyDate;
  final String notes;
  final double siteWidthMm;
  final double siteLengthMm;
  final double? ceilingHeightMm;
  final double? lowestBeamHeightMm;
  final double dimensionTextScale;
  final SiteDimensionUnit dimensionUnit;
  final DateTime createdAt;
  final DateTime updatedAt;

  SiteLayoutProject copyWith({
    String? name,
    String? customer,
    String? location,
    String? surveyor,
    DateTime? surveyDate,
    String? notes,
    double? siteWidthMm,
    double? siteLengthMm,
    double? ceilingHeightMm,
    bool clearCeilingHeight = false,
    double? lowestBeamHeightMm,
    bool clearLowestBeamHeight = false,
    double? dimensionTextScale,
    SiteDimensionUnit? dimensionUnit,
    DateTime? updatedAt,
  }) => SiteLayoutProject(
    id: id,
    name: name ?? this.name,
    customer: customer ?? this.customer,
    location: location ?? this.location,
    surveyor: surveyor ?? this.surveyor,
    surveyDate: surveyDate ?? this.surveyDate,
    notes: notes ?? this.notes,
    siteWidthMm: siteWidthMm ?? this.siteWidthMm,
    siteLengthMm: siteLengthMm ?? this.siteLengthMm,
    ceilingHeightMm: clearCeilingHeight
        ? null
        : ceilingHeightMm ?? this.ceilingHeightMm,
    lowestBeamHeightMm: clearLowestBeamHeight
        ? null
        : lowestBeamHeightMm ?? this.lowestBeamHeightMm,
    dimensionTextScale: dimensionTextScale ?? this.dimensionTextScale,
    dimensionUnit: dimensionUnit ?? this.dimensionUnit,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory SiteLayoutProject.fromMap(Map<String, Object?> map) =>
      SiteLayoutProject(
        id: map['id']! as String,
        name: map['name']! as String,
        customer: map['customer'] as String? ?? '',
        location: map['location'] as String? ?? '',
        surveyor: map['surveyor'] as String? ?? '',
        surveyDate: DateTime.parse(map['surveyDate']! as String),
        notes: map['notes'] as String? ?? '',
        siteWidthMm: (map['siteWidthMm']! as num).toDouble(),
        siteLengthMm: (map['siteLengthMm']! as num).toDouble(),
        ceilingHeightMm: (map['ceilingHeightMm'] as num?)?.toDouble(),
        lowestBeamHeightMm: (map['lowestBeamHeightMm'] as num?)?.toDouble(),
        dimensionTextScale:
            (map['dimensionTextScale'] as num?)?.toDouble() ?? 1.5,
        dimensionUnit: SiteDimensionUnit.fromStorage(map['dimensionUnit']),
        createdAt: DateTime.parse(map['createdAt']! as String),
        updatedAt: DateTime.parse(map['updatedAt']! as String),
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'customer': customer,
    'location': location,
    'surveyor': surveyor,
    'surveyDate': surveyDate.toIso8601String(),
    'notes': notes,
    'siteWidthMm': siteWidthMm,
    'siteLengthMm': siteLengthMm,
    'ceilingHeightMm': ceilingHeightMm,
    'lowestBeamHeightMm': lowestBeamHeightMm,
    'dimensionTextScale': dimensionTextScale,
    'dimensionUnit': dimensionUnit.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class SiteLayoutVariant {
  const SiteLayoutVariant({
    required this.id,
    required this.projectId,
    required this.name,
    this.isPreferred = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String name;
  final bool isPreferred;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  SiteLayoutVariant copyWith({
    String? name,
    bool? isPreferred,
    int? sortOrder,
    DateTime? updatedAt,
  }) => SiteLayoutVariant(
    id: id,
    projectId: projectId,
    name: name ?? this.name,
    isPreferred: isPreferred ?? this.isPreferred,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory SiteLayoutVariant.fromMap(Map<String, Object?> map) =>
      SiteLayoutVariant(
        id: map['id']! as String,
        projectId: map['projectId']! as String,
        name: map['name']! as String,
        isPreferred: (map['isPreferred'] as int? ?? 0) == 1,
        sortOrder: map['sortOrder'] as int? ?? 0,
        createdAt: DateTime.parse(map['createdAt']! as String),
        updatedAt: DateTime.parse(map['updatedAt']! as String),
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'projectId': projectId,
    'name': name,
    'isPreferred': isPreferred ? 1 : 0,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class SiteLayoutObject {
  const SiteLayoutObject({
    required this.id,
    required this.layoutId,
    required this.type,
    required this.xMm,
    required this.yMm,
    required this.widthMm,
    required this.lengthMm,
    this.rotationDeg = 0,
    this.isLocked = false,
    this.zIndex = 0,
    this.label = '',
    this.note = '',
  });

  final String id;
  final String layoutId;
  final SiteObjectType type;
  final double xMm;
  final double yMm;
  final double widthMm;
  final double lengthMm;
  final double rotationDeg;
  final bool isLocked;
  final int zIndex;
  final String label;
  final String note;

  double get renderedWidthMm {
    final normalized = ((rotationDeg % 180) + 180) % 180;
    if (normalized.abs() < 1e-9) return widthMm;
    if ((normalized - 90).abs() < 1e-9) return lengthMm;
    final radians = rotationDeg * math.pi / 180;
    return widthMm * math.cos(radians).abs() +
        lengthMm * math.sin(radians).abs();
  }

  double get renderedLengthMm {
    final normalized = ((rotationDeg % 180) + 180) % 180;
    if (normalized.abs() < 1e-9) return lengthMm;
    if ((normalized - 90).abs() < 1e-9) return widthMm;
    final radians = rotationDeg * math.pi / 180;
    return widthMm * math.sin(radians).abs() +
        lengthMm * math.cos(radians).abs();
  }

  SiteLayoutObject copyWith({
    String? id,
    String? layoutId,
    SiteObjectType? type,
    double? xMm,
    double? yMm,
    double? widthMm,
    double? lengthMm,
    double? rotationDeg,
    bool? isLocked,
    int? zIndex,
    String? label,
    String? note,
  }) => SiteLayoutObject(
    id: id ?? this.id,
    layoutId: layoutId ?? this.layoutId,
    type: type ?? this.type,
    xMm: xMm ?? this.xMm,
    yMm: yMm ?? this.yMm,
    widthMm: widthMm ?? this.widthMm,
    lengthMm: lengthMm ?? this.lengthMm,
    rotationDeg: rotationDeg ?? this.rotationDeg,
    isLocked: isLocked ?? this.isLocked,
    zIndex: zIndex ?? this.zIndex,
    label: label ?? this.label,
    note: note ?? this.note,
  );

  factory SiteLayoutObject.fromMap(Map<String, Object?> map) =>
      SiteLayoutObject(
        id: map['id']! as String,
        layoutId: map['layoutId']! as String,
        type: SiteObjectType.values.byName(map['type']! as String),
        xMm: (map['xMm']! as num).toDouble(),
        yMm: (map['yMm']! as num).toDouble(),
        widthMm: (map['widthMm']! as num).toDouble(),
        lengthMm: (map['lengthMm']! as num).toDouble(),
        rotationDeg: (map['rotationDeg'] as num? ?? 0).toDouble(),
        isLocked: (map['isLocked'] as int? ?? 0) == 1,
        zIndex: map['zIndex'] as int? ?? 0,
        label: map['label'] as String? ?? '',
        note: map['note'] as String? ?? '',
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'layoutId': layoutId,
    'type': type.name,
    'xMm': xMm,
    'yMm': yMm,
    'widthMm': widthMm,
    'lengthMm': lengthMm,
    'rotationDeg': rotationDeg,
    'isLocked': isLocked ? 1 : 0,
    'zIndex': zIndex,
    'label': label,
    'note': note,
  };
}

class CatalogMachineLayoutData {
  const CatalogMachineLayoutData({
    required this.sourceType,
    required this.sourceId,
    required this.category,
    required this.model,
    required this.displayName,
    this.lengthMm,
    this.widthMm,
    this.heightMm,
    this.imagePath,
    this.invalidReason,
  });

  final String sourceType;
  final String sourceId;
  final String category;
  final String model;
  final String displayName;
  final double? lengthMm;
  final double? widthMm;
  final double? heightMm;
  final String? imagePath;
  final String? invalidReason;

  bool get canPlace =>
      invalidReason == null &&
      lengthMm != null &&
      widthMm != null &&
      heightMm != null &&
      lengthMm! > 0 &&
      widthMm! > 0 &&
      heightMm! > 0;
}

class MachinePlacement {
  const MachinePlacement({
    required this.id,
    required this.layoutId,
    required this.sourceType,
    required this.sourceId,
    required this.category,
    required this.model,
    required this.displayName,
    this.imagePath,
    required this.xMm,
    required this.yMm,
    this.rotationDeg = 0,
    this.isLocked = false,
    this.zIndex = 0,
    required this.lengthMm,
    required this.widthMm,
    required this.heightMm,
    this.clearanceFrontMm = 0,
    this.clearanceRearMm = 0,
    this.clearanceLeftMm = 0,
    this.clearanceRightMm = 0,
    this.clearanceTopMm = 0,
    this.clearanceVerified = false,
    this.floorToBaseMm = 0,
  });

  final String id;
  final String layoutId;
  final String sourceType;
  final String sourceId;
  final String category;
  final String model;
  final String displayName;
  final String? imagePath;
  final double xMm;
  final double yMm;
  final double rotationDeg;
  final bool isLocked;
  final int zIndex;
  final double lengthMm;
  final double widthMm;
  final double heightMm;
  final double clearanceFrontMm;
  final double clearanceRearMm;
  final double clearanceLeftMm;
  final double clearanceRightMm;
  final double clearanceTopMm;
  final bool clearanceVerified;
  final double floorToBaseMm;

  double get renderedWidthMm {
    final normalized = ((rotationDeg % 180) + 180) % 180;
    if (normalized.abs() < 1e-9) return widthMm;
    if ((normalized - 90).abs() < 1e-9) return lengthMm;
    final radians = rotationDeg * math.pi / 180;
    return widthMm * math.cos(radians).abs() +
        lengthMm * math.sin(radians).abs();
  }

  double get renderedLengthMm {
    final normalized = ((rotationDeg % 180) + 180) % 180;
    if (normalized.abs() < 1e-9) return lengthMm;
    if ((normalized - 90).abs() < 1e-9) return widthMm;
    final radians = rotationDeg * math.pi / 180;
    return widthMm * math.sin(radians).abs() +
        lengthMm * math.cos(radians).abs();
  }

  double get installedTopMm => floorToBaseMm + heightMm;
  double get requiredHeightMm => installedTopMm + clearanceTopMm;

  MachinePlacement copyWith({
    String? id,
    String? layoutId,
    double? xMm,
    double? yMm,
    double? rotationDeg,
    bool? isLocked,
    int? zIndex,
    double? clearanceFrontMm,
    double? clearanceRearMm,
    double? clearanceLeftMm,
    double? clearanceRightMm,
    double? clearanceTopMm,
    bool? clearanceVerified,
    double? floorToBaseMm,
  }) => MachinePlacement(
    id: id ?? this.id,
    layoutId: layoutId ?? this.layoutId,
    sourceType: sourceType,
    sourceId: sourceId,
    category: category,
    model: model,
    displayName: displayName,
    imagePath: imagePath,
    xMm: xMm ?? this.xMm,
    yMm: yMm ?? this.yMm,
    rotationDeg: rotationDeg ?? this.rotationDeg,
    isLocked: isLocked ?? this.isLocked,
    zIndex: zIndex ?? this.zIndex,
    lengthMm: lengthMm,
    widthMm: widthMm,
    heightMm: heightMm,
    clearanceFrontMm: clearanceFrontMm ?? this.clearanceFrontMm,
    clearanceRearMm: clearanceRearMm ?? this.clearanceRearMm,
    clearanceLeftMm: clearanceLeftMm ?? this.clearanceLeftMm,
    clearanceRightMm: clearanceRightMm ?? this.clearanceRightMm,
    clearanceTopMm: clearanceTopMm ?? this.clearanceTopMm,
    clearanceVerified: clearanceVerified ?? this.clearanceVerified,
    floorToBaseMm: floorToBaseMm ?? this.floorToBaseMm,
  );

  factory MachinePlacement.fromMap(Map<String, Object?> map) =>
      MachinePlacement(
        id: map['id']! as String,
        layoutId: map['layoutId']! as String,
        sourceType: map['sourceType']! as String,
        sourceId: map['sourceId']! as String,
        category: map['category']! as String,
        model: map['model']! as String,
        displayName: map['displayName']! as String,
        imagePath: map['imagePath'] as String?,
        xMm: (map['xMm']! as num).toDouble(),
        yMm: (map['yMm']! as num).toDouble(),
        rotationDeg: (map['rotationDeg'] as num? ?? 0).toDouble(),
        isLocked: (map['isLocked'] as int? ?? 0) == 1,
        zIndex: map['zIndex'] as int? ?? 0,
        lengthMm: (map['lengthMm']! as num).toDouble(),
        widthMm: (map['widthMm']! as num).toDouble(),
        heightMm: (map['heightMm']! as num).toDouble(),
        clearanceFrontMm: (map['clearanceFrontMm'] as num? ?? 0).toDouble(),
        clearanceRearMm: (map['clearanceRearMm'] as num? ?? 0).toDouble(),
        clearanceLeftMm: (map['clearanceLeftMm'] as num? ?? 0).toDouble(),
        clearanceRightMm: (map['clearanceRightMm'] as num? ?? 0).toDouble(),
        clearanceTopMm: (map['clearanceTopMm'] as num? ?? 0).toDouble(),
        clearanceVerified: (map['clearanceVerified'] as int? ?? 0) == 1,
        floorToBaseMm: (map['floorToBaseMm'] as num? ?? 0).toDouble(),
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'layoutId': layoutId,
    'sourceType': sourceType,
    'sourceId': sourceId,
    'category': category,
    'model': model,
    'displayName': displayName,
    'imagePath': imagePath,
    'xMm': xMm,
    'yMm': yMm,
    'rotationDeg': rotationDeg,
    'isLocked': isLocked ? 1 : 0,
    'zIndex': zIndex,
    'lengthMm': lengthMm,
    'widthMm': widthMm,
    'heightMm': heightMm,
    'clearanceFrontMm': clearanceFrontMm,
    'clearanceRearMm': clearanceRearMm,
    'clearanceLeftMm': clearanceLeftMm,
    'clearanceRightMm': clearanceRightMm,
    'clearanceTopMm': clearanceTopMm,
    'clearanceVerified': clearanceVerified ? 1 : 0,
    'floorToBaseMm': floorToBaseMm,
  };
}

class LayoutMeasurement {
  const LayoutMeasurement({
    required this.id,
    required this.layoutId,
    required this.x1Mm,
    required this.y1Mm,
    required this.x2Mm,
    required this.y2Mm,
    this.label = '',
    this.note = '',
  });

  final String id;
  final String layoutId;
  final double x1Mm;
  final double y1Mm;
  final double x2Mm;
  final double y2Mm;
  final String label;
  final String note;

  double get distanceMm =>
      math.sqrt(math.pow(x2Mm - x1Mm, 2) + math.pow(y2Mm - y1Mm, 2));

  LayoutMeasurement copyWith({
    String? id,
    String? layoutId,
    double? x1Mm,
    double? y1Mm,
    double? x2Mm,
    double? y2Mm,
    String? label,
    String? note,
  }) => LayoutMeasurement(
    id: id ?? this.id,
    layoutId: layoutId ?? this.layoutId,
    x1Mm: x1Mm ?? this.x1Mm,
    y1Mm: y1Mm ?? this.y1Mm,
    x2Mm: x2Mm ?? this.x2Mm,
    y2Mm: y2Mm ?? this.y2Mm,
    label: label ?? this.label,
    note: note ?? this.note,
  );

  factory LayoutMeasurement.fromMap(Map<String, Object?> map) =>
      LayoutMeasurement(
        id: map['id']! as String,
        layoutId: map['layoutId']! as String,
        x1Mm: (map['x1Mm']! as num).toDouble(),
        y1Mm: (map['y1Mm']! as num).toDouble(),
        x2Mm: (map['x2Mm']! as num).toDouble(),
        y2Mm: (map['y2Mm']! as num).toDouble(),
        label: map['label'] as String? ?? '',
        note: map['note'] as String? ?? '',
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'layoutId': layoutId,
    'x1Mm': x1Mm,
    'y1Mm': y1Mm,
    'x2Mm': x2Mm,
    'y2Mm': y2Mm,
    'label': label,
    'note': note,
  };
}

class LayoutAnnotation {
  const LayoutAnnotation({
    required this.id,
    required this.layoutId,
    required this.xMm,
    required this.yMm,
    required this.text,
    this.markerNumber,
  });

  final String id;
  final String layoutId;
  final double xMm;
  final double yMm;
  final String text;
  final int? markerNumber;

  LayoutAnnotation copyWith({String? id, String? layoutId}) => LayoutAnnotation(
    id: id ?? this.id,
    layoutId: layoutId ?? this.layoutId,
    xMm: xMm,
    yMm: yMm,
    text: text,
    markerNumber: markerNumber,
  );

  factory LayoutAnnotation.fromMap(Map<String, Object?> map) =>
      LayoutAnnotation(
        id: map['id']! as String,
        layoutId: map['layoutId']! as String,
        xMm: (map['xMm']! as num).toDouble(),
        yMm: (map['yMm']! as num).toDouble(),
        text: map['text']! as String,
        markerNumber: map['markerNumber'] as int?,
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'layoutId': layoutId,
    'xMm': xMm,
    'yMm': yMm,
    'text': text,
    'markerNumber': markerNumber,
  };
}

class SitePhoto {
  const SitePhoto({
    required this.id,
    required this.projectId,
    required this.originalPath,
    this.thumbnailPath,
    this.caption = '',
    this.note = '',
    required this.capturedAt,
    required this.createdAt,
  });

  final String id;
  final String projectId;
  final String originalPath;
  final String? thumbnailPath;
  final String caption;
  final String note;
  final DateTime capturedAt;
  final DateTime createdAt;

  factory SitePhoto.fromMap(Map<String, Object?> map) => SitePhoto(
    id: map['id']! as String,
    projectId: map['projectId']! as String,
    originalPath: map['originalPath']! as String,
    thumbnailPath: map['thumbnailPath'] as String?,
    caption: map['caption'] as String? ?? '',
    note: map['note'] as String? ?? '',
    capturedAt: DateTime.parse(map['capturedAt']! as String),
    createdAt: DateTime.parse(map['createdAt']! as String),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'projectId': projectId,
    'originalPath': originalPath,
    'thumbnailPath': thumbnailPath,
    'caption': caption,
    'note': note,
    'capturedAt': capturedAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
}

class PhotoMarker {
  const PhotoMarker({
    required this.id,
    required this.layoutId,
    required this.photoId,
    required this.markerNumber,
    required this.xMm,
    required this.yMm,
  });

  final String id;
  final String layoutId;
  final String photoId;
  final int markerNumber;
  final double xMm;
  final double yMm;

  PhotoMarker copyWith({String? id, String? layoutId}) => PhotoMarker(
    id: id ?? this.id,
    layoutId: layoutId ?? this.layoutId,
    photoId: photoId,
    markerNumber: markerNumber,
    xMm: xMm,
    yMm: yMm,
  );

  factory PhotoMarker.fromMap(Map<String, Object?> map) => PhotoMarker(
    id: map['id']! as String,
    layoutId: map['layoutId']! as String,
    photoId: map['photoId']! as String,
    markerNumber: map['markerNumber']! as int,
    xMm: (map['xMm']! as num).toDouble(),
    yMm: (map['yMm']! as num).toDouble(),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'layoutId': layoutId,
    'photoId': photoId,
    'markerNumber': markerNumber,
    'xMm': xMm,
    'yMm': yMm,
  };
}

class LayoutWarning {
  const LayoutWarning({
    required this.type,
    required this.title,
    required this.message,
    this.subjectId,
    this.blockerId,
    this.requiredMm,
    this.actualMm,
  });

  final LayoutWarningType type;
  final String title;
  final String message;
  final String? subjectId;
  final String? blockerId;
  final double? requiredMm;
  final double? actualMm;

  double? get shortageMm => requiredMm == null || actualMm == null
      ? null
      : math.max(0, requiredMm! - actualMm!);
}

class SiteLayoutBundle {
  const SiteLayoutBundle({
    required this.project,
    required this.layout,
    this.objects = const [],
    this.machines = const [],
    this.measurements = const [],
    this.annotations = const [],
    this.photos = const [],
    this.photoMarkers = const [],
  });

  final SiteLayoutProject project;
  final SiteLayoutVariant layout;
  final List<SiteLayoutObject> objects;
  final List<MachinePlacement> machines;
  final List<LayoutMeasurement> measurements;
  final List<LayoutAnnotation> annotations;
  final List<SitePhoto> photos;
  final List<PhotoMarker> photoMarkers;

  SiteLayoutBundle copyWith({
    SiteLayoutProject? project,
    SiteLayoutVariant? layout,
    List<SiteLayoutObject>? objects,
    List<MachinePlacement>? machines,
    List<LayoutMeasurement>? measurements,
    List<LayoutAnnotation>? annotations,
    List<SitePhoto>? photos,
    List<PhotoMarker>? photoMarkers,
  }) => SiteLayoutBundle(
    project: project ?? this.project,
    layout: layout ?? this.layout,
    objects: objects ?? this.objects,
    machines: machines ?? this.machines,
    measurements: measurements ?? this.measurements,
    annotations: annotations ?? this.annotations,
    photos: photos ?? this.photos,
    photoMarkers: photoMarkers ?? this.photoMarkers,
  );
}
