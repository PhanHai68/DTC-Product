import '../models/grinding_proposal.dart';
import '../models/grinding_proposal_line_item.dart';

/// Validate dữ liệu thương mại của Proposal TRƯỚC khi ghi Repository (Phase
/// 11, mục 19-21) — chặn input sai ngay ở tầng UI/Service, không để lọt
/// xuống database. THUẦN DART, không phụ thuộc widget.
///
/// Rule (mục 21, ĐÃ ĐIỀU CHỈNH cho đúng kiến trúc thật — xem `discount` ở
/// [GrindingProposal]): Quantity > 0; Price >= 0; **Discount là SỐ TIỀN**
/// (không phải %, theo docstring gốc Phase 8 `GrindingProposal.discount`)
/// nên chỉ validate `>= 0`, KHÔNG áp trần 0-100 (nếu áp 0-100 sẽ chặn nhầm
/// các khoản giảm giá hợp lệ lớn hơn 100 VND/USD); VAT% 0-100 (đúng là %);
/// Line item quantity > 0; line item price >= 0. Field optional (`null`)
/// LUÔN hợp lệ — validation chỉ áp dụng khi người dùng ĐÃ NHẬP giá trị,
/// không bao giờ tự suy đoán/ép null thành 0.
abstract final class GrindingProposalValidationService {
  static List<String> validate(
    GrindingProposal proposal,
    List<GrindingProposalLineItem> lineItems,
  ) {
    final errors = <String>[];

    if (proposal.machineQuantity != null && proposal.machineQuantity! <= 0) {
      errors.add('Quantity phải lớn hơn 0.');
    }
    if (proposal.machineUnitPrice != null && proposal.machineUnitPrice! < 0) {
      errors.add('Unit price không được âm.');
    }
    if (proposal.discount != null && proposal.discount! < 0) {
      errors.add('Discount không được âm.');
    }
    if (proposal.vatPercent != null &&
        (proposal.vatPercent! < 0 || proposal.vatPercent! > 100)) {
      errors.add('VAT phải trong khoảng 0-100.');
    }

    for (final item in lineItems) {
      final label = item.name.isEmpty ? 'dòng chưa đặt tên' : item.name;
      if (item.quantity != null && item.quantity! <= 0) {
        errors.add('Quantity của "$label" phải lớn hơn 0.');
      }
      if (item.unitPrice != null && item.unitPrice! < 0) {
        errors.add('Unit price của "$label" không được âm.');
      }
    }

    return errors;
  }

  static bool isValid(
    GrindingProposal proposal,
    List<GrindingProposalLineItem> lineItems,
  ) => validate(proposal, lineItems).isEmpty;
}
