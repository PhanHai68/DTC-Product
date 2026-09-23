import 'dart:convert';

/// Trạng thái của 1 báo cáo bảo trì — "Completed" khoá không cho thay đổi
/// ảnh Original đã chụp (xem MaintenanceReportRepository).
enum MaintenanceReportStatus {
  draft('Nháp'),
  completed('Hoàn thành');

  const MaintenanceReportStatus(this.label);
  final String label;

  static MaintenanceReportStatus parse(String? value) =>
      MaintenanceReportStatus.values.firstWhere(
        (item) => item.name == value,
        orElse: () => MaintenanceReportStatus.draft,
      );
}

/// Kết luận cuối cùng sau bảo trì (Overall Result).
enum MaintenanceOverallResult {
  normalOperation('Hoạt động bình thường'),
  completed('Đã hoàn thành'),
  needMonitoring('Cần theo dõi thêm'),
  furtherInspectionRequired('Cần kiểm tra thêm'),
  repairRecommended('Đề xuất sửa chữa');

  const MaintenanceOverallResult(this.label);
  final String label;

  static MaintenanceOverallResult? parse(String? value) {
    if (value == null) return null;
    for (final item in MaintenanceOverallResult.values) {
      if (item.name == value) return item;
    }
    return null;
  }
}

/// 1 báo cáo bảo trì (Maintenance Report) — gộp Customer/Machine/Maintenance
/// Information. [sessionId] chỉ được sinh khi kỹ sư bấm "Start Maintenance"
/// (null trước đó); [startTime]/[endTime] là mốc thời gian THỰC của phiên
/// bảo trì (do Start/Complete Maintenance ghi lại), không phải giá trị nhập
/// tay tuỳ ý.
class MaintenanceReport {
  final String id;
  final MaintenanceReportStatus status;

  // Customer Information — chỉ giữ 2 trường thật sự cần khi tạo báo cáo mới.
  final String customerName;
  final String factorySite;

  // Machine Information — Model + Tagname (định danh máy) + số giờ vận hành.
  final String machineModel;
  final String machineTagName;
  final String machineRunningHours;

  // Maintenance Information
  final DateTime maintenanceDate;
  // Nhiều kỹ sư có thể cùng thực hiện 1 lần bảo trì.
  final List<String> engineerNames;
  final String? sessionId;
  final DateTime? startTime;
  final DateTime? endTime;

  // Tình trạng máy sau bảo trì — 1 đoạn văn bản tự do, không còn danh sách
  // thông số Label/Value/Unit riêng lẻ.
  final String machineCondition;

  // Final Result
  final MaintenanceOverallResult? overallResult;
  final String finalComment;
  final String recommendation;
  final DateTime? nextMaintenanceDate;
  final String nextMaintenanceRunningHours;

  final DateTime createdAt;
  final DateTime updatedAt;

  const MaintenanceReport({
    required this.id,
    this.status = MaintenanceReportStatus.draft,
    this.customerName = '',
    this.factorySite = '',
    this.machineModel = '',
    this.machineTagName = '',
    this.machineRunningHours = '',
    required this.maintenanceDate,
    this.engineerNames = const [],
    this.sessionId,
    this.startTime,
    this.endTime,
    this.machineCondition = '',
    this.overallResult,
    this.finalComment = '',
    this.recommendation = '',
    this.nextMaintenanceDate,
    this.nextMaintenanceRunningHours = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDraft => status == MaintenanceReportStatus.draft;
  bool get isCompleted => status == MaintenanceReportStatus.completed;
  bool get hasStarted => sessionId != null;
  String get engineerNamesDisplay => engineerNames.join(', ');

  factory MaintenanceReport.fromJson(Map<String, dynamic> json) =>
      MaintenanceReport(
        id: json['id'] as String,
        status: MaintenanceReportStatus.parse(json['status'] as String?),
        customerName: json['customerName'] as String? ?? '',
        factorySite: json['factorySite'] as String? ?? '',
        machineModel: json['machineModel'] as String? ?? '',
        machineTagName: json['machineTagName'] as String? ?? '',
        machineRunningHours: json['machineRunningHours'] as String? ?? '',
        maintenanceDate: DateTime.parse(json['maintenanceDate'] as String),
        engineerNames: _decodeEngineerNames(json['engineerNames']),
        sessionId: json['sessionId'] as String?,
        startTime: json['startTime'] == null
            ? null
            : DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] == null
            ? null
            : DateTime.parse(json['endTime'] as String),
        machineCondition: json['machineCondition'] as String? ?? '',
        overallResult: MaintenanceOverallResult.parse(
          json['overallResult'] as String?,
        ),
        finalComment: json['finalComment'] as String? ?? '',
        recommendation: json['recommendation'] as String? ?? '',
        nextMaintenanceDate: json['nextMaintenanceDate'] == null
            ? null
            : DateTime.parse(json['nextMaintenanceDate'] as String),
        nextMaintenanceRunningHours:
            json['nextMaintenanceRunningHours'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  static List<String> _decodeEngineerNames(Object? value) {
    if (value is String && value.isNotEmpty) {
      try {
        return (jsonDecode(value) as List<dynamic>).cast<String>();
      } catch (_) {
        return [value];
      }
    }
    return const [];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.name,
    'customerName': customerName,
    'factorySite': factorySite,
    'machineModel': machineModel,
    'machineTagName': machineTagName,
    'machineRunningHours': machineRunningHours,
    'maintenanceDate': maintenanceDate.toIso8601String(),
    'engineerNames': jsonEncode(engineerNames),
    'sessionId': sessionId,
    'startTime': startTime?.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'machineCondition': machineCondition,
    'overallResult': overallResult?.name,
    'finalComment': finalComment,
    'recommendation': recommendation,
    'nextMaintenanceDate': nextMaintenanceDate?.toIso8601String(),
    'nextMaintenanceRunningHours': nextMaintenanceRunningHours,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  MaintenanceReport copyWith({
    MaintenanceReportStatus? status,
    String? customerName,
    String? factorySite,
    String? machineModel,
    String? machineTagName,
    String? machineRunningHours,
    DateTime? maintenanceDate,
    List<String>? engineerNames,
    String? sessionId,
    DateTime? startTime,
    DateTime? endTime,
    String? machineCondition,
    MaintenanceOverallResult? overallResult,
    bool clearOverallResult = false,
    String? finalComment,
    String? recommendation,
    DateTime? nextMaintenanceDate,
    bool clearNextMaintenanceDate = false,
    String? nextMaintenanceRunningHours,
    DateTime? updatedAt,
  }) => MaintenanceReport(
    id: id,
    status: status ?? this.status,
    customerName: customerName ?? this.customerName,
    factorySite: factorySite ?? this.factorySite,
    machineModel: machineModel ?? this.machineModel,
    machineTagName: machineTagName ?? this.machineTagName,
    machineRunningHours: machineRunningHours ?? this.machineRunningHours,
    maintenanceDate: maintenanceDate ?? this.maintenanceDate,
    engineerNames: engineerNames ?? this.engineerNames,
    sessionId: sessionId ?? this.sessionId,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    machineCondition: machineCondition ?? this.machineCondition,
    overallResult: clearOverallResult
        ? null
        : (overallResult ?? this.overallResult),
    finalComment: finalComment ?? this.finalComment,
    recommendation: recommendation ?? this.recommendation,
    nextMaintenanceDate: clearNextMaintenanceDate
        ? null
        : (nextMaintenanceDate ?? this.nextMaintenanceDate),
    nextMaintenanceRunningHours:
        nextMaintenanceRunningHours ?? this.nextMaintenanceRunningHours,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
