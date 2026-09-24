import 'package:dtc_product/features/grinding_machine/models/grinding_proposal.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal_line_item.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_proposal_validation_service.dart';
import 'package:flutter_test/flutter_test.dart';

GrindingProposal _proposal({
  double? machineQuantity,
  double? machineUnitPrice,
  double? discount,
  double? vatPercent,
}) {
  final now = DateTime(2026, 9, 24);
  return GrindingProposal(
    projectId: 1,
    machineQuantity: machineQuantity,
    machineUnitPrice: machineUnitPrice,
    discount: discount,
    vatPercent: vatPercent,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('Quantity 0 -> invalid', () {
    final errors = GrindingProposalValidationService.validate(
      _proposal(machineQuantity: 0),
      const [],
    );
    expect(errors, isNotEmpty);
  });

  test('Quantity âm -> invalid', () {
    final errors = GrindingProposalValidationService.validate(
      _proposal(machineQuantity: -1),
      const [],
    );
    expect(errors, isNotEmpty);
  });

  test('VAT 101 -> invalid', () {
    final errors = GrindingProposalValidationService.validate(
      _proposal(vatPercent: 101),
      const [],
    );
    expect(errors, isNotEmpty);
  });

  test('VAT âm -> invalid', () {
    final errors = GrindingProposalValidationService.validate(
      _proposal(vatPercent: -1),
      const [],
    );
    expect(errors, isNotEmpty);
  });

  test('VAT 0 và 100 (biên) -> hợp lệ', () {
    expect(
      GrindingProposalValidationService.validate(_proposal(vatPercent: 0), const []),
      isEmpty,
    );
    expect(
      GrindingProposalValidationService.validate(_proposal(vatPercent: 100), const []),
      isEmpty,
    );
  });

  test('Discount là SỐ TIỀN (không phải %) -> giá trị lớn hơn 100 vẫn hợp lệ', () {
    final errors = GrindingProposalValidationService.validate(
      _proposal(discount: 50000000),
      const [],
    );
    expect(errors, isEmpty);
  });

  test('Discount âm -> invalid', () {
    final errors = GrindingProposalValidationService.validate(
      _proposal(discount: -1),
      const [],
    );
    expect(errors, isNotEmpty);
  });

  test('Giá âm -> invalid', () {
    final errors = GrindingProposalValidationService.validate(
      _proposal(machineUnitPrice: -1),
      const [],
    );
    expect(errors, isNotEmpty);
  });

  test('null optional price/quantity -> allowed (không báo lỗi)', () {
    final errors = GrindingProposalValidationService.validate(_proposal(), const []);
    expect(errors, isEmpty);
  });

  test('Line item quantity 0 -> invalid', () {
    final errors = GrindingProposalValidationService.validate(
      _proposal(),
      const [
        GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.accessory,
          name: 'Cyclone phụ',
          quantity: 0,
          unitPrice: 100,
        ),
      ],
    );
    expect(errors, isNotEmpty);
  });

  test('Line item unitPrice âm -> invalid', () {
    final errors = GrindingProposalValidationService.validate(
      _proposal(),
      const [
        GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.accessory,
          name: 'Cyclone phụ',
          quantity: 1,
          unitPrice: -5,
        ),
      ],
    );
    expect(errors, isNotEmpty);
  });

  test('Toàn bộ hợp lệ -> danh sách rỗng', () {
    final errors = GrindingProposalValidationService.validate(
      _proposal(machineQuantity: 1, machineUnitPrice: 100000000, vatPercent: 10, discount: 1000000),
      const [
        GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.accessory,
          name: 'Cyclone phụ',
          quantity: 1,
          unitPrice: 5000000,
        ),
      ],
    );
    expect(errors, isEmpty);
  });
}
