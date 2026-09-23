/// Trạng thái của 1 hạng mục bảo trì (Maintenance Item), VD "Air Filter".
enum MaintenanceItemStatus {
  normal('Bình thường'),
  completed('Hoàn thành'),
  needAttention('Cần chú ý'),
  recommendation('Khuyến nghị');

  const MaintenanceItemStatus(this.label);
  final String label;

  static MaintenanceItemStatus parse(String? value) =>
      MaintenanceItemStatus.values.firstWhere(
        (item) => item.name == value,
        orElse: () => MaintenanceItemStatus.normal,
      );
}

/// 1 hạng mục bảo trì trong report, VD "Air Filter", "Oil Filter"... — chứa
/// Before/Action/After theo đúng cấu trúc mục 10 trong đặc tả.
class MaintenanceItem {
  final String id;
  final String reportId;
  final String name;
  final int orderIndex;
  final String beforeFinding;
  final String actionTaken;
  final String afterResult;
  final MaintenanceItemStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MaintenanceItem({
    required this.id,
    required this.reportId,
    required this.name,
    this.orderIndex = 0,
    this.beforeFinding = '',
    this.actionTaken = '',
    this.afterResult = '',
    this.status = MaintenanceItemStatus.normal,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaintenanceItem.fromJson(Map<String, dynamic> json) =>
      MaintenanceItem(
        id: json['id'] as String,
        reportId: json['reportId'] as String,
        name: json['name'] as String? ?? '',
        orderIndex: json['orderIndex'] as int? ?? 0,
        beforeFinding: json['beforeFinding'] as String? ?? '',
        actionTaken: json['actionTaken'] as String? ?? '',
        afterResult: json['afterResult'] as String? ?? '',
        status: MaintenanceItemStatus.parse(json['status'] as String?),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'reportId': reportId,
    'name': name,
    'orderIndex': orderIndex,
    'beforeFinding': beforeFinding,
    'actionTaken': actionTaken,
    'afterResult': afterResult,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  MaintenanceItem copyWith({
    String? name,
    int? orderIndex,
    String? beforeFinding,
    String? actionTaken,
    String? afterResult,
    MaintenanceItemStatus? status,
    DateTime? updatedAt,
  }) => MaintenanceItem(
    id: id,
    reportId: reportId,
    name: name ?? this.name,
    orderIndex: orderIndex ?? this.orderIndex,
    beforeFinding: beforeFinding ?? this.beforeFinding,
    actionTaken: actionTaken ?? this.actionTaken,
    afterResult: afterResult ?? this.afterResult,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Danh sách gợi ý hạng mục bảo trì thường gặp (máy nén khí) — CHỈ để gợi ý
/// nhanh khi thêm mới, không cố định, người dùng có thể nhập tên khác.
const List<String> suggestedMaintenanceItemNames = [
  'Lọc gió',
  'Lọc dầu',
  'Tách dầu',
  'Dầu máy nén',
  'Giàn giải nhiệt',
  'Tủ điện',
  'Dây curoa',
  'Rò rỉ khí',
  'Hệ thống xả nước',
  'Khác',
];
