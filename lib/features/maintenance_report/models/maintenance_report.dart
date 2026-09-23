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

  // Customer Information
  final String customerName;
  final String factorySite;
  final String contactPerson;
  final String contactPhone;

  // Machine Information
  final String machineName;
  final String machineType;
  final String machineModel;
  final String machineSerial;
  final String machineRunningHours;
  final String machineLocation;

  // Maintenance Information
  final DateTime maintenanceDate;
  final String engineerName;
  final String? sessionId;
  final DateTime? startTime;
  final DateTime? endTime;

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
    this.contactPerson = '',
    this.contactPhone = '',
    this.machineName = '',
    this.machineType = '',
    this.machineModel = '',
    this.machineSerial = '',
    this.machineRunningHours = '',
    this.machineLocation = '',
    required this.maintenanceDate,
    this.engineerName = '',
    this.sessionId,
    this.startTime,
    this.endTime,
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

  factory MaintenanceReport.fromJson(Map<String, dynamic> json) =>
      MaintenanceReport(
        id: json['id'] as String,
        status: MaintenanceReportStatus.parse(json['status'] as String?),
        customerName: json['customerName'] as String? ?? '',
        factorySite: json['factorySite'] as String? ?? '',
        contactPerson: json['contactPerson'] as String? ?? '',
        contactPhone: json['contactPhone'] as String? ?? '',
        machineName: json['machineName'] as String? ?? '',
        machineType: json['machineType'] as String? ?? '',
        machineModel: json['machineModel'] as String? ?? '',
        machineSerial: json['machineSerial'] as String? ?? '',
        machineRunningHours: json['machineRunningHours'] as String? ?? '',
        machineLocation: json['machineLocation'] as String? ?? '',
        maintenanceDate: DateTime.parse(json['maintenanceDate'] as String),
        engineerName: json['engineerName'] as String? ?? '',
        sessionId: json['sessionId'] as String?,
        startTime: json['startTime'] == null
            ? null
            : DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] == null
            ? null
            : DateTime.parse(json['endTime'] as String),
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.name,
    'customerName': customerName,
    'factorySite': factorySite,
    'contactPerson': contactPerson,
    'contactPhone': contactPhone,
    'machineName': machineName,
    'machineType': machineType,
    'machineModel': machineModel,
    'machineSerial': machineSerial,
    'machineRunningHours': machineRunningHours,
    'machineLocation': machineLocation,
    'maintenanceDate': maintenanceDate.toIso8601String(),
    'engineerName': engineerName,
    'sessionId': sessionId,
    'startTime': startTime?.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
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
    String? contactPerson,
    String? contactPhone,
    String? machineName,
    String? machineType,
    String? machineModel,
    String? machineSerial,
    String? machineRunningHours,
    String? machineLocation,
    DateTime? maintenanceDate,
    String? engineerName,
    String? sessionId,
    DateTime? startTime,
    DateTime? endTime,
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
    contactPerson: contactPerson ?? this.contactPerson,
    contactPhone: contactPhone ?? this.contactPhone,
    machineName: machineName ?? this.machineName,
    machineType: machineType ?? this.machineType,
    machineModel: machineModel ?? this.machineModel,
    machineSerial: machineSerial ?? this.machineSerial,
    machineRunningHours: machineRunningHours ?? this.machineRunningHours,
    machineLocation: machineLocation ?? this.machineLocation,
    maintenanceDate: maintenanceDate ?? this.maintenanceDate,
    engineerName: engineerName ?? this.engineerName,
    sessionId: sessionId ?? this.sessionId,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
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
