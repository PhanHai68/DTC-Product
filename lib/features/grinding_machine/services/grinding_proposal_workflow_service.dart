import '../models/grinding_proposal.dart';

/// Luật chuyển trạng thái + quyền hành động của Proposal (Phase 9, mục 8-10).
/// KHÔNG đặt logic này trong Widget — Widget chỉ gọi các hàm `canX` ở đây để
/// quyết định hiện nút nào, và service này cũng là nơi enforce transition
/// hợp lệ trước khi Repository ghi DB.
///
/// Danh sách action hợp lệ theo status (mục 23, "exact lists given"):
/// Draft {Save, Preview, Finalize, Delete}; Final {Export, Share, Mark Sent,
/// Create Revision}; Sent {Export, Share, Mark Accepted, Mark Rejected,
/// Create Revision}; Accepted {Export, Share, View History} — KHÔNG có Create
/// Revision; Rejected {Export, Share, Create Revision, View History}.
class GrindingProposalWorkflowService {
  const GrindingProposalWorkflowService();

  bool canFinalize(GrindingProposal proposal) => proposal.isDraft;

  bool canMarkSent(GrindingProposal proposal) =>
      proposal.status == GrindingProposalStatus.final_;

  bool canAccept(GrindingProposal proposal) =>
      proposal.status == GrindingProposalStatus.sent;

  bool canReject(GrindingProposal proposal) =>
      proposal.status == GrindingProposalStatus.sent;

  /// Accepted KHÔNG cho Create Revision (mục 23) — dù mục 8 nói chung chung
  /// "Final hoặc Sent luôn cho phép", danh sách action theo status ở mục 23
  /// là bản chi tiết/chính xác hơn nên ưu tiên áp dụng đúng theo đó.
  bool canCreateRevision(GrindingProposal proposal) =>
      proposal.status == GrindingProposalStatus.final_ ||
      proposal.status == GrindingProposalStatus.sent ||
      proposal.status == GrindingProposalStatus.rejected;

  /// Chỉ Draft mới xoá trực tiếp được (mục 22).
  bool canDelete(GrindingProposal proposal) => proposal.isDraft;

  bool isExpired(GrindingProposal proposal, {DateTime? now}) =>
      proposal.isExpired(now: now);

  /// Kiểm tra 1 lần chuyển trạng thái trực tiếp (Draft->Final->Sent->
  /// Accepted/Rejected) có hợp lệ không — dùng để chặn assignment tuỳ tiện,
  /// KHÔNG áp dụng cho Create Revision (revision mới luôn bắt đầu ở Draft,
  /// không phải 1 "transition" của proposal cũ).
  bool validateTransition({
    required GrindingProposalStatus from,
    required GrindingProposalStatus to,
  }) {
    switch (from) {
      case GrindingProposalStatus.draft:
        return to == GrindingProposalStatus.final_;
      case GrindingProposalStatus.final_:
        return to == GrindingProposalStatus.sent;
      case GrindingProposalStatus.sent:
        return to == GrindingProposalStatus.accepted ||
            to == GrindingProposalStatus.rejected;
      case GrindingProposalStatus.accepted:
      case GrindingProposalStatus.rejected:
        return false;
    }
  }
}
