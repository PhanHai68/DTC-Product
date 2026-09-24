/// Nhóm thay đổi khi so sánh 2 revision (Phase 9, mục 18-19).
enum GrindingProposalChangeCategory { technical, commercial, terms, item }

/// 1 thay đổi field-level giữa 2 revision — derive lúc runtime bởi
/// [GrindingProposalDiffService], KHÔNG lưu DB.
class GrindingProposalChange {
  const GrindingProposalChange({
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.category,
  });

  final String field;
  final String? oldValue;
  final String? newValue;
  final GrindingProposalChangeCategory category;
}
