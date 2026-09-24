import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/grinding_machine.dart';
import '../models/grinding_proposal.dart';
import '../models/grinding_proposal_line_item.dart';
import '../models/grinding_selection_project.dart';
import '../models/grinding_series.dart';
import '../services/grinding_proposal_calculator.dart';
import '../utils/grinding_format.dart';

/// Xuất PDF "Grinding Machine Technical Proposal" (Phase 8) — logic dựng PDF
/// nằm hoàn toàn ở đây (mục 15), UI chỉ gọi [buildPdf]. Nhận dữ liệu ĐÃ
/// RESOLVE sẵn từ caller — không tự đọc SQLite. Draft: caller truyền
/// [currentMachine]/[currentSeries] (đọc live từ GrindingMachineProvider).
/// Final: caller truyền [snapshot] đã đóng băng, PDF chỉ dùng snapshot, kể
/// cả khi [currentMachine] null (máy đã bị xóa khỏi catalog) — mục
/// "Technical Snapshot" Phase 8.
abstract final class GrindingProposalPdfService {
  static final _navy = PdfColor(10, 39, 64);
  static final _cyan = PdfColor(11, 145, 168);
  static final _muted = PdfColor(96, 119, 134);
  static final _border = PdfColor(211, 225, 229);

  static Future<Uint8List> buildPdf({
    required GrindingSelectionProject project,
    required GrindingProposal proposal,
    required List<GrindingProposalLineItem> lineItems,
    GrindingMachine? currentMachine,
    GrindingSeries? currentSeries,
    bool machineUnavailable = false,
  }) async {
    final fonts = await _ProposalFonts.load();
    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a4
      ..margins.all = 36;

    final page = document.pages.add();
    final size = page.getClientSize();
    final contentWidth = size.width;
    var y = 0.0;

    y = _header(page.graphics, fonts, contentWidth, proposal);
    y = _projectSection(page.graphics, fonts, project, proposal, y, contentWidth);
    y = _machineSection(
      page.graphics,
      fonts,
      proposal,
      currentMachine,
      currentSeries,
      machineUnavailable,
      y,
      contentWidth,
    );

    final accessories = lineItems
        .where((i) => i.kind == GrindingProposalLineItemKind.accessory)
        .toList();
    final additionalCosts = lineItems
        .where((i) => i.kind == GrindingProposalLineItemKind.additionalCost)
        .toList();

    if (accessories.isNotEmpty) {
      y = _sectionTitle(page.graphics, fonts, 'ACCESSORIES / OPTIONS', y, contentWidth);
      y = _lineItemsGrid(document, page, fonts, accessories, proposal.currency, y, contentWidth);
    }
    if (additionalCosts.isNotEmpty) {
      y = _sectionTitle(page.graphics, fonts, 'ADDITIONAL COSTS', y, contentWidth);
      y = _lineItemsGrid(document, page, fonts, additionalCosts, proposal.currency, y, contentWidth);
    }

    y = _sectionTitle(page.graphics, fonts, 'CALCULATION', y, contentWidth);
    y = _calculationBlock(page.graphics, fonts, proposal, lineItems, y, contentWidth);

    if (proposal.notes != null && proposal.notes!.isNotEmpty) {
      y = _sectionTitle(page.graphics, fonts, 'NOTES', y, contentWidth);
      page.graphics.drawString(
        proposal.notes!,
        fonts.regular(10),
        bounds: ui.Rect.fromLTWH(0, y, contentWidth, 60),
        brush: PdfSolidBrush(_navy),
      );
    }

    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  static double _header(
    PdfGraphics g,
    _ProposalFonts fonts,
    double width,
    GrindingProposal proposal,
  ) {
    g.drawString(
      'DTC Product',
      fonts.bold(20),
      bounds: ui.Rect.fromLTWH(0, 0, width, 26),
      brush: PdfSolidBrush(_navy),
    );
    g.drawString(
      'Grinding Machine Technical Proposal',
      fonts.regular(13),
      bounds: ui.Rect.fromLTWH(0, 26, width, 20),
      brush: PdfSolidBrush(_cyan),
    );
    final statusLabel = switch (proposal.status) {
      GrindingProposalStatus.draft => 'DRAFT',
      GrindingProposalStatus.final_ => 'FINAL',
      GrindingProposalStatus.sent => 'SENT',
      GrindingProposalStatus.accepted => 'ACCEPTED',
      GrindingProposalStatus.rejected => 'REJECTED',
    };
    g.drawString(
      '${proposal.proposalNumber ?? '—'}  ·  Revision R${proposal.revision}  ·  $statusLabel',
      fonts.bold(11),
      bounds: ui.Rect.fromLTWH(0, 46, width, 16),
      brush: PdfSolidBrush(proposal.isDraft ? _muted : _cyan),
    );
    var lineY = 68.0;
    // Chỉ nêu "Supersedes" (kế thừa), KHÔNG khẳng định revision trước không
    // còn hiệu lực — R trước vẫn mở được/PDF export được bình thường (mục 18).
    if (proposal.revision > 0) {
      g.drawString(
        'Supersedes Revision R${proposal.revision - 1}',
        fonts.regular(9),
        bounds: ui.Rect.fromLTWH(0, 64, width, 14),
        brush: PdfSolidBrush(_muted),
      );
      lineY = 80.0;
    }
    g.drawLine(PdfPen(_border, width: 1), ui.Offset(0, lineY), ui.Offset(width, lineY));
    return lineY + 12;
  }

  static double _sectionTitle(
    PdfGraphics g,
    _ProposalFonts fonts,
    String title,
    double y,
    double width,
  ) {
    g.drawString(
      title,
      fonts.bold(12),
      bounds: ui.Rect.fromLTWH(0, y + 10, width, 18),
      brush: PdfSolidBrush(_navy),
    );
    return y + 32;
  }

  static double _keyValueRows(
    PdfGraphics g,
    _ProposalFonts fonts,
    List<(String, String?)> rows,
    double y,
    double width, {
    String placeholder = '—',
  }) {
    for (final (label, value) in rows) {
      g.drawString(
        label,
        fonts.regular(10),
        bounds: ui.Rect.fromLTWH(0, y, 160, 16),
        brush: PdfSolidBrush(_muted),
      );
      g.drawString(
        (value == null || value.isEmpty) ? placeholder : value,
        fonts.regular(10),
        bounds: ui.Rect.fromLTWH(160, y, width - 160, 16),
        brush: PdfSolidBrush(_navy),
      );
      y += 18;
    }
    return y + 8;
  }

  static double _projectSection(
    PdfGraphics g,
    _ProposalFonts fonts,
    GrindingSelectionProject project,
    GrindingProposal proposal,
    double y,
    double width,
  ) {
    y = _sectionTitle(g, fonts, 'PROJECT', y, width);
    return _keyValueRows(g, fonts, [
      ('Project name', project.projectName),
      ('Customer', project.customerName),
      ('Date', DateFormat('yyyy-MM-dd HH:mm').format(proposal.updatedAt)),
      ('Currency', proposal.currency),
    ], y, width);
  }

  static double _machineSection(
    PdfGraphics g,
    _ProposalFonts fonts,
    GrindingProposal proposal,
    GrindingMachine? currentMachine,
    GrindingSeries? currentSeries,
    bool machineUnavailable,
    double y,
    double width,
  ) {
    y = _sectionTitle(g, fonts, 'SELECTED MACHINE', y, width);
    final snapshot = proposal.technicalSnapshot;

    if (snapshot != null) {
      y = _keyValueRows(g, fonts, [
        ('Model', snapshot.model),
        ('Series', snapshot.seriesDisplayCode ?? snapshot.seriesNameVi),
        ('Capacity', snapshot.capacityDisplay),
        ('Fineness', snapshot.finenessDisplay),
        ('Motor', snapshot.motorDisplay),
        ('Dimensions', snapshot.dimensionsDisplay),
        ('Weight', snapshot.weightDisplay),
      ], y, width);
      if (machineUnavailable) {
        g.drawString(
          'Current machine no longer exists in database (using frozen snapshot from '
          '${DateFormat('yyyy-MM-dd').format(snapshot.capturedAt)}).',
          fonts.regular(9),
          bounds: ui.Rect.fromLTWH(0, y, width, 24),
          brush: PdfSolidBrush(_muted),
        );
        y += 26;
      }
      return y;
    }

    if (currentMachine == null) {
      g.drawString(
        'No machine selected',
        fonts.regular(10),
        bounds: ui.Rect.fromLTWH(0, y, width, 16),
        brush: PdfSolidBrush(_muted),
      );
      return y + 26;
    }
    return _keyValueRows(g, fonts, [
      ('Model', currentMachine.model),
      ('Series', currentSeries?.displayCode),
      ('Capacity', GrindingFormat.capacityRange(currentMachine)),
      ('Fineness', GrindingFormat.finenessRange(currentMachine)),
      ('Motor', GrindingFormat.motorRange(currentMachine)),
      ('Dimensions', currentMachine.dimensionsDisplay),
    ], y, width);
  }

  static double _lineItemsGrid(
    PdfDocument document,
    PdfPage page,
    _ProposalFonts fonts,
    List<GrindingProposalLineItem> items,
    String currency,
    double y,
    double width,
  ) {
    final grid = PdfGrid();
    grid.columns.add(count: 4);
    grid.columns[0].width = width * 0.4;
    grid.columns[1].width = width * 0.15;
    grid.columns[2].width = width * 0.2;
    grid.columns[3].width = width * 0.25;
    grid.style = PdfGridStyle(
      font: fonts.regular(9),
      textBrush: PdfSolidBrush(_navy),
      cellPadding: PdfPaddings(left: 6, right: 6, top: 5, bottom: 5),
    );
    final header = grid.headers.add(1)[0];
    header.style
      ..backgroundBrush = PdfSolidBrush(_navy)
      ..textBrush = PdfBrushes.white
      ..font = fonts.bold(8.5);
    const headings = ['Name', 'Qty', 'Unit price', 'Line total'];
    for (var i = 0; i < headings.length; i++) {
      header.cells[i].value = headings[i];
    }
    for (final item in items) {
      final row = grid.rows.add();
      row.cells[0].value = item.name;
      row.cells[1].value = item.quantity == null ? '—' : _num(item.quantity!);
      row.cells[2].value = item.unitPrice == null
          ? 'Not specified'
          : '${_money(item.unitPrice!)} $currency';
      row.cells[3].value = item.lineTotal == null
          ? 'Not specified'
          : '${_money(item.lineTotal!)} $currency';
    }
    final result = grid.draw(
      page: page,
      bounds: ui.Rect.fromLTWH(0, y, width, 300),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );
    return (result?.bounds.bottom ?? y) + 16;
  }

  static double _calculationBlock(
    PdfGraphics g,
    _ProposalFonts fonts,
    GrindingProposal proposal,
    List<GrindingProposalLineItem> lineItems,
    double y,
    double width,
  ) {
    final totals = GrindingProposalCalculator.calculate(proposal, lineItems);
    final c = proposal.currency;
    String money(double? v) => v == null ? 'Not specified' : '${_money(v)} $c';

    y = _keyValueRows(g, fonts, [
      ('Machine subtotal', money(totals.machineSubtotal)),
      ('Accessories subtotal', money(totals.accessoriesSubtotal)),
      ('Additional costs subtotal', money(totals.additionalCostsSubtotal)),
      ('Subtotal', money(totals.subtotal)),
      ('Discount', money(proposal.discount)),
      ('After discount', money(totals.afterDiscount)),
      (
        'VAT',
        totals.vatPercent == null
            ? 'Not specified'
            : '${_num(totals.vatPercent!)}% (${money(totals.vatAmount)})',
      ),
      ('Grand Total', money(totals.grandTotal)),
    ], y, width, placeholder: 'Not specified');

    if (totals.hasIncompleteData) {
      g.drawString(
        'Some items are missing price/quantity/VAT — totals above may be incomplete.',
        fonts.regular(9),
        bounds: ui.Rect.fromLTWH(0, y, width, 20),
        brush: PdfSolidBrush(_muted),
      );
      y += 22;
    }
    return y;
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static String _money(double v) =>
      NumberFormat.decimalPattern('vi_VN').format(v);
}

class _ProposalFonts {
  final Uint8List regularBytes;
  final Uint8List boldBytes;

  const _ProposalFonts(this.regularBytes, this.boldBytes);

  static Future<_ProposalFonts> load() async {
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return _ProposalFonts(
      Uint8List.sublistView(regular),
      Uint8List.sublistView(bold),
    );
  }

  PdfFont regular(double size) => PdfTrueTypeFont(regularBytes, size);
  PdfFont bold(double size) => PdfTrueTypeFont(boldBytes, size);
}
