import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../utils/grinding_format.dart';
import '../utils/grinding_spec_sheet.dart';

/// Xuất PDF "Catalog máy nghiền" cho 1 model — cùng nội dung với trang
/// Thông số kỹ thuật (3 nhóm thông số + ứng dụng + liên hệ). Dùng
/// `syncfusion_flutter_pdf` + font Roboto giống các PDF máy nghiền khác.
abstract final class GrindingSpecSheetPdfService {
  static final _navy = PdfColor(10, 39, 64);
  static final _green = PdfColor(20, 129, 71);
  static final _muted = PdfColor(96, 119, 134);
  static final _border = PdfColor(211, 225, 229);
  static final _paleBlue = PdfColor(243, 247, 249);

  static Future<Uint8List> buildPdf({
    required GrindingSpecSheet sheet,
    required Set<String> selectionTags,
    required String contactName,
    required String contactPhone,
  }) async {
    final regular = Uint8List.sublistView(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = Uint8List.sublistView(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    PdfFont font(double size, {bool isBold = false}) =>
        PdfTrueTypeFont(isBold ? bold : regular, size);

    final logo = Uint8List.sublistView(
      await rootBundle.load('assets/images/DTCGroup-Slogan.png'),
    );
    Uint8List? machineImage;
    if (sheet.imagePath case final path?) {
      machineImage = Uint8List.sublistView(await rootBundle.load(path));
    }

    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a4
      ..margins.all = 36;
    var page = document.pages.add();
    final width = page.getClientSize().width;
    final pageHeight = page.getClientSize().height;
    var y = 0.0;

    // Header
    final g = page.graphics;
    g.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(0, 0, width, 5),
    );
    _drawImageContain(
      g,
      PdfBitmap(logo),
      const ui.Rect.fromLTWH(0, 12, 132, 42),
    );
    g.drawString(
      'CATALOG MÁY NGHIỀN',
      font(15, isBold: true),
      bounds: ui.Rect.fromLTWH(142, 14, width - 142, 22),
      brush: PdfSolidBrush(_navy),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    g.drawString(
      'DTC PRODUCT · GIẢI PHÁP THIẾT BỊ',
      font(8.5),
      bounds: ui.Rect.fromLTWH(142, 37, width - 142, 14),
      brush: PdfSolidBrush(_muted),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    g.drawLine(PdfPen(_border), const ui.Offset(0, 68), ui.Offset(width, 68));
    y = 82;

    g.drawString(
      sheet.title,
      font(18, isBold: true),
      bounds: ui.Rect.fromLTWH(0, y, width, 24),
      brush: PdfSolidBrush(_navy),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    y += 26;
    if (sheet.series != null) {
      g.drawString(
        sheet.series!.nameVi,
        font(10),
        bounds: ui.Rect.fromLTWH(0, y, width, 14),
        brush: PdfSolidBrush(_muted),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      y += 20;
    }
    if (machineImage != null) {
      _drawImageContain(
        g,
        PdfBitmap(machineImage),
        ui.Rect.fromLTWH(width / 2 - 110, y, 220, 140),
      );
      y += 146;
      if (sheet.imageCaption case final caption?) {
        g.drawString(
          caption,
          font(8),
          bounds: ui.Rect.fromLTWH(0, y, width, 12),
          brush: PdfSolidBrush(_muted),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
        y += 16;
      }
    }

    // Bảng thông số theo 3 nhóm.
    final groups = <(String, List<GrindingSpecItem>)>[
      ('THÔNG SỐ KỸ THUẬT', sheet.technicalRows),
      ('THÔNG SỐ BỔ SUNG', sheet.extraRows),
      ('LẮP ĐẶT', sheet.installRows),
    ];
    for (final (title, rows) in groups) {
      if (rows.isEmpty) continue;
      if (y > pageHeight - 120) {
        page = document.pages.add();
        y = 0;
      }
      y = _sectionTitle(page.graphics, font, title, y, width);
      final grid = PdfGrid()..columns.add(count: 2);
      grid.columns[0].width = width * 0.42;
      for (final row in rows) {
        final r = grid.rows.add();
        r.cells[0].value = row.label;
        r.cells[1].value = row.value;
        r.cells[0].style = PdfGridCellStyle(
          font: font(9.5),
          textBrush: PdfSolidBrush(_muted),
          backgroundBrush: PdfSolidBrush(_paleBlue),
          cellPadding: PdfPaddings(left: 6, right: 6, top: 4, bottom: 4),
          borders: _cellBorders(),
        );
        r.cells[1].style = PdfGridCellStyle(
          font: font(9.5, isBold: true),
          textBrush: PdfSolidBrush(_navy),
          cellPadding: PdfPaddings(left: 6, right: 6, top: 4, bottom: 4),
          borders: _cellBorders(),
        );
      }
      final result = grid.draw(
        page: page,
        bounds: ui.Rect.fromLTWH(0, y, width, 0),
      )!;
      page = result.page;
      y = result.bounds.bottom + 10;
    }

    // Nhãn ứng dụng + mô tả ứng dụng.
    final tags = (selectionTags.toList()..sort())
        .map(GrindingFormat.tagLabel)
        .join(' · ');
    final application = sheet.series?.applicationVi ?? '';
    if (tags.isNotEmpty || application.isNotEmpty) {
      if (y > pageHeight - 120) {
        page = document.pages.add();
        y = 0;
      }
      y = _sectionTitle(page.graphics, font, 'ỨNG DỤNG', y, width);
      final text = [
        if (application.isNotEmpty) application,
        if (tags.isNotEmpty) 'Phù hợp: $tags',
      ].join('\n');
      final element = PdfTextElement(
        text: text,
        font: font(9.5),
        brush: PdfSolidBrush(_navy),
      );
      final result = element.draw(
        page: page,
        bounds: ui.Rect.fromLTWH(0, y, width, 0),
      )!;
      page = result.page;
      y = result.bounds.bottom + 10;
    }

    // Liên hệ
    if (y > pageHeight - 60) {
      page = document.pages.add();
      y = 0;
    }
    y = _sectionTitle(page.graphics, font, 'LIÊN HỆ TƯ VẤN', y, width);
    page.graphics.drawString(
      '$contactName  ·  $contactPhone',
      font(11, isBold: true),
      bounds: ui.Rect.fromLTWH(0, y, width, 18),
      brush: PdfSolidBrush(_navy),
    );

    for (var i = 0; i < document.pages.count; i++) {
      _footer(document.pages[i], font, i + 1, document.pages.count);
    }

    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  static PdfBorders _cellBorders() {
    final pen = PdfPen(_border, width: 0.6);
    return PdfBorders(left: pen, right: pen, top: pen, bottom: pen);
  }

  static double _sectionTitle(
    PdfGraphics g,
    PdfFont Function(double, {bool isBold}) font,
    String title,
    double y,
    double width,
  ) {
    g.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(0, y + 6, 4, 16),
    );
    g.drawString(
      title,
      font(11, isBold: true),
      bounds: ui.Rect.fromLTWH(10, y + 6, width - 10, 16),
      brush: PdfSolidBrush(_navy),
    );
    return y + 28;
  }

  static void _footer(
    PdfPage page,
    PdfFont Function(double, {bool isBold}) font,
    int current,
    int total,
  ) {
    final size = page.getClientSize();
    page.graphics.drawLine(
      PdfPen(_border, width: 0.6),
      ui.Offset(0, size.height - 20),
      ui.Offset(size.width, size.height - 20),
    );
    page.graphics.drawString(
      'DTCGroup · Catalog máy nghiền',
      font(7.2),
      bounds: ui.Rect.fromLTWH(0, size.height - 16, size.width - 60, 12),
      brush: PdfSolidBrush(_muted),
    );
    page.graphics.drawString(
      '$current / $total',
      font(7.2, isBold: true),
      bounds: ui.Rect.fromLTWH(size.width - 55, size.height - 16, 55, 12),
      brush: PdfSolidBrush(_muted),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
  }

  static void _drawImageContain(PdfGraphics g, PdfBitmap image, ui.Rect b) {
    final aspect = image.width / image.height;
    var w = b.width;
    var h = w / aspect;
    if (h > b.height) {
      h = b.height;
      w = h * aspect;
    }
    g.drawImage(
      image,
      ui.Rect.fromLTWH(
        b.left + (b.width - w) / 2,
        b.top + (b.height - h) / 2,
        w,
        h,
      ),
    );
  }
}
