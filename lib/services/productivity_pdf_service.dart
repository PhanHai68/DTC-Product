import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/productivity_calc.dart';

abstract final class ProductivityPdfService {
  static final _navy = PdfColor(10, 39, 64);
  static final _green = PdfColor(20, 129, 71);
  static final _muted = PdfColor(96, 119, 134);
  static final _border = PdfColor(211, 225, 229);
  static final _cardBg = PdfColor(246, 249, 250);
  static final _highlightBg = PdfColor(235, 247, 241);

  static Future<Uint8List> build({
    required ProductivityCalcData data,
  }) async {
    final fonts = await _PdfFonts.load();
    final logoData = await rootBundle.load('assets/images/DTCGroup-Slogan.png');
    final verifiedData = await rootBundle.load(
      'assets/images/verified_dtc_product_ink.png',
    );

    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a4
      ..margins.all = 0;

    final page = document.pages.add();
    final graphics = page.graphics;
    final size = page.getClientSize();
    const margin = 32.0;
    final contentWidth = size.width - margin * 2;

    // 1. Dải màu nhận diện trên đỉnh trang
    graphics.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(0, 0, size.width, 8),
    );

    // 2. Logo DTC Group
    _drawImageContain(
      graphics,
      PdfBitmap(Uint8List.sublistView(logoData)),
      const ui.Rect.fromLTWH(margin, 22, 145, 45),
      2048 / 713,
    );

    // 3. Header Tiêu đề
    _text(
      graphics,
      'PHIẾU TÍNH NĂNG SUẤT',
      fonts.bold(17),
      ui.Rect.fromLTWH(190, 24, size.width - margin - 190, 24),
      color: _navy,
      align: PdfTextAlignment.right,
    );
    _text(
      graphics,
      'PRODUCTIVITY CALCULATION REPORT',
      fonts.regular(9),
      ui.Rect.fromLTWH(190, 48, size.width - margin - 190, 14),
      color: _muted,
      align: PdfTextAlignment.right,
    );

    // Đường kẻ phân cách
    graphics.drawLine(
      PdfPen(_border, width: 0.8),
      const ui.Offset(margin, 76),
      ui.Offset(size.width - margin, 76),
    );

    double currentY = 88.0;

    // 4. Khối metadata ngày giờ và mã phiếu
    final dateStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(data.measuredAt);
    final reportCode =
        'PRD-${DateFormat('yyyyMMdd-HHmm').format(data.measuredAt)}';

    _text(
      graphics,
      'Mã báo cáo: $reportCode',
      fonts.regular(9),
      ui.Rect.fromLTWH(margin, currentY, contentWidth / 2, 14),
      color: _muted,
    );
    _text(
      graphics,
      'Thời gian lập: $dateStr',
      fonts.regular(9),
      ui.Rect.fromLTWH(margin + contentWidth / 2, currentY, contentWidth / 2, 14),
      color: _muted,
      align: PdfTextAlignment.right,
    );
    currentY += 24;

    // 5. Phần I: Thông tin chung
    currentY = _drawSectionHeader(
      graphics,
      fonts,
      'I. THÔNG TIN CHUNG / GENERAL INFORMATION',
      margin,
      currentY,
      contentWidth,
    );

    final infoBounds = ui.Rect.fromLTWH(margin, currentY, contentWidth, 76);
    graphics.drawRectangle(
      brush: PdfSolidBrush(_cardBg),
      pen: PdfPen(_border, width: 0.8),
      bounds: infoBounds,
    );

    final colW = (contentWidth - 24) / 2;
    _drawLabelValue(
      graphics,
      fonts,
      'Khách hàng:',
      data.customerName.isEmpty ? 'Chưa xác định' : data.customerName,
      margin + 12,
      currentY + 10,
      colW,
    );
    _drawLabelValue(
      graphics,
      fonts,
      'Tên nguyên liệu:',
      data.materialName.isEmpty ? 'Mẫu nguyên liệu thử nghiệm' : data.materialName,
      margin + 12 + colW + 12,
      currentY + 10,
      colW,
    );
    _drawLabelValue(
      graphics,
      fonts,
      'Ngày giờ đo máy:',
      dateStr,
      margin + 12,
      currentY + 42,
      colW,
    );
    _drawLabelValue(
      graphics,
      fonts,
      'Ghi chú thêm:',
      data.notes.isEmpty ? 'Không có ghi chú thêm' : data.notes,
      margin + 12 + colW + 12,
      currentY + 42,
      colW,
    );

    currentY += 92;

    // 6. Phần II: Dữ liệu đo đạc thực nghiệm
    currentY = _drawSectionHeader(
      graphics,
      fonts,
      'II. DỮ LIỆU ĐO ĐẠC THỰC NGHIỆM / EXPERIMENTAL DATA',
      margin,
      currentY,
      contentWidth,
    );

    final expBounds = ui.Rect.fromLTWH(margin, currentY, contentWidth, 80);
    graphics.drawRectangle(
      brush: PdfSolidBrush(_cardBg),
      pen: PdfPen(_border, width: 0.8),
      bounds: expBounds,
    );

    final expColW = (contentWidth - 24) / 3;
    _drawCardMetric(
      graphics,
      fonts,
      'KHỐI LƯỢNG MẪU ĐO',
      '${data.weightKg.toStringAsFixed(2)} kg',
      'Khối lượng thực cân',
      margin + 8,
      currentY + 8,
      expColW,
    );
    _drawCardMetric(
      graphics,
      fonts,
      'THỜI GIAN ĐO',
      data.formattedDuration,
      '${data.hours}h ${data.minutes}m ${data.seconds}s',
      margin + 8 + expColW,
      currentY + 8,
      expColW,
    );
    _drawCardMetric(
      graphics,
      fonts,
      'QUY RA GIÂY',
      '${data.totalSeconds} giây',
      '(Phút * 60) + Giây',
      margin + 8 + expColW * 2,
      currentY + 8,
      expColW,
    );

    currentY += 96;

    // 7. Phần III: Kết quả tính năng suất
    currentY = _drawSectionHeader(
      graphics,
      fonts,
      'III. KẾT QUẢ TÍNH NĂNG SUẤT / CALCULATED RESULTS',
      margin,
      currentY,
      contentWidth,
    );

    // Box kết quả lớn nổi bật
    final resBounds = ui.Rect.fromLTWH(margin, currentY, contentWidth, 115);
    graphics.drawRectangle(
      brush: PdfSolidBrush(_highlightBg),
      pen: PdfPen(_green, width: 1.2),
      bounds: resBounds,
    );

    final resColW = (contentWidth - 24) / 3;
    _drawBigResultMetric(
      graphics,
      fonts,
      'NĂNG SUẤT (KG/GIỜ)',
      data.kgPerHour > 0 ? NumberFormat('#,##0.0').format(data.kgPerHour) : '0.0',
      'kg/h',
      margin + 8,
      currentY + 12,
      resColW,
      _navy,
    );
    _drawBigResultMetric(
      graphics,
      fonts,
      'NĂNG SUẤT (TẤN/GIỜ)',
      data.tonPerHour > 0 ? NumberFormat('#,##0.00').format(data.tonPerHour) : '0.00',
      'tấn/h',
      margin + 8 + resColW,
      currentY + 12,
      resColW,
      _green,
    );
    _drawBigResultMetric(
      graphics,
      fonts,
      'ƯỚC TÍNH 24H (TẤN/NGÀY)',
      data.tonPerDay > 0 ? NumberFormat('#,##0.0').format(data.tonPerDay) : '0.0',
      'tấn/ngày',
      margin + 8 + resColW * 2,
      currentY + 12,
      resColW,
      _navy,
    );

    // Công thức tính toán
    graphics.drawLine(
      PdfPen(_border, width: 0.6),
      ui.Offset(margin + 12, currentY + 84),
      ui.Offset(margin + contentWidth - 12, currentY + 84),
    );
    _text(
      graphics,
      '• Công thức chuẩn: Năng suất (Kg/Giờ) = (Khối lượng kg / Tổng số giây đo) × 3,600',
      fonts.regular(9),
      ui.Rect.fromLTWH(margin + 16, currentY + 92, contentWidth - 32, 14),
      color: _muted,
    );

    currentY += 135;

    // 8. Phần IV: Xác nhận & Đóng dấu Verified
    final signY = currentY + 15;
    final signW = (contentWidth - 30) / 2;

    _text(
      graphics,
      'NGƯỜI LẬP PHIẾU / KỸ THUẬT VIÊN',
      fonts.bold(10.5),
      ui.Rect.fromLTWH(margin + 20, signY, signW, 16),
      color: _navy,
      align: PdfTextAlignment.center,
    );
    _text(
      graphics,
      '(Ký, ghi rõ họ tên)',
      fonts.regular(8.5),
      ui.Rect.fromLTWH(margin + 20, signY + 18, signW, 14),
      color: _muted,
      align: PdfTextAlignment.center,
    );

    _text(
      graphics,
      'XÁC NHẬN KIỂM ĐỊNH NĂNG SUẤT',
      fonts.bold(10.5),
      ui.Rect.fromLTWH(margin + signW + 30, signY, signW, 16),
      color: _navy,
      align: PdfTextAlignment.center,
    );
    _text(
      graphics,
      '(Đại diện DTC Group Verified)',
      fonts.regular(8.5),
      ui.Rect.fromLTWH(margin + signW + 30, signY + 18, signW, 14),
      color: _muted,
      align: PdfTextAlignment.center,
    );

    // Dấu Verified chính thức của DTC
    _drawImageContain(
      graphics,
      PdfBitmap(Uint8List.sublistView(verifiedData)),
      ui.Rect.fromLTWH(margin + signW + 30 + (signW - 130) / 2, signY + 38, 130, 85),
      130 / 85,
    );

    // 9. Footer chân trang
    graphics.drawLine(
      PdfPen(_border, width: 0.6),
      ui.Offset(margin, size.height - 35),
      ui.Offset(size.width - margin, size.height - 35),
    );
    _text(
      graphics,
      'DTC GROUP • HỆ THỐNG MÁY TÁCH MÀU & THIẾT BỊ CÔNG NGHỆ CAO • HOTLINE: 1800 6464',
      fonts.regular(8),
      ui.Rect.fromLTWH(margin, size.height - 28, contentWidth, 12),
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
    return y + 24;
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
      fonts.regular(8.5),
      ui.Rect.fromLTWH(x, y, width, 12),
      color: _muted,
    );
    _text(
      graphics,
      value,
      fonts.bold(10),
      ui.Rect.fromLTWH(x, y + 14, width, 16),
      color: _navy,
    );
  }

  static void _drawCardMetric(
    PdfGraphics graphics,
    _PdfFonts fonts,
    String title,
    String value,
    String sub,
    double x,
    double y,
    double width,
  ) {
    _text(
      graphics,
      title,
      fonts.bold(8.5),
      ui.Rect.fromLTWH(x, y + 6, width, 12),
      color: _muted,
      align: PdfTextAlignment.center,
    );
    _text(
      graphics,
      value,
      fonts.bold(14),
      ui.Rect.fromLTWH(x, y + 24, width, 20),
      color: _navy,
      align: PdfTextAlignment.center,
    );
    _text(
      graphics,
      sub,
      fonts.regular(8),
      ui.Rect.fromLTWH(x, y + 46, width, 12),
      color: _muted,
      align: PdfTextAlignment.center,
    );
  }

  static void _drawBigResultMetric(
    PdfGraphics graphics,
    _PdfFonts fonts,
    String title,
    String value,
    String unit,
    double x,
    double y,
    double width,
    PdfColor color,
  ) {
    _text(
      graphics,
      title,
      fonts.bold(9),
      ui.Rect.fromLTWH(x, y + 4, width, 14),
      color: _muted,
      align: PdfTextAlignment.center,
    );
    _text(
      graphics,
      value,
      fonts.bold(20),
      ui.Rect.fromLTWH(x, y + 22, width, 28),
      color: color,
      align: PdfTextAlignment.center,
    );
    _text(
      graphics,
      unit,
      fonts.bold(9.5),
      ui.Rect.fromLTWH(x, y + 50, width, 14),
      color: color,
      align: PdfTextAlignment.center,
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
