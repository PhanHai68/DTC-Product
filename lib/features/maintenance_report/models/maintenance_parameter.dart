/// 1 thông số máy sau bảo trì (Machine Condition After Maintenance), VD
/// "Running Pressure: 7.2 bar" — tự do thêm, không cố định danh sách.
class MaintenanceParameter {
  final String id;
  final String reportId;
  final String label;
  final String value;
  final String unit;
  final int orderIndex;

  const MaintenanceParameter({
    required this.id,
    required this.reportId,
    required this.label,
    this.value = '',
    this.unit = '',
    this.orderIndex = 0,
  });

  factory MaintenanceParameter.fromJson(Map<String, dynamic> json) =>
      MaintenanceParameter(
        id: json['id'] as String,
        reportId: json['reportId'] as String,
        label: json['label'] as String? ?? '',
        value: json['value'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
        orderIndex: json['orderIndex'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reportId': reportId,
    'label': label,
    'value': value,
    'unit': unit,
    'orderIndex': orderIndex,
  };
}

/// Gợi ý nhanh thông số thường ghi nhận sau bảo trì máy nén khí.
const List<String> suggestedMaintenanceParameterLabels = [
  'Running Pressure',
  'Discharge Temperature',
  'Current',
  'Voltage',
  'Running Hours',
  'Leakage',
  'Noise',
];
