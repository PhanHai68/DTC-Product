import '../models/grinding_proposal.dart';
import '../models/grinding_proposal_change.dart';
import '../models/grinding_proposal_line_item.dart';

/// So sánh field-level giữa 2 revision — derive lúc runtime, KHÔNG lưu DB
/// (Phase 9, mục 18-19). Chỉ so nguyên giá trị field (vd Notes so nguyên
/// đoạn text cũ/mới), KHÔNG diff ký tự.
class GrindingProposalDiffService {
  const GrindingProposalDiffService();

  List<GrindingProposalChange> diff({
    required GrindingProposal oldProposal,
    required List<GrindingProposalLineItem> oldLineItems,
    required GrindingProposal newProposal,
    required List<GrindingProposalLineItem> newLineItems,
  }) {
    final changes = <GrindingProposalChange>[];

    void addIfChanged(
      String field,
      String? oldValue,
      String? newValue,
      GrindingProposalChangeCategory category,
    ) {
      if (oldValue != newValue) {
        changes.add(
          GrindingProposalChange(
            field: field,
            oldValue: oldValue,
            newValue: newValue,
            category: category,
          ),
        );
      }
    }

    // Commercial.
    addIfChanged(
      'Đơn giá máy',
      oldProposal.machineUnitPrice?.toString(),
      newProposal.machineUnitPrice?.toString(),
      GrindingProposalChangeCategory.commercial,
    );
    addIfChanged(
      'Số lượng máy',
      oldProposal.machineQuantity?.toString(),
      newProposal.machineQuantity?.toString(),
      GrindingProposalChangeCategory.commercial,
    );
    addIfChanged(
      'Tiền tệ',
      oldProposal.currency,
      newProposal.currency,
      GrindingProposalChangeCategory.commercial,
    );
    addIfChanged(
      'Giảm giá',
      oldProposal.discount?.toString(),
      newProposal.discount?.toString(),
      GrindingProposalChangeCategory.commercial,
    );
    addIfChanged(
      'VAT (%)',
      oldProposal.vatPercent?.toString(),
      newProposal.vatPercent?.toString(),
      GrindingProposalChangeCategory.commercial,
    );

    // Terms.
    addIfChanged(
      'Thời gian giao hàng',
      oldProposal.deliveryTime,
      newProposal.deliveryTime,
      GrindingProposalChangeCategory.terms,
    );
    addIfChanged(
      'Bảo hành',
      oldProposal.warranty,
      newProposal.warranty,
      GrindingProposalChangeCategory.terms,
    );
    addIfChanged(
      'Điều khoản thanh toán',
      oldProposal.paymentTerms,
      newProposal.paymentTerms,
      GrindingProposalChangeCategory.terms,
    );
    addIfChanged(
      'Số ngày hiệu lực',
      oldProposal.validityDays?.toString(),
      newProposal.validityDays?.toString(),
      GrindingProposalChangeCategory.terms,
    );
    addIfChanged(
      'Ghi chú',
      oldProposal.notes,
      newProposal.notes,
      GrindingProposalChangeCategory.terms,
    );

    // Technical.
    addIfChanged(
      'Máy được chọn',
      oldProposal.machineId,
      newProposal.machineId,
      GrindingProposalChangeCategory.technical,
    );
    final oldSnapshot = oldProposal.technicalSnapshot;
    final newSnapshot = newProposal.technicalSnapshot;
    addIfChanged(
      'Model',
      oldSnapshot?.model,
      newSnapshot?.model,
      GrindingProposalChangeCategory.technical,
    );
    addIfChanged(
      'Công suất',
      oldSnapshot?.capacityDisplay,
      newSnapshot?.capacityDisplay,
      GrindingProposalChangeCategory.technical,
    );
    addIfChanged(
      'Độ mịn',
      oldSnapshot?.finenessDisplay,
      newSnapshot?.finenessDisplay,
      GrindingProposalChangeCategory.technical,
    );
    addIfChanged(
      'Động cơ',
      oldSnapshot?.motorDisplay,
      newSnapshot?.motorDisplay,
      GrindingProposalChangeCategory.technical,
    );
    addIfChanged(
      'Kích thước',
      oldSnapshot?.dimensionsDisplay,
      newSnapshot?.dimensionsDisplay,
      GrindingProposalChangeCategory.technical,
    );
    addIfChanged(
      'Khối lượng',
      oldSnapshot?.weightDisplay,
      newSnapshot?.weightDisplay,
      GrindingProposalChangeCategory.technical,
    );

    // Line items — ghép theo (kind, name) vì line item không có identity ổn
    // định giữa 2 revision (revision mới insert lại toàn bộ với id mới).
    String key(GrindingProposalLineItem item) => '${item.kind.value}::${item.name}';
    final oldByKey = {for (final i in oldLineItems) key(i): i};
    final newByKey = {for (final i in newLineItems) key(i): i};

    for (final entry in newByKey.entries) {
      if (!oldByKey.containsKey(entry.key)) {
        changes.add(
          GrindingProposalChange(
            field: 'Thêm dòng: ${entry.value.name}',
            oldValue: null,
            newValue:
                '${entry.value.quantity ?? '—'} x ${entry.value.unitPrice ?? '—'}',
            category: GrindingProposalChangeCategory.item,
          ),
        );
      }
    }
    for (final entry in oldByKey.entries) {
      if (!newByKey.containsKey(entry.key)) {
        changes.add(
          GrindingProposalChange(
            field: 'Xoá dòng: ${entry.value.name}',
            oldValue:
                '${entry.value.quantity ?? '—'} x ${entry.value.unitPrice ?? '—'}',
            newValue: null,
            category: GrindingProposalChangeCategory.item,
          ),
        );
      }
    }
    for (final entry in newByKey.entries) {
      final oldItem = oldByKey[entry.key];
      if (oldItem == null) continue;
      final newItem = entry.value;
      addIfChanged(
        'Số lượng: ${newItem.name}',
        oldItem.quantity?.toString(),
        newItem.quantity?.toString(),
        GrindingProposalChangeCategory.item,
      );
      addIfChanged(
        'Đơn giá: ${newItem.name}',
        oldItem.unitPrice?.toString(),
        newItem.unitPrice?.toString(),
        GrindingProposalChangeCategory.item,
      );
    }

    return changes;
  }
}
