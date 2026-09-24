import 'dart:convert';

/// 1 tham số cấu hình của Selection Engine (trọng số chấm điểm, ngưỡng,
/// guardrail...) — lấy từ sheet `AI_Config`. Lưu trong database (không
/// hard-code trong Dart) để sau này chỉnh trọng số chỉ cần cập nhật database,
/// không phải sửa code, đúng yêu cầu "Database update".
class GrindingAiConfig {
  final String key;

  /// Giá trị gốc — có thể là số (VD trọng số điểm) hoặc boolean (VD cờ
  /// guardrail); dùng [asNum]/[asBool] để đọc đúng kiểu mong đợi.
  final Object? value;
  final String? unit;
  final String? category;
  final String? description;
  final bool editable;

  const GrindingAiConfig({
    required this.key,
    this.value,
    this.unit,
    this.category,
    this.description,
    this.editable = true,
  });

  num? get asNum => value is num ? value as num : null;
  bool? get asBool => value is bool ? value as bool : null;

  factory GrindingAiConfig.fromJson(Map<String, dynamic> json) =>
      GrindingAiConfig(
        key: json['key'] as String,
        value: json['value'],
        unit: json['unit'] as String?,
        category: json['category'] as String?,
        description: json['description'] as String?,
        editable: switch (json['editable']) {
          bool v => v,
          int v => v != 0,
          _ => true,
        },
      );

  /// Đọc lại từ 1 row SQLite — cột `value` lưu dạng TEXT JSON-encode để chứa
  /// được cả số lẫn boolean trong cùng 1 cột.
  factory GrindingAiConfig.fromRow(Map<String, Object?> row) =>
      GrindingAiConfig(
        key: row['key'] as String,
        value: row['value'] == null ? null : jsonDecode(row['value'] as String),
        unit: row['unit'] as String?,
        category: row['category'] as String?,
        description: row['description'] as String?,
        editable: (row['editable'] as int? ?? 1) == 1,
      );

  Map<String, Object?> toRow() => {
    'key': key,
    'value': value == null ? null : jsonEncode(value),
    'unit': unit,
    'category': category,
    'description': description,
    'editable': editable ? 1 : 0,
  };
}
