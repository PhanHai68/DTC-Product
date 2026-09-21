import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/note.dart';

/// Xuất 1 ghi chú thành PDF theo đúng phong cách các phiếu DTC Product khác
/// (xem ProductivityPdfService/DtcPdfExportService) — dải màu nhận diện, logo,
/// tiêu đề, nội dung tự động sang trang mới khi dài, chân trang.
abstract final class NotePdfService {
  static final _navy = PdfColor(10, 39, 64);
  static final _green = PdfColor(20, 129, 71);
  static final _muted = PdfColor(96, 119, 134);
  static final _border = PdfColor(211, 225, 229);

  static Future<Uint8List> build(Note note) async {
    final fonts = await _PdfFonts.load();
    final logoData = await rootBundle.load('assets/images/DTCGroup-Slogan.png');

    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a4
      ..margins.all = 0;

    var page = document.pages.add();
    var graphics = page.graphics;
    final size = page.getClientSize();
    const margin = 32.0;
    final contentWidth = size.width - margin * 2;

    graphics.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(0, 0, size.width, 8),
    );

    _drawImageContain(
      graphics,
      PdfBitmap(Uint8List.sublistView(logoData)),
      const ui.Rect.fromLTWH(margin, 22, 130, 40),
      2048 / 713,
    );

    _text(
      graphics,
      'GHI CHÚ',
      fonts.bold(17),
      ui.Rect.fromLTWH(190, 24, size.width - margin - 190, 24),
      color: _navy,
      align: PdfTextAlignment.right,
    );
    _text(
      graphics,
      'DTC PRODUCT',
      fonts.regular(9),
      ui.Rect.fromLTWH(190, 48, size.width - margin - 190, 14),
      color: _muted,
      align: PdfTextAlignment.right,
    );

    graphics.drawLine(
      PdfPen(_border, width: 0.8),
      const ui.Offset(margin, 76),
      ui.Offset(size.width - margin, 76),
    );

    double currentY = 90;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    _text(
      graphics,
      'Tiêu đề:',
      fonts.regular(9),
      ui.Rect.fromLTWH(margin, currentY, contentWidth, 12),
      color: _muted,
    );
    _text(
      graphics,
      note.title.isEmpty ? '(Không có tiêu đề)' : note.title,
      fonts.bold(12),
      ui.Rect.fromLTWH(margin, currentY + 14, contentWidth, 22),
      color: _navy,
    );
    currentY += 42;

    final halfWidth = (contentWidth - 16) / 2;
    _drawLabelValue(
      graphics,
      fonts,
      'Ngày tạo:',
      dateFormat.format(note.createdAt),
      margin,
      currentY,
      halfWidth,
    );
    if (note.reminderEnabled && note.reminderDateTime != null) {
      _drawLabelValue(
        graphics,
        fonts,
        'Ngày nhắc:',
        dateFormat.format(note.reminderDateTime!),
        margin + halfWidth + 16,
        currentY,
        halfWidth,
      );
    }
    currentY += 40;

    currentY = _drawSectionHeader(
      graphics,
      fonts,
      'NỘI DUNG',
      margin,
      currentY,
      contentWidth,
    );

    final contentText = note.content.trim().isEmpty
        ? '(Không có nội dung)'
        : note.content;
    final contentElement = PdfTextElement(
      text: contentText,
      font: fonts.regular(10.5),
      brush: PdfSolidBrush(_navy),
    );
    var result = contentElement.draw(
      page: page,
      bounds: ui.Rect.fromLTWH(
        margin,
        currentY,
        contentWidth,
        size.height - currentY - 60,
      ),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );
    page = result!.page;
    graphics = page.graphics;
    currentY = result.bounds.bottom + 20;

    if (note.checklistItems.isNotEmpty) {
      if (currentY > size.height - 100) {
        page = document.pages.add();
        graphics = page.graphics;
        currentY = 32;
      }
      currentY = _drawSectionHeader(
        graphics,
        fonts,
        'CHECKLIST',
        margin,
        currentY,
        contentWidth,
      );

      const boxSize = 11.0;
      const boxTextGap = 10.0;
      final itemTextWidth = contentWidth - boxSize - boxTextGap;

      for (final item in note.checklistItems) {
        if (currentY > size.height - 60) {
          page = document.pages.add();
          graphics = page.graphics;
          currentY = 32;
        }

        final itemElement = PdfTextElement(
          text: item.text,
          font: fonts.regular(10.5),
          brush: PdfSolidBrush(item.isCompleted ? _muted : _navy),
        );
        final itemResult = itemElement.draw(
          page: page,
          bounds: ui.Rect.fromLTWH(
            margin + boxSize + boxTextGap,
            currentY,
            itemTextWidth,
            size.height - currentY - 60,
          ),
          format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
        )!;

        // Vẽ checkbox trên trang chứa dòng đầu của mục này, trước khi
        // graphics/page được cập nhật sang trang kế (nếu text tràn trang).
        _drawChecklistBox(
          graphics,
          ui.Rect.fromLTWH(margin, currentY + 1.5, boxSize, boxSize),
          item.isCompleted,
        );

        page = itemResult.page;
        graphics = page.graphics;
        currentY = itemResult.bounds.bottom + 9;
      }
      currentY += 11;
    }

    // Chân trang — vẽ trên trang cuối cùng chứa nội dung.
    final footerY = currentY + 8 > size.height - 40
        ? size.height - 40
        : currentY + 8;
    graphics.drawLine(
      PdfPen(_border, width: 0.6),
      ui.Offset(margin, footerY),
      ui.Offset(size.width - margin, footerY),
    );
    _text(
      graphics,
      'Created by DTC Product',
      fonts.regular(8),
      ui.Rect.fromLTWH(margin, footerY + 6, contentWidth, 12),
      color: _muted,
      align: PdfTextAlignment.center,
    );

    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  static double _drawSectionHeader(
    PdfGraphics graphics,
    _PdfFonts fonts,
    String title,
    double x,
    double y,
    double width,
  ) {
    graphics.drawRectangle(
      brush: PdfSolidBrush(_navy),
      bounds: ui.Rect.fromLTWH(x, y + 2, 4, 15),
    );
    _text(
      graphics,
      title,
      fonts.bold(10.5),
      ui.Rect.fromLTWH(x + 10, y + 2, width - 10, 16),
      color: _navy,
    );
    return y + 26;
  }

  static void _drawLabelValue(
    PdfGraphics graphics,
    _PdfFonts fonts,
    String label,
    String value,
    double x,
    double y,
    double width,
  ) {
    _text(
      graphics,
      label,
      fonts.regular(9),
      ui.Rect.fromLTWH(x, y, width, 12),
      color: _muted,
    );
    _text(
      graphics,
      value,
      fonts.bold(10.5),
      ui.Rect.fromLTWH(x, y + 14, width, 20),
      color: _navy,
    );
  }

  static void _text(
    PdfGraphics graphics,
    String text,
    PdfFont font,
    ui.Rect bounds, {
    PdfColor? color,
    PdfTextAlignment align = PdfTextAlignment.left,
  }) {
    graphics.drawString(
      text,
      font,
      brush: PdfSolidBrush(color ?? _navy),
      bounds: bounds,
      format: PdfStringFormat(
        alignment: align,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );
  }

  /// Vẽ checkbox nhỏ cho 1 mục checklist: ô vuông viền mờ khi chưa xong,
  /// nền xanh + dấu tick trắng khi đã hoàn thành — thay cho ký tự "[x]/[ ]"
  /// đơn điệu trước đây.
  static void _drawChecklistBox(
    PdfGraphics graphics,
    ui.Rect bounds,
    bool completed,
  ) {
    if (completed) {
      graphics.drawRectangle(brush: PdfSolidBrush(_green), bounds: bounds);
      final tickPen = PdfPen(
        PdfColor(255, 255, 255),
        width: 1.4,
        lineCap: PdfLineCap.round,
      );
      graphics.drawLine(
        tickPen,
        ui.Offset(
          bounds.left + bounds.width * 0.22,
          bounds.top + bounds.height * 0.55,
        ),
        ui.Offset(
          bounds.left + bounds.width * 0.42,
          bounds.top + bounds.height * 0.76,
        ),
      );
      graphics.drawLine(
        tickPen,
        ui.Offset(
          bounds.left + bounds.width * 0.42,
          bounds.top + bounds.height * 0.76,
        ),
        ui.Offset(
          bounds.left + bounds.width * 0.82,
          bounds.top + bounds.height * 0.24,
        ),
      );
    } else {
      graphics.drawRectangle(
        pen: PdfPen(_muted, width: 1.0),
        bounds: bounds,
      );
    }
  }

  static void _drawImageContain(
    PdfGraphics graphics,
    PdfBitmap image,
    ui.Rect bounds,
    double aspect,
  ) {
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

class _PdfFonts {
  final Uint8List regularBytes;
  final Uint8List boldBytes;

  const _PdfFonts(this.regularBytes, this.boldBytes);

  static Future<_PdfFonts> load() async {
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return _PdfFonts(
      Uint8List.sublistView(regular),
      Uint8List.sublistView(bold),
    );
  }

  PdfFont regular(double size) => PdfTrueTypeFont(regularBytes, size);
  PdfFont bold(double size) => PdfTrueTypeFont(boldBytes, size);
}
