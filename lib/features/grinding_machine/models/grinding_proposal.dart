import 'dart:convert';

import 'grinding_technical_snapshot.dart';

/// Trạng thái Proposal — Phase 8 có `draft`/`final_`; Phase 9 mở rộng thêm
/// `sent`/`accepted`/`rejected` theo workflow thương mại (mục 8). Giữ
/// nguyên string lưu DB 'draft'/'final' của Phase 8 để không phá dữ liệu
/// cũ — chỉ CỘNG THÊM giá trị mới, không đổi ý nghĩa `final_`/`isFinal`.
enum GrindingProposalStatus {
  draft,
  final_,
  sent,
  accepted,
  rejected;

  String get value => switch (this) {
    GrindingProposalStatus.draft => 'draft',
    GrindingProposalStatus.final_ => 'final',
    GrindingProposalStatus.sent => 'sent',
    GrindingProposalStatus.accepted => 'accepted',
    GrindingProposalStatus.rejected => 'rejected',
  };

  static GrindingProposalStatus fromValue(String? value) => switch (value) {
    'final' => GrindingProposalStatus.final_,
    'sent' => GrindingProposalStatus.sent,
    'accepted' => GrindingProposalStatus.accepted,
    'rejected' => GrindingProposalStatus.rejected,
    _ => GrindingProposalStatus.draft,
  };
}

/// 1 báo giá/đề xuất kỹ thuật gắn với 1 GrindingSelectionProject — domain
/// RIÊNG với catalog máy VÀ với Project (Phase 8). Giữ [machineId] để tham
/// chiếu, không copy spec vào đây khi còn Draft (đọc live qua
/// GrindingMachineProvider) — chỉ đóng băng vào [technicalSnapshot] đúng 1
/// lần tại thời điểm Finalize, độc lập cho từng revision (Phase 9, mục 7).
///
/// Revision chain (Phase 9, mục 2-4): [rootProposalId] tự tham chiếu — R0
/// có `rootProposalId == id` của chính nó; R1 trở đi có `rootProposalId` =
/// id của R0. Mọi revision trong 1 chain giữ CHUNG [proposalNumber].
class GrindingProposal {
  const GrindingProposal({
    this.id,
    required this.projectId,
    this.proposalNumber,
    this.status = GrindingProposalStatus.draft,
    this.currency = 'VND',
    this.machineId,
    this.machineUnitPrice,
    this.machineQuantity,
    this.discount,
    this.vatPercent,
    this.notes,
    this.technicalSnapshot,
    this.rootProposalId,
    this.revision = 0,
    this.validityDays,
    this.deliveryTime,
    this.warranty,
    this.paymentTerms,
    this.sentAt,
    this.acceptedAt,
    this.rejectedAt,
    this.responseNote,
    required this.createdAt,
    required this.updatedAt,
    this.finalizedAt,
  });

  /// `null` trước khi lưu lần đầu.
  final int? id;
  final int projectId;

  /// `null` trước khi insert lần đầu — Repository tự sinh `GM-<năm>-<id>`
  /// NGAY SAU insert (derive từ AUTOINCREMENT id, không cần bảng đếm riêng)
  /// — CHỈ ở R0; revision sau copy nguyên proposalNumber của R0.
  final String? proposalNumber;

  final GrindingProposalStatus status;

  /// 'VND' | 'USD' — KHÔNG tự quy đổi tỷ giá.
  final String currency;

  final String? machineId;
  final double? machineUnitPrice;
  final double? machineQuantity;

  /// Số tiền giảm giá (không phải %) — trừ trước khi tính VAT.
  final double? discount;

  /// `null` nghĩa là CHƯA XÁC ĐỊNH thuế suất — KHÔNG mặc định 0%.
  final double? vatPercent;

  final String? notes;

  /// `null` khi còn Draft; có giá trị từ thời điểm Finalize trở đi. Mỗi
  /// revision có snapshot RIÊNG, không dùng chung với revision khác.
  final GrindingTechnicalSnapshot? technicalSnapshot;

  /// `null` trước khi lưu lần đầu (Repository tự set = id của chính nó khi
  /// tạo R0, hoặc = rootProposalId của bản gốc khi Create Revision).
  final int? rootProposalId;

  /// 0 = bản gốc (R0); Repository tự tính `MAX(revision)+1` trong
  /// transaction khi Create Revision — KHÔNG tính ở UI (mục 32).
  final int revision;

  /// Số ngày hiệu lực báo giá — dùng derive "Valid until"/"Expired" (mục
  /// 13), KHÔNG lưu ngày hết hạn trực tiếp.
  final int? validityDays;
  final String? deliveryTime;
  final String? warranty;
  final String? paymentTerms;

  final DateTime? sentAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final String? responseNote;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finalizedAt;

  bool get isFinal => status == GrindingProposalStatus.final_;
  bool get isDraft => status == GrindingProposalStatus.draft;

  /// `id == rootProposalId` nghĩa là bản gốc (R0) của chain.
  bool get isRoot => rootProposalId == null || rootProposalId == id;

  /// Ngày hết hạn derive từ [finalizedAt] (ưu tiên) hoặc [sentAt] +
  /// [validityDays] — `null` nếu thiếu 1 trong 2 (không suy đoán).
  DateTime? get expiresAt {
    final base = finalizedAt ?? sentAt;
    if (base == null || validityDays == null) return null;
    return base.add(Duration(days: validityDays!));
  }

  /// So [now] (mặc định thời điểm thật) với [expiresAt] — chỉ derive lúc
  /// hiển thị/kiểm tra, KHÔNG tự đổi status thành Rejected (mục 13).
  bool isExpired({DateTime? now}) {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return (now ?? DateTime.now()).isAfter(expiry);
  }

  GrindingProposal copyWith({
    int? id,
    String? proposalNumber,
    GrindingProposalStatus? status,
    String? currency,
    String? machineId,
    bool clearMachineId = false,
    double? machineUnitPrice,
    bool clearMachineUnitPrice = false,
    double? machineQuantity,
    bool clearMachineQuantity = false,
    double? discount,
    bool clearDiscount = false,
    double? vatPercent,
    bool clearVatPercent = false,
    String? notes,
    bool clearNotes = false,
    GrindingTechnicalSnapshot? technicalSnapshot,
    bool clearTechnicalSnapshot = false,
    int? rootProposalId,
    int? revision,
    int? validityDays,
    bool clearValidityDays = false,
    String? deliveryTime,
    bool clearDeliveryTime = false,
    String? warranty,
    bool clearWarranty = false,
    String? paymentTerms,
    bool clearPaymentTerms = false,
    DateTime? sentAt,
    bool clearSentAt = false,
    DateTime? acceptedAt,
    bool clearAcceptedAt = false,
    DateTime? rejectedAt,
    bool clearRejectedAt = false,
    String? responseNote,
    bool clearResponseNote = false,
    DateTime? updatedAt,
    DateTime? finalizedAt,
  }) {
    return GrindingProposal(
      id: id ?? this.id,
      projectId: projectId,
      proposalNumber: proposalNumber ?? this.proposalNumber,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      machineId: clearMachineId ? null : (machineId ?? this.machineId),
      machineUnitPrice: clearMachineUnitPrice
          ? null
          : (machineUnitPrice ?? this.machineUnitPrice),
      machineQuantity: clearMachineQuantity
          ? null
          : (machineQuantity ?? this.machineQuantity),
      discount: clearDiscount ? null : (discount ?? this.discount),
      vatPercent: clearVatPercent ? null : (vatPercent ?? this.vatPercent),
      notes: clearNotes ? null : (notes ?? this.notes),
      technicalSnapshot: clearTechnicalSnapshot
          ? null
          : (technicalSnapshot ?? this.technicalSnapshot),
      rootProposalId: rootProposalId ?? this.rootProposalId,
      revision: revision ?? this.revision,
      validityDays: clearValidityDays ? null : (validityDays ?? this.validityDays),
      deliveryTime: clearDeliveryTime ? null : (deliveryTime ?? this.deliveryTime),
      warranty: clearWarranty ? null : (warranty ?? this.warranty),
      paymentTerms: clearPaymentTerms ? null : (paymentTerms ?? this.paymentTerms),
      sentAt: clearSentAt ? null : (sentAt ?? this.sentAt),
      acceptedAt: clearAcceptedAt ? null : (acceptedAt ?? this.acceptedAt),
      rejectedAt: clearRejectedAt ? null : (rejectedAt ?? this.rejectedAt),
      responseNote: clearResponseNote ? null : (responseNote ?? this.responseNote),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      finalizedAt: finalizedAt ?? this.finalizedAt,
    );
  }

  factory GrindingProposal.fromRow(Map<String, Object?> row) => GrindingProposal(
    id: row['id'] as int?,
    projectId: row['projectId'] as int,
    proposalNumber: row['proposalNumber'] as String?,
    status: GrindingProposalStatus.fromValue(row['status'] as String?),
    currency: row['currency'] as String? ?? 'VND',
    machineId: row['machineId'] as String?,
    machineUnitPrice: (row['machineUnitPrice'] as num?)?.toDouble(),
    machineQuantity: (row['machineQuantity'] as num?)?.toDouble(),
    discount: (row['discount'] as num?)?.toDouble(),
    vatPercent: (row['vatPercent'] as num?)?.toDouble(),
    notes: row['notes'] as String?,
    technicalSnapshot: row['technicalSnapshotJson'] == null
        ? null
        : GrindingTechnicalSnapshot.fromJson(
            jsonDecode(row['technicalSnapshotJson'] as String) as Map<String, dynamic>,
          ),
    rootProposalId: row['rootProposalId'] as int?,
    revision: (row['revision'] as int?) ?? 0,
    validityDays: row['validityDays'] as int?,
    deliveryTime: row['deliveryTime'] as String?,
    warranty: row['warranty'] as String?,
    paymentTerms: row['paymentTerms'] as String?,
    sentAt: row['sentAt'] == null ? null : DateTime.parse(row['sentAt'] as String),
    acceptedAt: row['acceptedAt'] == null
        ? null
        : DateTime.parse(row['acceptedAt'] as String),
    rejectedAt: row['rejectedAt'] == null
        ? null
        : DateTime.parse(row['rejectedAt'] as String),
    responseNote: row['responseNote'] as String?,
    createdAt: DateTime.parse(row['createdAt'] as String),
    updatedAt: DateTime.parse(row['updatedAt'] as String),
    finalizedAt: row['finalizedAt'] == null
        ? null
        : DateTime.parse(row['finalizedAt'] as String),
  );

  Map<String, Object?> toRow() => {
    if (id != null) 'id': id,
    'projectId': projectId,
    if (proposalNumber != null) 'proposalNumber': proposalNumber,
    'status': status.value,
    'currency': currency,
    'machineId': machineId,
    'machineUnitPrice': machineUnitPrice,
    'machineQuantity': machineQuantity,
    'discount': discount,
    'vatPercent': vatPercent,
    'notes': notes,
    'technicalSnapshotJson': technicalSnapshot == null
        ? null
        : jsonEncode(technicalSnapshot!.toJson()),
    if (rootProposalId != null) 'rootProposalId': rootProposalId,
    'revision': revision,
    'validityDays': validityDays,
    'deliveryTime': deliveryTime,
    'warranty': warranty,
    'paymentTerms': paymentTerms,
    'sentAt': sentAt?.toIso8601String(),
    'acceptedAt': acceptedAt?.toIso8601String(),
    'rejectedAt': rejectedAt?.toIso8601String(),
    'responseNote': responseNote,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'finalizedAt': finalizedAt?.toIso8601String(),
  };

  /// Nhóm [proposals] (phẳng, nhiều chain trộn lẫn) theo `rootProposalId` —
  /// mỗi chain sắp revision TĂNG DẦN nên `chain.last` luôn là latest
  /// revision. Dùng chung cho mọi nơi cần "theo chain" (Phase 10 Dashboard,
  /// v.v.) — KHÔNG thay thế logic nhóm cục bộ đã có/đã test ở nơi khác
  /// (Repository.getProposalChainsByProject, Project Detail) để tránh động
  /// vào code đang pass.
  static List<List<GrindingProposal>> groupByChain(
    List<GrindingProposal> proposals,
  ) {
    final byRoot = <int, List<GrindingProposal>>{};
    for (final p in proposals) {
      final rootId = p.rootProposalId ?? p.id;
      if (rootId == null) continue;
      byRoot.putIfAbsent(rootId, () => []).add(p);
    }
    final chains = byRoot.values.toList();
    for (final chain in chains) {
      chain.sort((a, b) => a.revision.compareTo(b.revision));
    }
    return chains;
  }
}
