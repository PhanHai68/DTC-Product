import 'package:dtc_product/features/grinding_machine/models/grinding_machine.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_proposal_line_item.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_project.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_technical_snapshot.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_proposal_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 9, 24, 15, 30);
  GrindingSelectionProject project() => GrindingSelectionProject(
    id: 1,
    projectName: 'Trà xanh Bảo Lộc',
    customerName: 'Công ty ABC',
    createdAt: now,
    updatedAt: now,
  );

  test('Draft (chưa Finalize): dùng currentMachine, PDF tạo thành công, đủ Project + Selected Machine', () async {
    final proposal = GrindingProposal(
      id: 1,
      projectId: 1,
      proposalNumber: 'GM-2026-0001',
      currency: 'VND',
      machineId: 'BSP_ULTRAFINE__ASP-350',
      machineUnitPrice: 500000000,
      machineQuantity: 1,
      vatPercent: 10,
      createdAt: now,
      updatedAt: now,
    );
    const currentMachine = GrindingMachine(
      machineId: 'BSP_ULTRAFINE__ASP-350',
      seriesCode: 'BSP_ULTRAFINE',
      model: 'ASP-350',
      capacityMinKgH: 300,
      capacityMaxKgH: 500,
      // fineness/motor để trống có chủ đích -> phải hiện "—", KHÔNG "0".
    );

    final bytes = await GrindingProposalPdfService.buildPdf(
      project: project(),
      proposal: proposal,
      lineItems: const [],
      currentMachine: currentMachine,
    );

    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');

    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();

    expect(text, contains('DTC Product'));
    expect(text, contains('GM-2026-0001'));
    expect(text, contains('DRAFT'));
    expect(text, contains('Trà xanh Bảo Lộc'));
    expect(text, contains('Công ty ABC'));
    expect(text, contains('ASP-350'));
    expect(text, contains('—')); // fineness/motor thiếu.
    expect(text, isNot(contains(' 0 kg/h')));
  });

  test(
    'Final: dùng technicalSnapshot đã đóng băng, KHÔNG dùng currentMachine kể cả khi truyền vào',
    () async {
      final snapshot = GrindingTechnicalSnapshot(
        machineId: 'BSP_ULTRAFINE__ASP-350',
        model: 'ASP-350-SNAPSHOT',
        seriesDisplayCode: 'BSP',
        capacityDisplay: '300 - 500 kg/h',
        capturedAt: DateTime(2026, 9, 20),
      );
      final proposal = GrindingProposal(
        id: 2,
        projectId: 1,
        proposalNumber: 'GM-2026-0002',
        status: GrindingProposalStatus.final_,
        technicalSnapshot: snapshot,
        createdAt: now,
        updatedAt: now,
        finalizedAt: now,
      );
      // currentMachine CÓ truyền vào nhưng model KHÁC snapshot -> PDF phải
      // vẫn hiện đúng model trong snapshot, không lẫn dữ liệu current.
      const currentMachineDifferent = GrindingMachine(
        machineId: 'BSP_ULTRAFINE__ASP-350',
        seriesCode: 'BSP_ULTRAFINE',
        model: 'ASP-350-CURRENT-DIFFERENT',
      );

      final bytes = await GrindingProposalPdfService.buildPdf(
        project: project(),
        proposal: proposal,
        lineItems: const [],
        currentMachine: currentMachineDifferent,
      );

      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      document.dispose();

      expect(text, contains('FINAL'));
      expect(text, contains('ASP-350-SNAPSHOT'));
      expect(text, isNot(contains('ASP-350-CURRENT-DIFFERENT')));
    },
  );

  test(
    'Final + machine đã bị xóa khỏi database -> vẫn export được, báo rõ "no longer exists"',
    () async {
      final snapshot = GrindingTechnicalSnapshot(
        machineId: 'DELETED_MACHINE',
        model: 'ASP-350',
        capturedAt: DateTime(2026, 9, 20),
      );
      final proposal = GrindingProposal(
        id: 3,
        projectId: 1,
        proposalNumber: 'GM-2026-0003',
        status: GrindingProposalStatus.final_,
        technicalSnapshot: snapshot,
        createdAt: now,
        updatedAt: now,
        finalizedAt: now,
      );

      final bytes = await GrindingProposalPdfService.buildPdf(
        project: project(),
        proposal: proposal,
        lineItems: const [],
        currentMachine: null, // Không còn trong catalog.
        machineUnavailable: true,
      );

      expect(bytes.length, greaterThan(500));
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      document.dispose();

      expect(text, contains('ASP-350'));
      expect(text, contains('no longer exists'));
    },
  );

  test('Chưa chọn máy -> hiện "No machine selected", không crash', () async {
    final proposal = GrindingProposal(
      id: 4,
      projectId: 1,
      proposalNumber: 'GM-2026-0004',
      createdAt: now,
      updatedAt: now,
    );

    final bytes = await GrindingProposalPdfService.buildPdf(
      project: project(),
      proposal: proposal,
      lineItems: const [],
    );

    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();

    expect(text, contains('No machine selected'));
  });

  test(
    'Accessories/Additional costs + Calculation: null không thành 0, thiếu giá hiện "Not specified"',
    () async {
      final proposal = GrindingProposal(
        id: 5,
        projectId: 1,
        proposalNumber: 'GM-2026-0005',
        machineId: 'M1',
        machineUnitPrice: 100000000,
        machineQuantity: 1,
        vatPercent: 10,
        createdAt: now,
        updatedAt: now,
      );
      const lineItems = [
        GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.accessory,
          name: 'Cyclone phụ',
          quantity: 1,
          unitPrice: 10000000,
        ),
        GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.accessory,
          name: 'Phụ kiện chưa báo giá',
          quantity: 1,
          // unitPrice null có chủ đích.
        ),
        GrindingProposalLineItem(
          kind: GrindingProposalLineItemKind.additionalCost,
          name: 'Shipping',
          quantity: 1,
          unitPrice: 3000000,
        ),
      ];

      final bytes = await GrindingProposalPdfService.buildPdf(
        project: project(),
        proposal: proposal,
        lineItems: lineItems,
        currentMachine: const GrindingMachine(
          machineId: 'M1',
          seriesCode: 'S1',
          model: 'ASP-350',
        ),
      );

      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      document.dispose();

      expect(text, contains('ACCESSORIES'));
      expect(text, contains('ADDITIONAL COSTS'));
      expect(text, contains('Cyclone phụ'));
      expect(text, contains('CALCULATION'));
      expect(text, contains('Grand Total'));
      // Discount chưa nhập -> phải hiện "Not specified", KHÔNG bịa thành 0.
      expect(text, contains('Not specified'));
    },
  );

  test(
    'R1 PDF: hiện đúng proposalNumber, Revision R1, status SENT, dùng snapshot RIÊNG của R1 — R0 không đổi',
    () async {
      final r0Snapshot = GrindingTechnicalSnapshot(
        machineId: 'M1',
        model: 'ASP-350-R0',
        capturedAt: DateTime(2026, 9, 1),
      );
      final r0 = GrindingProposal(
        id: 10,
        projectId: 1,
        proposalNumber: 'GM-2026-0012',
        status: GrindingProposalStatus.final_,
        currency: 'VND',
        machineId: 'M1',
        technicalSnapshot: r0Snapshot,
        rootProposalId: 10,
        revision: 0,
        createdAt: now,
        updatedAt: now,
        finalizedAt: now,
      );
      final r1Snapshot = GrindingTechnicalSnapshot(
        machineId: 'M1',
        model: 'ASP-350-R1-REFRESHED',
        capturedAt: DateTime(2026, 9, 10),
      );
      final r1 = GrindingProposal(
        id: 15,
        projectId: 1,
        proposalNumber: 'GM-2026-0012',
        status: GrindingProposalStatus.sent,
        currency: 'VND',
        machineId: 'M1',
        technicalSnapshot: r1Snapshot,
        rootProposalId: 10,
        revision: 1,
        createdAt: now,
        updatedAt: now,
        finalizedAt: now,
        sentAt: now,
      );

      final r0Bytes = await GrindingProposalPdfService.buildPdf(
        project: project(),
        proposal: r0,
        lineItems: const [],
      );
      final r1Bytes = await GrindingProposalPdfService.buildPdf(
        project: project(),
        proposal: r1,
        lineItems: const [],
      );

      final r0Doc = PdfDocument(inputBytes: r0Bytes);
      final r0Text = PdfTextExtractor(r0Doc).extractText();
      r0Doc.dispose();
      final r1Doc = PdfDocument(inputBytes: r1Bytes);
      final r1Text = PdfTextExtractor(r1Doc).extractText();
      r1Doc.dispose();

      expect(r1Text, contains('GM-2026-0012'));
      expect(r1Text, contains('Revision R1'));
      expect(r1Text, contains('SENT'));
      expect(r1Text, contains('ASP-350-R1-REFRESHED'));
      expect(r1Text, contains('Supersedes Revision R0'));

      // R0 PDF không đổi: vẫn Revision R0, FINAL, snapshot riêng của R0.
      expect(r0Text, contains('Revision R0'));
      expect(r0Text, contains('FINAL'));
      expect(r0Text, contains('ASP-350-R0'));
      expect(r0Text, isNot(contains('ASP-350-R1-REFRESHED')));
      expect(r0Text, isNot(contains('Supersedes')));
    },
  );
}
