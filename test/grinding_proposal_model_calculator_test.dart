import 'package:dtc_product/features/grinding_machine/models/grinding_proposal.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal_line_item.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_technical_snapshot.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_proposal_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

GrindingProposal _proposal({
  int? id,
  GrindingProposalStatus status = GrindingProposalStatus.draft,
  String? machineId,
  double? machineUnitPrice,
  double? machineQuantity,
  double? discount,
  double? vatPercent,
  GrindingTechnicalSnapshot? technicalSnapshot,
}) {
  final now = DateTime(2026, 9, 24, 10, 0);
  return GrindingProposal(
    id: id,
    projectId: 1,
    status: status,
    machineId: machineId,
    machineUnitPrice: machineUnitPrice,
    machineQuantity: machineQuantity,
    discount: discount,
    vatPercent: vatPercent,
    technicalSnapshot: technicalSnapshot,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('GrindingProposal model', () {
    test('Field optional không nhập giữ null, không tự thành 0/rỗng', () {
      final p = _proposal();
      expect(p.machineId, isNull);
      expect(p.machineUnitPrice, isNull);
      expect(p.machineQuantity, isNull);
      expect(p.discount, isNull);
      expect(p.vatPercent, isNull);
      expect(p.notes, isNull);
      expect(p.technicalSnapshot, isNull);
      expect(p.status, GrindingProposalStatus.draft);
    });

    test('GrindingProposalStatus parse đúng, giá trị lạ về draft', () {
      expect(GrindingProposalStatus.fromValue('final'), GrindingProposalStatus.final_);
      expect(GrindingProposalStatus.fromValue('draft'), GrindingProposalStatus.draft);
      expect(GrindingProposalStatus.fromValue('khong-hop-le'), GrindingProposalStatus.draft);
      expect(GrindingProposalStatus.fromValue(null), GrindingProposalStatus.draft);
    });

    test('toRow/fromRow giữ đúng dữ liệu kể cả field null', () {
      final p = _proposal(
        id: 5,
        machineId: 'BSP_ULTRAFINE__ASP-350',
        machineUnitPrice: 500000000,
        machineQuantity: 1,
        discount: null,
        vatPercent: 10,
      );
      final row = p.toRow();
      expect(row['discount'], isNull);
      expect(row['technicalSnapshotJson'], isNull);
      expect(row['status'], 'draft');

      final roundTrip = GrindingProposal.fromRow({...row, 'id': 5});
      expect(roundTrip.machineId, p.machineId);
      expect(roundTrip.machineUnitPrice, p.machineUnitPrice);
      expect(roundTrip.discount, isNull);
      expect(roundTrip.vatPercent, 10);
    });

    test('GrindingTechnicalSnapshot toJson/fromJson round-trip đúng', () {
      final snapshot = GrindingTechnicalSnapshot(
        machineId: 'BSP_ULTRAFINE__ASP-350',
        model: 'ASP-350',
        seriesDisplayCode: 'BSP',
        capacityDisplay: '300 - 500 kg/h',
        finenessDisplay: null,
        extraSpecs: const [
          GrindingSnapshotExtraSpec(label: 'Blower motor', value: '5.5 kW'),
        ],
        capturedAt: DateTime(2026, 9, 24, 10, 0),
      );
      final roundTrip = GrindingTechnicalSnapshot.fromJson(snapshot.toJson());
      expect(roundTrip.machineId, snapshot.machineId);
      expect(roundTrip.model, snapshot.model);
      expect(roundTrip.finenessDisplay, isNull);
      expect(roundTrip.extraSpecs.single.label, 'Blower motor');
      expect(roundTrip.capturedAt, snapshot.capturedAt);
    });

    test('toRow lưu đúng technicalSnapshotJson khi Final', () {
      final snapshot = GrindingTechnicalSnapshot(
        machineId: 'M1',
        model: 'ASP-350',
        capturedAt: DateTime(2026, 9, 24),
      );
      final p = _proposal(
        status: GrindingProposalStatus.final_,
        machineId: 'M1',
        technicalSnapshot: snapshot,
      );
      final row = p.toRow();
      expect(row['technicalSnapshotJson'], isNotNull);
      final roundTrip = GrindingProposal.fromRow({...row, 'id': 1});
      expect(roundTrip.isFinal, isTrue);
      expect(roundTrip.technicalSnapshot!.model, 'ASP-350');
    });
  });

  group('GrindingProposalLineItem', () {
    test('lineTotal null nếu thiếu quantity hoặc unitPrice', () {
      const withBoth = GrindingProposalLineItem(
        kind: GrindingProposalLineItemKind.accessory,
        name: 'Blower phụ',
        quantity: 2,
        unitPrice: 1000000,
      );
      expect(withBoth.lineTotal, 2000000);

      const missingPrice = GrindingProposalLineItem(
        kind: GrindingProposalLineItemKind.accessory,
        name: 'Blower phụ',
        quantity: 2,
      );
      expect(missingPrice.lineTotal, isNull);

      const missingQuantity = GrindingProposalLineItem(
        kind: GrindingProposalLineItemKind.accessory,
        name: 'Blower phụ',
        unitPrice: 1000000,
      );
      expect(missingQuantity.lineTotal, isNull);
    });

    test('GrindingProposalLineItemKind parse đúng', () {
      expect(
        GrindingProposalLineItemKind.fromValue('additional_cost'),
        GrindingProposalLineItemKind.additionalCost,
      );
      expect(
        GrindingProposalLineItemKind.fromValue('accessory'),
        GrindingProposalLineItemKind.accessory,
      );
      expect(
        GrindingProposalLineItemKind.fromValue(null),
        GrindingProposalLineItemKind.accessory,
      );
    });
  });

  group('GrindingProposalCalculator — null-safety bắt buộc', () {
    test('Đầy đủ dữ liệu -> tính đúng công thức Machine+Accessories+Additional -Discount +VAT', () {
      final proposal = _proposal(
        machineId: 'M1',
        machineUnitPrice: 100000000,
        machineQuantity: 1,
        discount: 5000000,
        vatPercent: 10,
      );
      final items = [
        const GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.accessory,
          name: 'Cyclone phụ',
          quantity: 1,
          unitPrice: 10000000,
        ),
        const GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.additionalCost,
          name: 'Shipping',
          quantity: 1,
          unitPrice: 3000000,
        ),
      ];
      final totals = GrindingProposalCalculator.calculate(proposal, items);

      expect(totals.machineSubtotal, 100000000);
      expect(totals.accessoriesSubtotal, 10000000);
      expect(totals.additionalCostsSubtotal, 3000000);
      expect(totals.subtotal, 113000000);
      expect(totals.afterDiscount, 108000000);
      expect(totals.vatAmount, closeTo(10800000, 0.001));
      expect(totals.grandTotal, closeTo(118800000, 0.001));
      expect(totals.hasIncompleteData, isFalse);
    });

    test('Thiếu giá 1 accessory -> KHÔNG tính là 0, loại khỏi tổng + cờ hasIncompleteData', () {
      final proposal = _proposal(
        machineId: 'M1',
        machineUnitPrice: 100000000,
        machineQuantity: 1,
        vatPercent: 10,
      );
      final items = [
        const GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.accessory,
          name: 'Có giá',
          quantity: 1,
          unitPrice: 5000000,
        ),
        const GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.accessory,
          name: 'Chưa có giá',
          quantity: 1,
          // unitPrice null có chủ đích.
        ),
      ];
      final totals = GrindingProposalCalculator.calculate(proposal, items);

      // Chỉ cộng dòng có đủ dữ liệu — dòng thiếu giá bị loại, KHÔNG cộng 0.
      expect(totals.accessoriesSubtotal, 5000000);
      expect(totals.hasIncompleteData, isTrue);
    });

    test('Chưa chọn máy, chỉ có accessory -> machineSubtotal null, không hasIncompleteData vì chưa chọn máy', () {
      final proposal = _proposal(vatPercent: 0);
      final items = [
        const GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.accessory,
          name: 'Phụ kiện',
          quantity: 1,
          unitPrice: 1000000,
        ),
      ];
      final totals = GrindingProposalCalculator.calculate(proposal, items);

      expect(totals.machineSubtotal, isNull);
      expect(totals.subtotal, 1000000);
      expect(totals.hasIncompleteData, isFalse);
    });

    test('Đã chọn máy nhưng thiếu giá/số lượng -> machineSubtotal null + hasIncompleteData true', () {
      final proposal = _proposal(machineId: 'M1', vatPercent: 10);
      final totals = GrindingProposalCalculator.calculate(proposal, const []);

      expect(totals.machineSubtotal, isNull);
      expect(totals.hasIncompleteData, isTrue);
    });

    test('vatPercent null -> vatAmount null, grandTotal = afterDiscount, hasIncompleteData true', () {
      final proposal = _proposal(machineId: 'M1', machineUnitPrice: 1000000, machineQuantity: 1);
      final totals = GrindingProposalCalculator.calculate(proposal, const []);

      expect(totals.vatAmount, isNull);
      expect(totals.grandTotal, totals.afterDiscount);
      expect(totals.hasIncompleteData, isTrue);
    });

    test('Không có discount/máy/accessory nào -> tổng vẫn là 0, không lỗi, không crash', () {
      final proposal = _proposal(vatPercent: 10);
      final totals = GrindingProposalCalculator.calculate(proposal, const []);

      expect(totals.subtotal, 0);
      expect(totals.grandTotal, 0);
    });
  });
}
