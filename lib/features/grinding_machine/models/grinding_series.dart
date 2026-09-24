/// 1 dòng máy nghiền (VD "BSP_ULTRAFINE" = Bộ nghiền bột siêu mịn/Air
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
  final String workingPrincipleVi;
  final String notes;

  const GrindingSeries({
    required this.seriesCode,
    this.displayCode = '',
    this.nameVi = '',
    this.nameEn = '',
    this.technology = '',
    this.pdfPages = '',
    this.applicationVi = '',
    this.workingPrincipleVi = '',
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
    workingPrincipleVi: json['workingPrincipleVi'] as String? ?? '',
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
    'workingPrincipleVi': workingPrincipleVi,
    'notes': notes,
  };
}
