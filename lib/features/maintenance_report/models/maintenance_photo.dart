/// BEFORE hay AFTER — quyết định chữ cái trong Photo ID (B/A) và thư mục lưu.
enum MaintenancePhotoKind {
  before('B'),
  after('A');

  const MaintenancePhotoKind(this.prefix);
  final String prefix;

  static MaintenancePhotoKind parse(String? value) =>
      MaintenancePhotoKind.values.firstWhere(
        (item) => item.name == value,
        orElse: () => MaintenancePhotoKind.before,
      );
}

/// 1 ảnh Before/After chụp bằng Verified Camera. [id] chính là Photo ID hiển
/// thị (VD `MNT-20260923-0015-B01`). [originalPath] là ảnh gốc bất biến dùng
/// xác minh toàn vẹn (SHA-256); [reportPath] là bản có watermark dùng hiển
/// thị/PDF — KHÔNG bao giờ ghi đè lẫn nhau.
class MaintenancePhoto {
  final String id;
  final String reportId;
  final String? itemId;
  final MaintenancePhotoKind kind;
  final int sequence;
  final String originalPath;
  final String reportPath;
  final String sha256;
  final bool verified;
  final DateTime capturedAt;

  const MaintenancePhoto({
    required this.id,
    required this.reportId,
    this.itemId,
    required this.kind,
    required this.sequence,
    required this.originalPath,
    required this.reportPath,
    required this.sha256,
    this.verified = true,
    required this.capturedAt,
  });

  factory MaintenancePhoto.fromJson(Map<String, dynamic> json) =>
      MaintenancePhoto(
        id: json['id'] as String,
        reportId: json['reportId'] as String,
        itemId: json['itemId'] as String?,
        kind: MaintenancePhotoKind.parse(json['kind'] as String?),
        sequence: json['sequence'] as int? ?? 1,
        originalPath: json['originalPath'] as String? ?? '',
        reportPath: json['reportPath'] as String? ?? '',
        sha256: json['sha256'] as String? ?? '',
        verified: (json['verified'] as int? ?? 1) == 1,
        capturedAt: DateTime.parse(json['capturedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reportId': reportId,
    'itemId': itemId,
    'kind': kind.name,
    'sequence': sequence,
    'originalPath': originalPath,
    'reportPath': reportPath,
    'sha256': sha256,
    'verified': verified ? 1 : 0,
    'capturedAt': capturedAt.toIso8601String(),
  };

  MaintenancePhoto copyWith({bool? verified}) => MaintenancePhoto(
    id: id,
    reportId: reportId,
    itemId: itemId,
    kind: kind,
    sequence: sequence,
    originalPath: originalPath,
    reportPath: reportPath,
    sha256: sha256,
    verified: verified ?? this.verified,
    capturedAt: capturedAt,
  );
}
