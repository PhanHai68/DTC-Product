/// 1 dòng máy nghiền (VD "ASP_ULTRAFINE" = Bộ nghiền bột siêu mịn/Air
/// Classifier Mill) — dữ liệu lấy nguyên từ sheet `Series` của
/// DTC_Grinding_Machine_Database_AI_Ready.xlsx, KHÔNG tự suy diễn thêm.
class GrindingSeries {
  final String seriesCode;
  final String displayCode;
  final String nameVi;
  final String nameEn;
  final String technology;
  final String pdfPages;
  final String applicationVi;

  /// Cấu tạo máy/hệ thống (nhiều dòng, có thể có gạch đầu dòng "- ").
  final String structureVi;

  final String workingPrincipleVi;

  /// Đặc điểm chính, mỗi ý 1 dòng (VD "1. Nhiệt độ nghiền thấp: ...").
  final String featuresVi;
  final String notes;

  const GrindingSeries({
    required this.seriesCode,
    this.displayCode = '',
    this.nameVi = '',
    this.nameEn = '',
    this.technology = '',
    this.pdfPages = '',
    this.applicationVi = '',
    this.structureVi = '',
    this.workingPrincipleVi = '',
    this.featuresVi = '',
    this.notes = '',
  });

  factory GrindingSeries.fromJson(Map<String, dynamic> json) => GrindingSeries(
    seriesCode: json['seriesCode'] as String,
    displayCode: json['displayCode'] as String? ?? '',
    nameVi: json['nameVi'] as String? ?? '',
    nameEn: json['nameEn'] as String? ?? '',
    technology: json['technology'] as String? ?? '',
    pdfPages: json['pdfPages'] as String? ?? '',
    applicationVi: json['applicationVi'] as String? ?? '',
    structureVi: json['structureVi'] as String? ?? '',
    workingPrincipleVi: json['workingPrincipleVi'] as String? ?? '',
    featuresVi: json['featuresVi'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'seriesCode': seriesCode,
    'displayCode': displayCode,
    'nameVi': nameVi,
    'nameEn': nameEn,
    'technology': technology,
    'pdfPages': pdfPages,
    'applicationVi': applicationVi,
    'structureVi': structureVi,
    'workingPrincipleVi': workingPrincipleVi,
    'featuresVi': featuresVi,
    'notes': notes,
  };
}
