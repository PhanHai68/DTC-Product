/// 1 nguyên liệu (VD "Trà", "Vừng") — lấy từ sheet `Materials`.
///
/// Các cờ thuộc tính (`fibrous`, `oily`,...) là `bool?` BA TRẠNG THÁI: `null`
/// nghĩa là chưa xác minh (KHÔNG được coi là `false`). [status] cho biết dữ
/// liệu nguyên liệu này đã được xác minh theo nguồn catalog hay chỉ mới thêm
/// để tiện nhập liệu (`Needs validation`) — Selection Engine chỉ được dùng
/// tự động các dòng `status == 'Verified'`.
class GrindingMaterial {
  final String materialId;
  final String nameVi;
  final String nameEn;
  final String category;
  final String? hardness;
  final bool? fibrous;
  final bool? oily;
  final bool? stickyOrPaste;
  final bool? wet;
  final bool? heatSensitive;
  final bool? brittle;
  final bool? crystalline;
  final String? sourceCandidateSeries;
  final String? sourceBasis;
  final String status;
  final String? notes;

  const GrindingMaterial({
    required this.materialId,
    this.nameVi = '',
    this.nameEn = '',
    this.category = '',
    this.hardness,
    this.fibrous,
    this.oily,
    this.stickyOrPaste,
    this.wet,
    this.heatSensitive,
    this.brittle,
    this.crystalline,
    this.sourceCandidateSeries,
    this.sourceBasis,
    this.status = 'Needs validation',
    this.notes,
  });

  bool get isVerified => status == 'Verified';

  /// Chấp nhận cả `bool` (từ JSON seed) lẫn `int` 0/1 (đọc lại từ SQLite,
  /// vì cột lưu dạng INTEGER) — `null`/giá trị khác đều là "chưa xác minh".
  static bool? _triBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value == 1;
    return null;
  }

  factory GrindingMaterial.fromJson(Map<String, dynamic> json) =>
      GrindingMaterial(
        materialId: json['materialId'] as String,
        nameVi: json['nameVi'] as String? ?? '',
        nameEn: json['nameEn'] as String? ?? '',
        category: json['category'] as String? ?? '',
        hardness: json['hardness'] as String?,
        fibrous: _triBool(json['fibrous']),
        oily: _triBool(json['oily']),
        stickyOrPaste: _triBool(json['stickyOrPaste']),
        wet: _triBool(json['wet']),
        heatSensitive: _triBool(json['heatSensitive']),
        brittle: _triBool(json['brittle']),
        crystalline: _triBool(json['crystalline']),
        sourceCandidateSeries: json['sourceCandidateSeries'] as String?,
        sourceBasis: json['sourceBasis'] as String?,
        status: json['status'] as String? ?? 'Needs validation',
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'materialId': materialId,
    'nameVi': nameVi,
    'nameEn': nameEn,
    'category': category,
    'hardness': hardness,
    'fibrous': fibrous == null ? null : (fibrous! ? 1 : 0),
    'oily': oily == null ? null : (oily! ? 1 : 0),
    'stickyOrPaste': stickyOrPaste == null ? null : (stickyOrPaste! ? 1 : 0),
    'wet': wet == null ? null : (wet! ? 1 : 0),
    'heatSensitive': heatSensitive == null ? null : (heatSensitive! ? 1 : 0),
    'brittle': brittle == null ? null : (brittle! ? 1 : 0),
    'crystalline': crystalline == null ? null : (crystalline! ? 1 : 0),
    'sourceCandidateSeries': sourceCandidateSeries,
    'sourceBasis': sourceBasis,
    'status': status,
    'notes': notes,
  };
}
