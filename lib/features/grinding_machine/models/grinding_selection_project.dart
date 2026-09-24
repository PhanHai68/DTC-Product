/// Trạng thái hồ sơ chọn máy (mục 3) — đơn giản, không workflow phức tạp.
enum GrindingProjectStatus {
  draft,
  evaluating,
  selected,
  completed;

  /// Giá trị lưu SQLite — text rõ nghĩa, không phụ thuộc thứ tự enum.
  String get value => switch (this) {
    GrindingProjectStatus.draft => 'draft',
    GrindingProjectStatus.evaluating => 'evaluating',
    GrindingProjectStatus.selected => 'selected',
    GrindingProjectStatus.completed => 'completed',
  };

  static GrindingProjectStatus fromValue(String? value) => switch (value) {
    'evaluating' => GrindingProjectStatus.evaluating,
    'selected' => GrindingProjectStatus.selected,
    'completed' => GrindingProjectStatus.completed,
    _ => GrindingProjectStatus.draft,
  };
}

/// 1 hồ sơ "chọn máy phù hợp" kỹ sư lưu lại cho 1 khách hàng — domain RIÊNG
/// với catalog máy nghiền (mục 16), chỉ lưu [machineId] khi tham chiếu tới
/// model, KHÔNG copy snapshot thông số kỹ thuật (mục 17). Field nào khách
/// hàng/kỹ sư chưa cung cấp giữ `null`, KHÔNG tự đổi thành chuỗi rỗng/0.
class GrindingSelectionProject {
  const GrindingSelectionProject({
    this.id,
    required this.projectName,
    this.customerName,
    this.contactName,
    this.contactInfo,
    this.materialId,
    this.materialName,
    this.requiredCapacityKgH,
    this.requiredFinenessValue,
    this.requiredFinenessUnit,
    this.feedSizeMm,
    this.maxMotorKw,
    this.application,
    this.notes,
    this.status = GrindingProjectStatus.draft,
    this.nextFollowUpAt,
    this.followUpNote,
    required this.createdAt,
    required this.updatedAt,
  });

  /// `null` trước khi lưu lần đầu — SQLite tự sinh khi insert.
  final int? id;

  final String projectName;
  final String? customerName;
  final String? contactName;
  final String? contactInfo;

  final String? materialId;
  final String? materialName;
  final double? requiredCapacityKgH;
  final double? requiredFinenessValue;

  /// 'mm' | 'mesh' | 'µm'.
  final String? requiredFinenessUnit;
  final double? feedSizeMm;
  final double? maxMotorKw;
  final String? application;
  final String? notes;

  final GrindingProjectStatus status;

  /// Ngày cần follow-up khách hàng tiếp theo (Phase 10) — `null` nghĩa là
  /// CHƯA đặt follow-up, KHÔNG tự suy đoán thành hôm nay.
  final DateTime? nextFollowUpAt;
  final String? followUpNote;

  final DateTime createdAt;
  final DateTime updatedAt;

  GrindingSelectionProject copyWith({
    int? id,
    String? projectName,
    String? customerName,
    bool clearCustomerName = false,
    String? contactName,
    bool clearContactName = false,
    String? contactInfo,
    bool clearContactInfo = false,
    String? materialId,
    bool clearMaterialId = false,
    String? materialName,
    bool clearMaterialName = false,
    double? requiredCapacityKgH,
    bool clearCapacity = false,
    double? requiredFinenessValue,
    String? requiredFinenessUnit,
    bool clearFineness = false,
    double? feedSizeMm,
    bool clearFeedSize = false,
    double? maxMotorKw,
    bool clearMaxMotorKw = false,
    String? application,
    bool clearApplication = false,
    String? notes,
    bool clearNotes = false,
    GrindingProjectStatus? status,
    DateTime? nextFollowUpAt,
    bool clearNextFollowUpAt = false,
    String? followUpNote,
    bool clearFollowUpNote = false,
    DateTime? updatedAt,
  }) {
    return GrindingSelectionProject(
      id: id ?? this.id,
      projectName: projectName ?? this.projectName,
      customerName: clearCustomerName ? null : (customerName ?? this.customerName),
      contactName: clearContactName ? null : (contactName ?? this.contactName),
      contactInfo: clearContactInfo ? null : (contactInfo ?? this.contactInfo),
      materialId: clearMaterialId ? null : (materialId ?? this.materialId),
      materialName: clearMaterialName ? null : (materialName ?? this.materialName),
      requiredCapacityKgH: clearCapacity
          ? null
          : (requiredCapacityKgH ?? this.requiredCapacityKgH),
      requiredFinenessValue: clearFineness
          ? null
          : (requiredFinenessValue ?? this.requiredFinenessValue),
      requiredFinenessUnit: clearFineness
          ? null
          : (requiredFinenessUnit ?? this.requiredFinenessUnit),
      feedSizeMm: clearFeedSize ? null : (feedSizeMm ?? this.feedSizeMm),
      maxMotorKw: clearMaxMotorKw ? null : (maxMotorKw ?? this.maxMotorKw),
      application: clearApplication ? null : (application ?? this.application),
      notes: clearNotes ? null : (notes ?? this.notes),
      status: status ?? this.status,
      nextFollowUpAt: clearNextFollowUpAt
          ? null
          : (nextFollowUpAt ?? this.nextFollowUpAt),
      followUpNote: clearFollowUpNote ? null : (followUpNote ?? this.followUpNote),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Đọc lại từ 1 row SQLite (bảng `grinding_selection_projects`).
  factory GrindingSelectionProject.fromRow(Map<String, Object?> row) =>
      GrindingSelectionProject(
        id: row['id'] as int?,
        projectName: row['projectName'] as String,
        customerName: row['customerName'] as String?,
        contactName: row['contactName'] as String?,
        contactInfo: row['contactInfo'] as String?,
        materialId: row['materialId'] as String?,
        materialName: row['materialName'] as String?,
        requiredCapacityKgH: (row['requiredCapacityKgH'] as num?)?.toDouble(),
        requiredFinenessValue: (row['requiredFinenessValue'] as num?)
            ?.toDouble(),
        requiredFinenessUnit: row['requiredFinenessUnit'] as String?,
        feedSizeMm: (row['feedSizeMm'] as num?)?.toDouble(),
        maxMotorKw: (row['maxMotorKw'] as num?)?.toDouble(),
        application: row['application'] as String?,
        notes: row['notes'] as String?,
        status: GrindingProjectStatus.fromValue(row['status'] as String?),
        nextFollowUpAt: row['nextFollowUpAt'] == null
            ? null
            : DateTime.parse(row['nextFollowUpAt'] as String),
        followUpNote: row['followUpNote'] as String?,
        createdAt: DateTime.parse(row['createdAt'] as String),
        updatedAt: DateTime.parse(row['updatedAt'] as String),
      );

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'projectName': projectName,
    'customerName': customerName,
    'contactName': contactName,
    'contactInfo': contactInfo,
    'materialId': materialId,
    'materialName': materialName,
    'requiredCapacityKgH': requiredCapacityKgH,
    'requiredFinenessValue': requiredFinenessValue,
    'requiredFinenessUnit': requiredFinenessUnit,
    'feedSizeMm': feedSizeMm,
    'maxMotorKw': maxMotorKw,
    'application': application,
    'notes': notes,
    'status': status.value,
    'nextFollowUpAt': nextFollowUpAt?.toIso8601String(),
    'followUpNote': followUpNote,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// Quan hệ project <-> machine (bảng `grinding_selection_project_machines`)
/// — [role] `primary` (tối đa 1 máy/project) hoặc `shortlist` (so sánh).
class GrindingProjectMachines {
  const GrindingProjectMachines({this.primaryMachineId, this.shortlistMachineIds = const []});

  final String? primaryMachineId;
  final List<String> shortlistMachineIds;
}
