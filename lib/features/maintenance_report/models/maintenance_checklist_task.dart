/// 1 dòng trong "Các công việc đã thực hiện" — luôn do người dùng tự thêm
/// (không còn checklist mặc định), nên có thể xóa bất kỳ dòng nào.
class MaintenanceChecklistTask {
  final String id;
  final String reportId;
  final String label;
  final bool isChecked;
  final int orderIndex;

  const MaintenanceChecklistTask({
    required this.id,
    required this.reportId,
    required this.label,
    this.isChecked = false,
    this.orderIndex = 0,
  });

  factory MaintenanceChecklistTask.fromJson(Map<String, dynamic> json) =>
      MaintenanceChecklistTask(
        id: json['id'] as String,
        reportId: json['reportId'] as String,
        label: json['label'] as String? ?? '',
        isChecked: (json['isChecked'] as int? ?? 0) == 1,
        orderIndex: json['orderIndex'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reportId': reportId,
    'label': label,
    'isChecked': isChecked ? 1 : 0,
    'orderIndex': orderIndex,
  };

  MaintenanceChecklistTask copyWith({bool? isChecked}) =>
      MaintenanceChecklistTask(
        id: id,
        reportId: reportId,
        label: label,
        isChecked: isChecked ?? this.isChecked,
        orderIndex: orderIndex,
      );
}
