/// 1 dòng trong "Maintenance Performed" checklist.
class MaintenanceChecklistTask {
  final String id;
  final String reportId;
  final String label;
  final bool isChecked;
  final bool isCustom;
  final int orderIndex;

  const MaintenanceChecklistTask({
    required this.id,
    required this.reportId,
    required this.label,
    this.isChecked = false,
    this.isCustom = false,
    this.orderIndex = 0,
  });

  factory MaintenanceChecklistTask.fromJson(Map<String, dynamic> json) =>
      MaintenanceChecklistTask(
        id: json['id'] as String,
        reportId: json['reportId'] as String,
        label: json['label'] as String? ?? '',
        isChecked: (json['isChecked'] as int? ?? 0) == 1,
        isCustom: (json['isCustom'] as int? ?? 0) == 1,
        orderIndex: json['orderIndex'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reportId': reportId,
    'label': label,
    'isChecked': isChecked ? 1 : 0,
    'isCustom': isCustom ? 1 : 0,
    'orderIndex': orderIndex,
  };

  MaintenanceChecklistTask copyWith({bool? isChecked}) =>
      MaintenanceChecklistTask(
        id: id,
        reportId: reportId,
        label: label,
        isChecked: isChecked ?? this.isChecked,
        isCustom: isCustom,
        orderIndex: orderIndex,
      );
}

/// Checklist gợi ý mặc định cho máy nén khí — chèn sẵn khi tạo report mới,
/// người dùng có thể bỏ chọn hoặc thêm "Add Custom Task".
const List<String> defaultMaintenanceChecklistLabels = [
  'Thay lọc gió',
  'Thay lọc dầu',
  'Thay lọc tách dầu',
  'Thay dầu máy nén',
  'Vệ sinh giàn giải nhiệt',
  'Kiểm tra hệ thống điện',
  'Kiểm tra dây curoa',
  'Kiểm tra rò rỉ khí',
  'Xả nước ngưng tụ',
  'Vệ sinh tủ điện',
];
