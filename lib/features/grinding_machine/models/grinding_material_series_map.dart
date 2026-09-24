/// Điểm cộng/trừ theo tương thích [materialId] ↔ [seriesCode], lấy từ sheet
/// `Material_Series_Map` — dùng trong Selection Engine để điều chỉnh điểm
/// (KHÔNG thay thế hard filter kỹ thuật capacity/fineness/input). Chỉ dòng
/// `status == 'Verified'` mới được Selection Engine dùng tự động.
class GrindingMaterialSeriesMap {
  final int? id;
  final String materialId;
  final String seriesCode;
  final double scoreAdjustment;
  final String? basisType;
  final String? reasonVi;
  final String? sourceBasis;
  final String status;

  const GrindingMaterialSeriesMap({
    this.id,
    required this.materialId,
    required this.seriesCode,
    this.scoreAdjustment = 0,
    this.basisType,
    this.reasonVi,
    this.sourceBasis,
    this.status = 'Needs validation',
  });

  bool get isVerified => status == 'Verified';

  factory GrindingMaterialSeriesMap.fromJson(Map<String, dynamic> json) =>
      GrindingMaterialSeriesMap(
        id: json['id'] as int?,
        materialId: json['materialId'] as String,
        seriesCode: json['seriesCode'] as String,
        scoreAdjustment: (json['scoreAdjustment'] as num?)?.toDouble() ?? 0,
        basisType: json['basisType'] as String?,
        reasonVi: json['reasonVi'] as String?,
        sourceBasis: json['sourceBasis'] as String?,
        status: json['status'] as String? ?? 'Needs validation',
      );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'materialId': materialId,
    'seriesCode': seriesCode,
    'scoreAdjustment': scoreAdjustment,
    'basisType': basisType,
    'reasonVi': reasonVi,
    'sourceBasis': sourceBasis,
    'status': status,
  };
}
