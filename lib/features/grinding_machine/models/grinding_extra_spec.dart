/// 1 thông số phụ riêng của từng công nghệ (VD "chamber_diameter_mm",
/// "blower_motor_kw") — dạng key-value, lấy từ sheet `Extra_Specs`, để không
/// phải thêm cột mới vào bảng `grinding_machines` mỗi khi có công nghệ mới.
class GrindingExtraSpec {
  final int? id;
  final String machineId;
  final String specKey;
  final double? specValueNumber;
  final String? specValueText;
  final String? unit;
  final int? sourcePdfPage;
  final String? note;

  const GrindingExtraSpec({
    this.id,
    required this.machineId,
    required this.specKey,
    this.specValueNumber,
    this.specValueText,
    this.unit,
    this.sourcePdfPage,
    this.note,
  });

  /// Giá trị hiển thị: ưu tiên số kèm đơn vị, rơi về text nếu không phải số.
  String get displayValue {
    if (specValueNumber != null) {
      final n = specValueNumber!;
      final formatted = n == n.roundToDouble()
          ? n.toInt().toString()
          : n.toString();
      return unit == null || unit!.isEmpty ? formatted : '$formatted $unit';
    }
    return specValueText ?? '';
  }

  factory GrindingExtraSpec.fromJson(Map<String, dynamic> json) =>
      GrindingExtraSpec(
        id: json['id'] as int?,
        machineId: json['machineId'] as String,
        specKey: json['specKey'] as String,
        specValueNumber: (json['specValueNumber'] as num?)?.toDouble(),
        specValueText: json['specValueText'] as String?,
        unit: json['unit'] as String?,
        sourcePdfPage: json['sourcePdfPage'] as int?,
        note: json['note'] as String?,
      );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'machineId': machineId,
    'specKey': specKey,
    'specValueNumber': specValueNumber,
    'specValueText': specValueText,
    'unit': unit,
    'sourcePdfPage': sourcePdfPage,
    'note': note,
  };
}
