/// Nguồn bản ghi: do kỹ sư này tạo, hay nhập từ file khác (giai đoạn 3 —
/// bản ghi nhập vào chỉ xem, không sửa/xóa).
enum FaultRecordSource {
  mine('mine'),
  imported('imported');

  const FaultRecordSource(this.value);
  final String value;

  static FaultRecordSource parse(String? value) =>
      value == imported.value ? imported : mine;
}

/// 1 bước xử lý (đánh số theo [order], bắt đầu từ 1).
class SolutionStep {
  const SolutionStep({
    required this.id,
    required this.order,
    required this.content,
    this.photo,
  });

  final String id;
  final int order;
  final String content;

  /// Ảnh gắn với bước (tối đa 1).
  final FaultAttachment? photo;

  SolutionStep copyWith({
    int? order,
    String? content,
    FaultAttachment? photo,
    bool clearPhoto = false,
  }) => SolutionStep(
    id: id,
    order: order ?? this.order,
    content: content ?? this.content,
    photo: clearPhoto ? null : (photo ?? this.photo),
  );
}

/// 1 ảnh. Bảng chỉ lưu [fileName]; đường dẫn đầy đủ tính lại lúc chạy từ
/// thư mục của app.
class FaultAttachment {
  const FaultAttachment({
    required this.id,
    required this.fileName,
    this.stepId,
    this.caption,
  });

  final String id;
  final String fileName;

  /// null = ảnh chung của bản ghi; khác null = ảnh của 1 bước xử lý.
  final String? stepId;
  final String? caption;

  factory FaultAttachment.fromMap(Map<String, Object?> map) => FaultAttachment(
    id: map['id'] as String,
    fileName: map['file_name'] as String,
    stepId: map['step_id'] as String?,
    caption: map['caption'] as String?,
  );
}

/// 1 sự cố đã ghi nhận, kèm các bước xử lý và ảnh.
class FaultRecord {
  const FaultRecord({
    required this.id,
    required this.machineModelId,
    required this.machineModelName,
    required this.symptom,
    required this.cause,
    required this.steps,
    required this.authorCode,
    required this.authorName,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.serialNumber,
    this.errorCode,
    this.faultGroup,
    this.parts,
    this.tools,
    this.durationMinutes,
    this.safetyWarning,
    this.photos = const [],
  });

  /// `<mã kỹ sư>-<uuid>`, không bao giờ đổi.
  final String id;
  final String machineModelId;
  final String machineModelName;
  final String? serialNumber;
  final String? errorCode;
  final String? faultGroup;
  final String symptom;
  final String cause;
  final List<SolutionStep> steps;

  /// Ảnh chung của bản ghi (không thuộc bước nào).
  final List<FaultAttachment> photos;
  final String? parts;
  final String? tools;
  final int? durationMinutes;
  final String? safetyWarning;
  final String authorCode;
  final String authorName;
  final FaultRecordSource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEditable => source == FaultRecordSource.mine;
}

/// Dữ liệu người dùng nhập ở form Ghi nhận / Sửa sự cố.
class FaultRecordDraft {
  const FaultRecordDraft({
    required this.machineModelId,
    required this.symptom,
    required this.cause,
    required this.steps,
    this.serialNumber,
    this.errorCode,
    this.faultGroup,
    this.parts,
    this.tools,
    this.durationMinutes,
    this.safetyWarning,
    this.photos = const [],
  });

  final String machineModelId;
  final String? serialNumber;
  final String? errorCode;
  final String? faultGroup;
  final String symptom;
  final String cause;

  /// Theo đúng thứ tự hiển thị; [SolutionStep.order] sẽ được đánh lại.
  final List<SolutionStep> steps;
  final List<FaultAttachment> photos;
  final String? parts;
  final String? tools;
  final int? durationMinutes;
  final String? safetyWarning;
}

/// 1 dòng kết quả tra cứu.
class FaultRecordSummary {
  const FaultRecordSummary({
    required this.id,
    required this.machineModelName,
    required this.symptom,
    required this.updatedAt,
    required this.source,
    this.errorCode,
    this.faultGroup,
  });

  final String id;
  final String machineModelName;
  final String? errorCode;
  final String? faultGroup;
  final String symptom;
  final DateTime updatedAt;
  final FaultRecordSource source;

  factory FaultRecordSummary.fromMap(Map<String, Object?> map) =>
      FaultRecordSummary(
        id: map['id'] as String,
        machineModelName: (map['machine_name'] as String?) ?? '—',
        errorCode: map['error_code'] as String?,
        faultGroup: map['fault_group'] as String?,
        symptom: map['symptom'] as String,
        updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
        source: FaultRecordSource.parse(map['source'] as String?),
      );
}

/// Bộ lọc tra cứu.
class FaultSearchFilter {
  const FaultSearchFilter({
    this.query = '',
    this.machineModelId,
    this.faultGroup,
    this.errorCode,
  });

  final String query;
  final String? machineModelId;
  final String? faultGroup;
  final String? errorCode;

  bool get hasFilters =>
      machineModelId != null ||
      faultGroup != null ||
      (errorCode?.trim().isNotEmpty ?? false);

  FaultSearchFilter copyWith({
    String? query,
    String? machineModelId,
    String? faultGroup,
    String? errorCode,
    bool clearMachine = false,
    bool clearGroup = false,
    bool clearErrorCode = false,
  }) => FaultSearchFilter(
    query: query ?? this.query,
    machineModelId: clearMachine
        ? null
        : (machineModelId ?? this.machineModelId),
    faultGroup: clearGroup ? null : (faultGroup ?? this.faultGroup),
    errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
  );
}
