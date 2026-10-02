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
  static final _green = PdfColor(20, 129, 71);
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
    final logo = Uint8List.sublistView(
      await rootBundle.load('assets/images/DTCGroup-Slogan.png'),
    );
    final verifiedStamp = Uint8List.sublistView(
      await rootBundle.load('assets/images/verified_dtc_product_ink.png'),
    );
    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a4
      ..margins.all = 36;

    final page = document.pages.add();
    final size = page.getClientSize();
    final contentWidth = size.width;
    var y = 0.0;

    y = _header(
      page.graphics,
      fonts,
      logo,
      verifiedStamp,
      contentWidth,
      proposal,
    );
    y = _projectSection(
      page.graphics,
      fonts,
      project,
      proposal,
      y,
      contentWidth,
    );
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
      y = _sectionTitle(
        page.graphics,
        fonts,
        'PHỤ KIỆN / TUỲ CHỌN',
        y,
        contentWidth,
      );
      y = _lineItemsGrid(
        document,
        page,
        fonts,
        accessories,
        proposal.currency,
        y,
        contentWidth,
      );
    }
    if (additionalCosts.isNotEmpty) {
      y = _sectionTitle(
        page.graphics,
        fonts,
        'CHI PHÍ BỔ SUNG',
        y,
        contentWidth,
      );
      y = _lineItemsGrid(
        document,
        page,
        fonts,
        additionalCosts,
        proposal.currency,
        y,
        contentWidth,
      );
    }

    y = _sectionTitle(page.graphics, fonts, 'TÍNH TOÁN', y, contentWidth);
    y = _calculationBlock(
      page.graphics,
      fonts,
      proposal,
      lineItems,
      y,
      contentWidth,
    );

    if (proposal.notes != null && proposal.notes!.isNotEmpty) {
      y = _sectionTitle(page.graphics, fonts, 'GHI CHÚ', y, contentWidth);
      page.graphics.drawString(
        proposal.notes!,
        fonts.regular(10),
        bounds: ui.Rect.fromLTWH(0, y, contentWidth, 60),
        brush: PdfSolidBrush(_navy),
      );
    }

    for (var index = 0; index < document.pages.count; index++) {
      _footer(document.pages[index], fonts, index + 1, document.pages.count);
    }

    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  static double _header(
    PdfGraphics g,
    _ProposalFonts fonts,
    Uint8List logo,
    Uint8List verifiedStamp,
    double width,
    GrindingProposal proposal,
  ) {
    g.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(0, 0, width, 5),
    );
    _drawImageContain(
      g,
      PdfBitmap(logo),
      const ui.Rect.fromLTWH(0, 12, 132, 42),
    );
    _drawImageContain(
      g,
      PdfBitmap(verifiedStamp),
      ui.Rect.fromLTWH(width - 58, 8, 58, 50),
    );
    g.drawString(
      'TÍNH TOÁN CHI PHÍ LẮP ĐẶT MÁY NGHIỀN',
      fonts.bold(13),
      bounds: ui.Rect.fromLTWH(142, 11, width - 210, 30),
      brush: PdfSolidBrush(_navy),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.right,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );
    final statusLabel = switch (proposal.status) {
      GrindingProposalStatus.draft => 'BẢN NHÁP',
      GrindingProposalStatus.final_ => 'ĐÃ CHỐT',
      GrindingProposalStatus.sent => 'ĐÃ GỬI',
      GrindingProposalStatus.accepted => 'ĐÃ CHẤP NHẬN',
      GrindingProposalStatus.rejected => 'ĐÃ TỪ CHỐI',
    };
    g.drawString(
      'DTC Product · ${proposal.proposalNumber ?? '—'} · Phiên bản ${proposal.revision} · $statusLabel',
      fonts.bold(8.2),
      bounds: ui.Rect.fromLTWH(142, 40, width - 210, 14),
      brush: PdfSolidBrush(proposal.isDraft ? _muted : _cyan),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    if (proposal.revision > 0) {
      g.drawString(
        'Thay thế phiên bản ${proposal.revision - 1}',
        fonts.regular(7.4),
        bounds: ui.Rect.fromLTWH(142, 54, width - 210, 11),
        brush: PdfSolidBrush(_muted),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
    }
    const lineY = 68.0;
    g.drawLine(
      PdfPen(_border, width: 1),
      const ui.Offset(0, lineY),
      ui.Offset(width, lineY),
    );
    return lineY + 8;
  }

  static double _sectionTitle(
    PdfGraphics g,
    _ProposalFonts fonts,
    String title,
    double y,
    double width,
  ) {
    g.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(0, y + 10, 4, 18),
    );
    g.drawString(
      title,
      fonts.bold(11),
      bounds: ui.Rect.fromLTWH(10, y + 10, width - 10, 18),
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
    y = _sectionTitle(g, fonts, 'DỰ ÁN', y, width);
    return _keyValueRows(
      g,
      fonts,
      [
        ('Tên dự án', project.projectName),
        ('Khách hàng', project.customerName),
        ('Ngày', DateFormat('dd/MM/yyyy HH:mm').format(proposal.updatedAt)),
        ('Đơn vị tiền tệ', proposal.currency),
      ],
      y,
      width,
    );
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
    y = _sectionTitle(g, fonts, 'MÁY ĐÃ CHỌN', y, width);
    final snapshot = proposal.technicalSnapshot;

    if (snapshot != null) {
      y = _keyValueRows(
        g,
        fonts,
        [
          ('Model', snapshot.model),
          (
            'Dòng máy',
            [
              snapshot.seriesDisplayCode,
              snapshot.seriesNameVi,
            ].whereType<String>().where((v) => v.isNotEmpty).join(' - '),
          ),
          ('Năng suất', snapshot.capacityDisplay),
          ('Độ mịn', snapshot.finenessDisplay),
          ('Công suất động cơ', snapshot.motorDisplay),
          ('Kích thước', snapshot.dimensionsDisplay),
          ('Trọng lượng', snapshot.weightDisplay),
        ],
        y,
        width,
      );
      if (machineUnavailable) {
        g.drawString(
          'Máy hiện tại không còn trong cơ sở dữ liệu (đang dùng thông số đã lưu ngày '
          '${DateFormat('dd/MM/yyyy').format(snapshot.capturedAt)}).',
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
        'Chưa chọn máy',
        fonts.regular(10),
        bounds: ui.Rect.fromLTWH(0, y, width, 16),
        brush: PdfSolidBrush(_muted),
      );
      return y + 26;
    }
    return _keyValueRows(
      g,
      fonts,
      [
        ('Model', currentMachine.model),
        (
          'Dòng máy',
          [
            currentSeries?.displayCode,
            currentSeries?.nameVi,
          ].whereType<String>().where((v) => v.isNotEmpty).join(' - '),
        ),
        ('Năng suất', GrindingFormat.capacityRange(currentMachine)),
        ('Độ mịn', GrindingFormat.finenessRange(currentMachine)),
        ('Công suất động cơ', GrindingFormat.motorRange(currentMachine)),
        ('Kích thước', currentMachine.dimensionsDisplay),
      ],
      y,
      width,
    );
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
    const headings = ['Tên', 'Số lượng', 'Đơn giá', 'Thành tiền'];
    for (var i = 0; i < headings.length; i++) {
      header.cells[i].value = headings[i];
    }
    for (final item in items) {
      final row = grid.rows.add();
      row.cells[0].value = item.name;
      row.cells[1].value = item.quantity == null ? '—' : _num(item.quantity!);
      row.cells[2].value = item.unitPrice == null
          ? 'Chưa có thông tin'
          : '${_money(item.unitPrice!)} $currency';
      row.cells[3].value = item.lineTotal == null
          ? 'Chưa có thông tin'
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
    String money(double? v) =>
        v == null ? 'Chưa có thông tin' : '${_money(v)} $c';

    y = _keyValueRows(
      g,
      fonts,
      [
        ('Tiền máy', money(totals.machineSubtotal)),
        ('Tổng phụ kiện', money(totals.accessoriesSubtotal)),
        ('Tổng chi phí bổ sung', money(totals.additionalCostsSubtotal)),
        ('Tạm tính', money(totals.subtotal)),
        ('Giảm giá', money(proposal.discount)),
        ('Sau giảm giá', money(totals.afterDiscount)),
        (
          'VAT',
          totals.vatPercent == null
              ? 'Chưa có thông tin'
              : '${_num(totals.vatPercent!)}% (${money(totals.vatAmount)})',
        ),
        ('Tổng cộng', money(totals.grandTotal)),
      ],
      y,
      width,
      placeholder: 'Chưa có thông tin',
    );

    if (totals.hasIncompleteData) {
      g.drawString(
        'Một số hạng mục chưa có đơn giá, số lượng hoặc thuế — tổng tiền có thể chưa đầy đủ.',
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

  static void _footer(
    PdfPage page,
    _ProposalFonts fonts,
    int currentPage,
    int totalPages,
  ) {
    final size = page.getClientSize();
    page.graphics.drawLine(
      PdfPen(_border, width: 0.6),
      ui.Offset(0, size.height - 20),
      ui.Offset(size.width, size.height - 20),
    );
    page.graphics.drawString(
      'DTCGroup · Tính toán chi phí lắp đặt Máy nghiền',
      fonts.regular(7.2),
      bounds: ui.Rect.fromLTWH(0, size.height - 16, size.width - 60, 12),
      brush: PdfSolidBrush(_muted),
    );
    page.graphics.drawString(
      '$currentPage / $totalPages',
      fonts.bold(7.2),
      bounds: ui.Rect.fromLTWH(size.width - 55, size.height - 16, 55, 12),
      brush: PdfSolidBrush(_muted),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
  }

  static void _drawImageContain(
    PdfGraphics graphics,
    PdfBitmap image,
    ui.Rect bounds,
  ) {
    final aspect = image.width / image.height;
    var width = bounds.width;
    var height = width / aspect;
    if (height > bounds.height) {
      height = bounds.height;
      width = height * aspect;
    }
    graphics.drawImage(
      image,
      ui.Rect.fromLTWH(
        bounds.left + (bounds.width - width) / 2,
        bounds.top + (bounds.height - height) / 2,
        width,
        height,
      ),
    );
  }
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
