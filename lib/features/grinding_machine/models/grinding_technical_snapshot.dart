/// 1 thông số phụ đã đóng băng trong snapshot (xem [GrindingTechnicalSnapshot]).
class GrindingSnapshotExtraSpec {
  const GrindingSnapshotExtraSpec({required this.label, required this.value});

  final String label;
  final String value;

  factory GrindingSnapshotExtraSpec.fromJson(Map<String, dynamic> json) =>
      GrindingSnapshotExtraSpec(
        label: json['label'] as String,
        value: json['value'] as String,
      );

  Map<String, dynamic> toJson() => {'label': label, 'value': value};
}

/// Bản chụp thông số kỹ thuật máy TẠI THỜI ĐIỂM Finalize 1 Proposal (Phase
/// 8, mục "Technical Snapshot") — từ lúc này Proposal Final KHÔNG được đọc
/// lại catalog máy nữa, kể cả khi database Excel sau đó cập nhật/xóa model.
/// Đóng băng trực tiếp GIÁ TRỊ ĐÃ ĐỊNH DẠNG (không giữ số thô) vì mục đích
/// duy nhất là hiển thị lại y hệt trên PDF/UI Final, không dùng để tính
/// toán tiếp.
class GrindingTechnicalSnapshot {
  const GrindingTechnicalSnapshot({
    required this.machineId,
    required this.model,
    this.seriesDisplayCode,
    this.seriesNameVi,
    this.capacityDisplay,
    this.finenessDisplay,
    this.motorDisplay,
    this.dimensionsDisplay,
    this.weightDisplay,
    this.extraSpecs = const [],
    required this.capturedAt,
  });

  final String machineId;
  final String model;
  final String? seriesDisplayCode;
  final String? seriesNameVi;
  final String? capacityDisplay;
  final String? finenessDisplay;
  final String? motorDisplay;
  final String? dimensionsDisplay;
  final String? weightDisplay;
  final List<GrindingSnapshotExtraSpec> extraSpecs;
  final DateTime capturedAt;

  factory GrindingTechnicalSnapshot.fromJson(Map<String, dynamic> json) =>
      GrindingTechnicalSnapshot(
        machineId: json['machineId'] as String,
        model: json['model'] as String,
        seriesDisplayCode: json['seriesDisplayCode'] as String?,
        seriesNameVi: json['seriesNameVi'] as String?,
        capacityDisplay: json['capacityDisplay'] as String?,
        finenessDisplay: json['finenessDisplay'] as String?,
        motorDisplay: json['motorDisplay'] as String?,
        dimensionsDisplay: json['dimensionsDisplay'] as String?,
        weightDisplay: json['weightDisplay'] as String?,
        extraSpecs: (json['extraSpecs'] as List<dynamic>? ?? const [])
            .map((e) => GrindingSnapshotExtraSpec.fromJson(e as Map<String, dynamic>))
            .toList(),
        capturedAt: DateTime.parse(json['capturedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'machineId': machineId,
    'model': model,
    'seriesDisplayCode': seriesDisplayCode,
    'seriesNameVi': seriesNameVi,
    'capacityDisplay': capacityDisplay,
    'finenessDisplay': finenessDisplay,
    'motorDisplay': motorDisplay,
    'dimensionsDisplay': dimensionsDisplay,
    'weightDisplay': weightDisplay,
    'extraSpecs': extraSpecs.map((e) => e.toJson()).toList(),
    'capturedAt': capturedAt.toIso8601String(),
  };
}
