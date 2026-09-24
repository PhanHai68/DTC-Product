import 'grinding_proposal.dart';
import 'grinding_proposal_line_item.dart';
import 'grinding_selection_project.dart';

/// Loại lỗi backup (Phase 11, mục 14-16) — UI map sang message phù hợp,
/// KHÔNG hiện raw exception/stack trace cho người dùng.
enum GrindingBackupErrorKind {
  /// File không phải JSON hợp lệ, thiếu section bắt buộc, sai `type`, hoặc
  /// 1 dòng dữ liệu không parse được (timestamp/enum/số hỏng).
  corrupted,

  /// `formatVersion` lớn hơn [GrindingBackupService.supportedFormatVersion]
  /// — app hiện tại KHÔNG được đoán structure, phải từ chối rõ ràng.
  unsupportedVersion,

  /// JSON hợp lệ, parse được từng dòng, nhưng dữ liệu KHÔNG nhất quán (ID
  /// trùng, revision trùng trong 1 chain, tham chiếu project/proposal
  /// không tồn tại trong chính backup).
  integrity,
}

class GrindingBackupException implements Exception {
  const GrindingBackupException(this.kind, this.message, {this.details = const []});

  final GrindingBackupErrorKind kind;
  final String message;
  final List<String> details;

  @override
  String toString() => details.isEmpty ? message : '$message\n${details.join('\n')}';
}

/// Toàn bộ dữ liệu workflow "Máy nghiền" ở 1 thời điểm — KHÔNG gồm catalog
/// máy (phục hồi được từ Excel/JSON seed, mục 2). Đây là "logical backup"
/// (Option B) — dùng lại `toRow()`/`fromRow()` của model hiện có nên mọi
/// giá trị vốn đã là kiểu JSON-compatible (String/num/null), không cần lớp
/// serialize riêng.
class GrindingBackupPayload {
  const GrindingBackupPayload({
    required this.formatVersion,
    required this.createdAt,
    required this.appDatabaseVersion,
    required this.projects,
    required this.projectMachines,
    required this.proposals,
    required this.lineItems,
  });

  static const type = 'dtc_grinding_backup';

  final int formatVersion;
  final DateTime createdAt;
  final int appDatabaseVersion;
  final List<GrindingSelectionProject> projects;

  /// Mỗi phần tử: `{projectId, machineId, role, addedAt}`.
  final List<Map<String, Object?>> projectMachines;
  final List<GrindingProposal> proposals;
  final List<GrindingProposalLineItem> lineItems;

  Map<String, dynamic> toJson() => {
    'type': type,
    'formatVersion': formatVersion,
    'createdAt': createdAt.toIso8601String(),
    'appDatabaseVersion': appDatabaseVersion,
    'projects': projects.map((p) => p.toRow()).toList(),
    'projectMachines': projectMachines,
    'proposals': proposals.map((p) => p.toRow()).toList(),
    'proposalLineItems': lineItems.map((i) => i.toRow()).toList(),
  };
}

/// Tóm tắt hiển thị TRƯỚC khi Restore (mục 9) — người dùng xác nhận dựa
/// trên đây, KHÔNG restore ngay khi chọn file (mục 8).
class GrindingRestorePreview {
  const GrindingRestorePreview({
    required this.createdAt,
    required this.formatVersion,
    required this.projectCount,
    required this.proposalChainCount,
    required this.revisionCount,
    required this.lineItemCount,
    required this.currentProjectCount,
    required this.currentProposalCount,
    required this.missingMachineReferenceCount,
  });

  final DateTime createdAt;
  final int formatVersion;
  final int projectCount;
  final int proposalChainCount;
  final int revisionCount;
  final int lineItemCount;
  final int currentProjectCount;
  final int currentProposalCount;

  /// Số project/proposal trong backup tham chiếu `machineId` KHÔNG có trong
  /// catalog hiện tại — CHỈ mang tính cảnh báo (mục 13, 44), KHÔNG chặn
  /// restore.
  final int missingMachineReferenceCount;
}

/// Kết quả sau khi Restore thành công (mục 44).
class GrindingRestoreResult {
  const GrindingRestoreResult({
    required this.projectsRestored,
    required this.proposalChainsRestored,
    required this.revisionsRestored,
    required this.lineItemsRestored,
    required this.missingMachineReferenceCount,
  });

  final int projectsRestored;
  final int proposalChainsRestored;
  final int revisionsRestored;
  final int lineItemsRestored;
  final int missingMachineReferenceCount;
}
