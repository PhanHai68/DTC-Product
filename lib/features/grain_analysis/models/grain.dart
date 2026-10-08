/// Một vật thể đã tách khỏi nền (mục 6 tài liệu yêu cầu). Không import
/// Flutter để module thuật toán và script dòng lệnh dùng chung.
///
/// Tọa độ ([contour], [centroidX], [centroidY]) tính trên ảnh đã nắn của
/// ảnh thứ [imageIndex] trong phiên.
enum GrainSource { auto, manual }

class Grain {
  const Grain({
    required this.id,
    this.imageIndex = 0,
    required this.contour,
    required this.centroidX,
    required this.centroidY,
    required this.areaPx,
    this.lengthPx = 0,
    this.widthPx = 0,
    this.lengthMm,
    this.widthMm,
    this.areaMm2,
    this.meanColorLab = const [0, 0, 0],
    this.featureVector = const [],
    this.predictedClassId,
    this.confidence,
    this.finalClassId,
    this.needsReview = false,
    this.source = GrainSource.auto,
    this.removed = false,
    this.estimatedCount = 1,
  });

  /// Duy nhất trong một phiên.
  final String id;
  final int imageIndex;

  /// Đa giác viền [x0, y0, x1, y1, ...].
  final List<double> contour;
  final double centroidX;
  final double centroidY;
  final double areaPx;

  /// Chiều dài / rộng theo hình chữ nhật bao nhỏ nhất (pixel ảnh đã nắn).
  final double lengthPx;
  final double widthPx;
  final double? lengthMm;
  final double? widthMm;
  final double? areaMm2;
  final List<double> meanColorLab;
  final List<double> featureVector;
  final String? predictedClassId;
  final double? confidence;
  final String? finalClassId;
  final bool needsReview;
  final GrainSource source;
  final bool removed;

  /// Số hạt ước tính của vật thể này: 1 với hạt đơn; > 1 với cụm hạt
  /// chồng/dính không tách được (= diện tích cụm / diện tích trung vị).
  final int estimatedCount;

  bool get isCluster => estimatedCount > 1;

  /// Số hạt được tính vào kết quả.
  int get countedGrains => removed ? 0 : estimatedCount;

  Grain copyWith({bool? removed, int? estimatedCount}) => Grain(
    id: id,
    imageIndex: imageIndex,
    contour: contour,
    centroidX: centroidX,
    centroidY: centroidY,
    areaPx: areaPx,
    lengthPx: lengthPx,
    widthPx: widthPx,
    lengthMm: lengthMm,
    widthMm: widthMm,
    areaMm2: areaMm2,
    meanColorLab: meanColorLab,
    featureVector: featureVector,
    predictedClassId: predictedClassId,
    confidence: confidence,
    finalClassId: finalClassId,
    needsReview: needsReview,
    source: source,
    removed: removed ?? this.removed,
    estimatedCount: estimatedCount ?? this.estimatedCount,
  );
}

/// Kết quả tổng hợp cho một nhóm hạt (mục 6). Ở giai đoạn 1 chưa có hồ sơ
/// nguyên liệu nên [classId] là các nhóm cố định — xem [ClassResult.allId].
class ClassResult {
  const ClassResult({
    required this.classId,
    required this.grainCount,
    required this.countPercent,
    required this.areaPercent,
    this.estWeightG,
    this.weightPercent,
  });

  /// Cả mẫu (đếm hạt thường).
  static const allId = 'all';

  /// Đếm nhanh: nhóm đã tách tay và phần còn lại của mẫu.
  static const groupId = 'group';
  static const restId = 'rest';

  final String classId;
  final int grainCount;

  /// Chưa làm tròn; làm tròn khi hiển thị (mục 8).
  final double countPercent;
  final double areaPercent;
  final double? estWeightG;
  final double? weightPercent;
}
