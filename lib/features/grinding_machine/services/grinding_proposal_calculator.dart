import '../models/grinding_proposal.dart';
import '../models/grinding_proposal_line_item.dart';

/// Kết quả tính tổng — mỗi bước null-safe: dòng/thành phần THIẾU giá KHÔNG
/// được coi là 0, chỉ đơn giản KHÔNG cộng vào tổng, và [hasIncompleteData]
/// báo cho UI/PDF biết để cảnh báo thay vì âm thầm hiện số thiếu chính xác.
class GrindingProposalTotals {
  const GrindingProposalTotals({
    required this.machineSubtotal,
    required this.accessoriesSubtotal,
    required this.additionalCostsSubtotal,
    required this.subtotal,
    required this.discount,
    required this.afterDiscount,
    required this.vatPercent,
    required this.vatAmount,
    required this.grandTotal,
    required this.hasIncompleteData,
  });

  final double? machineSubtotal;
  final double accessoriesSubtotal;
  final double additionalCostsSubtotal;
  final double subtotal;
  final double discount;
  final double afterDiscount;
  final double? vatPercent;
  final double? vatAmount;
  final double grandTotal;

  /// `true` nếu có ít nhất 1 dòng/machine thiếu quantity hoặc unitPrice, HOẶC
  /// chưa xác định VAT — tổng hiển thị có thể chưa đầy đủ.
  final bool hasIncompleteData;
}

/// Tính tổng Proposal (Phase 8) — logic DUY NHẤT dùng chung cho Preview UI
/// và PDF export để không bao giờ lệch số giữa 2 nơi hiển thị. Công thức đã
/// chốt: `Machine subtotal + Accessories + Additional Costs -> trừ Discount
/// -> tính VAT -> Grand Total`. Thuần Dart, không đụng database/widget.
abstract final class GrindingProposalCalculator {
  static GrindingProposalTotals calculate(
    GrindingProposal proposal,
    List<GrindingProposalLineItem> lineItems,
  ) {
    var incomplete = false;

    double? machineSubtotal;
    if (proposal.machineUnitPrice != null && proposal.machineQuantity != null) {
      machineSubtotal = proposal.machineUnitPrice! * proposal.machineQuantity!;
    } else if (proposal.machineId != null) {
      // Có chọn máy nhưng thiếu giá/số lượng -> thiếu dữ liệu thật sự.
      incomplete = true;
    }

    double sumKind(GrindingProposalLineItemKind kind) {
      var sum = 0.0;
      for (final item in lineItems.where((i) => i.kind == kind)) {
        final total = item.lineTotal;
        if (total == null) {
          incomplete = true;
        } else {
          sum += total;
        }
      }
      return sum;
    }

    final accessoriesSubtotal = sumKind(GrindingProposalLineItemKind.accessory);
    final additionalCostsSubtotal = sumKind(GrindingProposalLineItemKind.additionalCost);

    final subtotal = (machineSubtotal ?? 0) + accessoriesSubtotal + additionalCostsSubtotal;
    final discount = proposal.discount ?? 0;
    final afterDiscount = subtotal - discount;

    final vatPercent = proposal.vatPercent;
    if (vatPercent == null) incomplete = true;
    final vatAmount = vatPercent == null ? null : afterDiscount * vatPercent / 100;
    final grandTotal = afterDiscount + (vatAmount ?? 0);

    return GrindingProposalTotals(
      machineSubtotal: machineSubtotal,
      accessoriesSubtotal: accessoriesSubtotal,
      additionalCostsSubtotal: additionalCostsSubtotal,
      subtotal: subtotal,
      discount: discount,
      afterDiscount: afterDiscount,
      vatPercent: vatPercent,
      vatAmount: vatAmount,
      grandTotal: grandTotal,
      hasIncompleteData: incomplete,
    );
  }
}
