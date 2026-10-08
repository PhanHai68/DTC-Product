import 'grain.dart';

/// Loại mẫu (mục 3): đầu vào, thành phẩm, phế của máy tách màu, hoặc khác.
enum SampleType {
  input('Đầu vào'),
  accept('Thành phẩm'),
  reject('Phế'),
  other('Mẫu khác');

  const SampleType(this.label);
  final String label;

  static SampleType byName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => other);
}

/// Đếm hạt thường (một ảnh) hoặc đếm nhanh không cần hồ sơ (luồng C, hai
/// ảnh: cả mẫu + nhóm đã tách tay).
enum AnalysisMode {
  count('Đếm hạt'),
  quick('Đếm nhanh nhóm hạt');

  const AnalysisMode(this.label);
  final String label;

  static AnalysisMode byName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => count);
}

enum SessionStatus {
  draft('Nháp'),
  confirmed('Đã xác nhận');

  const SessionStatus(this.label);
  final String label;

  static SessionStatus byName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => draft);
}

/// Một ảnh trong phiên và thông tin xử lý của ảnh đó. Ảnh gốc lưu đủ độ
/// phân giải; ảnh đánh dấu vẽ lại từ dữ liệu hạt (NFR-06).
class SessionImage {
  const SessionImage({
    required this.fileName,
    required this.width,
    required this.height,
    required this.frameWidth,
    required this.frameHeight,
    required this.frameToImage,
    required this.pixelsPerMm,
    required this.markersFound,
    required this.tiltDegrees,
    required this.issues,
    required this.metrics,
    required this.medianAreaPx,
    required this.edgeCutCount,
    required this.dustCount,
    this.ignoredRegionCount = 0,
    required this.clusterAreaFraction,
  });

  /// Tên file trong thư mục ảnh của module (không lưu đường dẫn tuyệt đối).
  final String fileName;

  /// Kích thước ảnh gốc sau khi xoay theo EXIF.
  final int width;
  final int height;

  /// Kích thước khung đã nắn (hệ tọa độ của các hạt).
  final int frameWidth;
  final int frameHeight;

  /// Ma trận 3×3 đổi tọa độ khung đã nắn → ảnh gốc.
  final List<double> frameToImage;
  final double? pixelsPerMm;
  final bool markersFound;
  final double? tiltDegrees;

  /// Tên các lỗi chất lượng ([QualityIssue.name]) người dùng đã bỏ qua.
  final List<String> issues;
  final Map<String, double> metrics;
  final double medianAreaPx;
  final int edgeCutCount;
  final int dustCount;

  /// Vùng quá lớn so với một hạt (bóng đổ, mép giấy...) — không được tính.
  final int ignoredRegionCount;
  final double clusterAreaFraction;

  Map<String, Object?> toJson() => {
    'fileName': fileName,
    'width': width,
    'height': height,
    'frameWidth': frameWidth,
    'frameHeight': frameHeight,
    'frameToImage': frameToImage,
    'pixelsPerMm': pixelsPerMm,
    'markersFound': markersFound,
    'tiltDegrees': tiltDegrees,
    'issues': issues,
    'metrics': metrics,
    'medianAreaPx': medianAreaPx,
    'edgeCutCount': edgeCutCount,
    'dustCount': dustCount,
    'ignoredRegionCount': ignoredRegionCount,
    'clusterAreaFraction': clusterAreaFraction,
  };

  factory SessionImage.fromJson(Map<String, Object?> json) => SessionImage(
    fileName: json['fileName'] as String,
    width: (json['width'] as num).toInt(),
    height: (json['height'] as num).toInt(),
    frameWidth: (json['frameWidth'] as num).toInt(),
    frameHeight: (json['frameHeight'] as num).toInt(),
    frameToImage: [
      for (final v in json['frameToImage'] as List) (v as num).toDouble(),
    ],
    pixelsPerMm: (json['pixelsPerMm'] as num?)?.toDouble(),
    markersFound: json['markersFound'] as bool? ?? false,
    tiltDegrees: (json['tiltDegrees'] as num?)?.toDouble(),
    issues: [for (final v in json['issues'] as List? ?? const []) '$v'],
    metrics: {
      for (final e in (json['metrics'] as Map? ?? const {}).entries)
        '${e.key}': (e.value as num).toDouble(),
    },
    medianAreaPx: (json['medianAreaPx'] as num?)?.toDouble() ?? 0,
    edgeCutCount: (json['edgeCutCount'] as num?)?.toInt() ?? 0,
    dustCount: (json['dustCount'] as num?)?.toInt() ?? 0,
    ignoredRegionCount: (json['ignoredRegionCount'] as num?)?.toInt() ?? 0,
    clusterAreaFraction: (json['clusterAreaFraction'] as num?)?.toDouble() ?? 0,
  );
}

/// Phiên phân tích (mục 6): một lần chụp và phân tích một mẫu.
class AnalysisSession {
  const AnalysisSession({
    required this.id,
    this.profileId,
    required this.mode,
    this.lotCode,
    required this.sampleType,
    this.sampleWeightG,
    this.streamWeightKg,
    required this.trayId,
    required this.images,
    required this.grains,
    required this.results,
    required this.status,
    required this.algorithmVersion,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  final String id;

  /// Hồ sơ nguyên liệu — giai đoạn 2; giai đoạn 1 luôn null.
  final String? profileId;
  final AnalysisMode mode;
  final String? lotCode;
  final SampleType sampleType;
  final double? sampleWeightG;
  final double? streamWeightKg;
  final String trayId;
  final List<SessionImage> images;
  final List<Grain> grains;
  final List<ClassResult> results;
  final SessionStatus status;
  final String algorithmVersion;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? note;

  List<String> get imagePaths => [for (final i in images) i.fileName];

  /// pixelsPerMm của ảnh chính (ảnh cả mẫu).
  double? get pixelsPerMm => images.isEmpty ? null : images.first.pixelsPerMm;

  /// Có ảnh bị bỏ qua lỗi chất lượng ("vẫn tiếp tục") → gắn cờ ảnh kém.
  bool get poorQuality => images.any((i) => i.issues.isNotEmpty);

  List<Grain> grainsOf(int imageIndex) => [
    for (final g in grains)
      if (g.imageIndex == imageIndex) g,
  ];

  ClassResult? resultOf(String classId) {
    for (final r in results) {
      if (r.classId == classId) return r;
    }
    return null;
  }

  AnalysisSession copyWith({
    List<Grain>? grains,
    List<ClassResult>? results,
    SessionStatus? status,
    DateTime? updatedAt,
  }) => AnalysisSession(
    id: id,
    profileId: profileId,
    mode: mode,
    lotCode: lotCode,
    sampleType: sampleType,
    sampleWeightG: sampleWeightG,
    streamWeightKg: streamWeightKg,
    trayId: trayId,
    images: images,
    grains: grains ?? this.grains,
    results: results ?? this.results,
    status: status ?? this.status,
    algorithmVersion: algorithmVersion,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    note: note,
  );
}

/// Dòng trong danh sách phiên (không nạp dữ liệu từng hạt).
class AnalysisSessionSummary {
  const AnalysisSessionSummary({
    required this.id,
    required this.mode,
    required this.lotCode,
    required this.sampleType,
    required this.status,
    required this.poorQuality,
    required this.createdAt,
    required this.createdBy,
    required this.results,
  });

  final String id;
  final AnalysisMode mode;
  final String? lotCode;
  final SampleType sampleType;
  final SessionStatus status;
  final bool poorQuality;
  final DateTime createdAt;
  final String createdBy;
  final List<ClassResult> results;

  ClassResult? resultOf(String classId) {
    for (final r in results) {
      if (r.classId == classId) return r;
    }
    return null;
  }
}
