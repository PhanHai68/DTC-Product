import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

abstract final class DtcPdfExportService {
  static final _navy = PdfColor(10, 39, 64);
  static final _green = PdfColor(20, 129, 71);
  static final _muted = PdfColor(96, 119, 134);
  static final _border = PdfColor(220, 231, 235);
  static final _paleGreen = PdfColor(234, 247, 241);
  static final _paleBlue = PdfColor(243, 247, 249);

  static Future<Uint8List> buildColorSorterCatalog({
    required Map<String, String> specs,
    required String contactName,
    required String contactPhone,
    required String? machineImagePath,
  }) async {
    final fonts = await _PdfFonts.load();
    final logoBytes = await _loadAsset('assets/images/DTCGroup-Slogan.png');
    final machineBytes = machineImagePath == null
        ? null
        : await _loadAsset(machineImagePath);
    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a4
      ..margins.all = 0;

    final page = document.pages.add();
    final graphics = page.graphics;
    final pageSize = page.getClientSize();
    const margin = 24.0;
    final width = pageSize.width - margin * 2;
    final model = (specs['Model'] ?? 'SC').toUpperCase();

    graphics.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(0, 0, pageSize.width, 7),
    );
    _drawImageContain(
      graphics,
      PdfBitmap(logoBytes),
      ui.Rect.fromLTWH((pageSize.width - 168) / 2, 14, 168, 58),
      2048 / 713,
    );
    graphics.drawLine(
      PdfPen(_border, width: 0.7),
      ui.Offset(margin, 76),
      ui.Offset(pageSize.width - margin, 76),
    );
    _drawText(
      graphics,
      'MÁY TÁCH MÀU $model',
      fonts.bold(22),
      ui.Rect.fromLTWH(margin, 82, width, 28),
      color: _navy,
      alignment: PdfTextAlignment.center,
    );

    if (machineBytes != null) {
      _drawImageContain(
        graphics,
        PdfBitmap(machineBytes),
        ui.Rect.fromLTWH(margin + 32, 126, width - 64, 150),
        838 / 384,
      );
    }

    const metricY = 280.0;
    const metricGap = 8.0;
    final metricWidth = (width - metricGap * 2) / 3;
    _drawMetric(
      graphics,
      fonts,
      ui.Rect.fromLTWH(margin, metricY, metricWidth, 46),
      specs['Năng suất (tấn/giờ)'] ?? '--',
      'Năng suất (T/h)',
    );
    _drawMetric(
      graphics,
      fonts,
      ui.Rect.fromLTWH(
        margin + metricWidth + metricGap,
        metricY,
        metricWidth,
        46,
      ),
      specs['Số Camera'] ?? '--',
      'Số Camera',
    );
    _drawMetric(
      graphics,
      fonts,
      ui.Rect.fromLTWH(
        margin + (metricWidth + metricGap) * 2,
        metricY,
        metricWidth,
        46,
      ),
      specs['Số ejector'] ?? '--',
      'Số Ejector',
    );

    const bodyY = 340.0;
    const columnGap = 11.0;
    final leftWidth = width * 0.47;
    final rightX = margin + leftWidth + columnGap;
    final rightWidth = width - leftWidth - columnGap;
    _drawSectionTitle(
      graphics,
      fonts,
      'THÔNG SỐ KỸ THUẬT',
      ui.Rect.fromLTWH(margin, bodyY, leftWidth, 18),
    );
    _drawSpecTable(
      graphics,
      fonts,
      specs,
      ui.Rect.fromLTWH(margin, bodyY + 22, leftWidth, 200),
    );

    _drawSectionTitle(
      graphics,
      fonts,
      '6 ĐẶC TÍNH CÔNG NGHỆ',
      ui.Rect.fromLTWH(rightX, bodyY, rightWidth, 18),
    );
    _drawTechnologyFeatures(
      graphics,
      fonts,
      ui.Rect.fromLTWH(rightX, bodyY + 22, rightWidth, 200),
    );

    const applicationY = 573.0;
    _drawSectionTitle(
      graphics,
      fonts,
      'CHI TIẾT ỨNG DỤNG',
      ui.Rect.fromLTWH(margin, applicationY, width, 18),
    );
    _drawApplications(
      graphics,
      fonts,
      ui.Rect.fromLTWH(margin, applicationY + 22, width, 96),
    );

    _drawFooter(
      graphics,
      fonts,
      ui.Rect.fromLTWH(margin, 704, width, 90),
      contactName,
      contactPhone,
    );

    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  static Future<Uint8List> buildAuxEquipmentCatalog({
    required String model,
    required List<Map<String, String>> items,
  }) async {
    final fonts = await _PdfFonts.load();
    final logoBytes = await _loadAsset('assets/images/DTCGroup-Slogan.png');
    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a4
      ..orientation = PdfPageOrientation.landscape
      ..margins.all = 28;
    final page = document.pages.add();
    final size = page.getClientSize();
    final graphics = page.graphics;

    _drawImageContain(
      graphics,
      PdfBitmap(logoBytes),
      ui.Rect.fromLTWH((size.width - 135) / 2, 0, 135, 47),
      2048 / 713,
    );
    _drawText(
      graphics,
      'DANH SÁCH THIẾT BỊ PHỤ TRỢ',
      fonts.bold(20),
      ui.Rect.fromLTWH(0, 55, size.width, 26),
      color: _navy,
      alignment: PdfTextAlignment.center,
    );
    _drawText(
      graphics,
      'MÁY TÁCH MÀU ${model.toUpperCase()}',
      fonts.bold(11),
      ui.Rect.fromLTWH(0, 82, size.width, 18),
      color: _green,
      alignment: PdfTextAlignment.center,
    );
    graphics.drawLine(
      PdfPen(_border, width: 0.8),
      const ui.Offset(0, 106),
      ui.Offset(size.width, 106),
    );

    final grid = PdfGrid();
    grid.columns.add(count: 4);
    grid.columns[0].width = size.width * 0.34;
    grid.columns[1].width = size.width * 0.11;
    grid.columns[2].width = size.width * 0.15;
    grid.columns[3].width = size.width * 0.40;
    grid.style = PdfGridStyle(
      font: fonts.regular(8.2),
      textBrush: PdfSolidBrush(_navy),
      cellPadding: PdfPaddings(left: 6, right: 6, top: 6, bottom: 6),
    );
    final header = grid.headers.add(1)[0];
    header.style
      ..backgroundBrush = PdfSolidBrush(_navy)
      ..textBrush = PdfBrushes.white
      ..font = fonts.bold(8.5);
    const headings = [
      'Tên thiết bị',
      'Số lượng',
      'Công suất',
      'Quy cách tham khảo',
    ];
    for (var i = 0; i < headings.length; i++) {
      header.cells[i].value = headings[i];
      header.cells[i].stringFormat.alignment = PdfTextAlignment.center;
    }

    var sectionNumber = 0;
    for (final item in items) {
      final name = item['Tên thiết bị'] ?? '';
      final lowerName = name.toLowerCase().trim();
      final isSection =
          lowerName == 'hệ thống cơ khí phụ trợ' ||
          lowerName == 'hệ thống cơ khí' ||
          lowerName == 'hệ thống nén khí' ||
          lowerName == 'hệ thống khí nén';
      final row = grid.rows.add();
      if (isSection) {
        sectionNumber++;
        row.cells[0]
          ..value = '$sectionNumber. $name'
          ..columnSpan = 4;
        row.style
          ..backgroundBrush = PdfSolidBrush(_paleGreen)
          ..textBrush = PdfSolidBrush(_green)
          ..font = fonts.bold(9);
        continue;
      }
      row.cells[0].value = name;
      row.cells[1].value = item['SL'] ?? item['Số lượng'] ?? '';
      row.cells[2].value = item['Điện năng (HP)'] ?? '';
      row.cells[3].value = item['Qui cách tham khảo'] ?? item['Qui cách'] ?? '';
      row.cells[1].stringFormat.alignment = PdfTextAlignment.center;
      row.cells[2].stringFormat.alignment = PdfTextAlignment.center;
    }
    grid.draw(
      page: page,
      bounds: ui.Rect.fromLTWH(0, 115, size.width, size.height - 150),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );

    for (var i = 0; i < document.pages.count; i++) {
      final current = document.pages[i];
      final currentSize = current.getClientSize();
      _drawText(
        current.graphics,
        'DTCGroup  •  Danh sách thiết bị phụ trợ $model',
        fonts.regular(7),
        ui.Rect.fromLTWH(
          0,
          currentSize.height - 18,
          currentSize.width - 50,
          12,
        ),
        color: _muted,
      );
      _drawText(
        current.graphics,
        '${i + 1}/${document.pages.count}',
        fonts.regular(7),
        ui.Rect.fromLTWH(
          currentSize.width - 50,
          currentSize.height - 18,
          50,
          12,
        ),
        color: _muted,
        alignment: PdfTextAlignment.right,
      );
    }

    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  static Future<Uint8List> _loadAsset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static void _drawImageContain(
    PdfGraphics graphics,
    PdfBitmap image,
    ui.Rect bounds,
    double aspectRatio,
  ) {
    var width = bounds.width;
    var height = width / aspectRatio;
    if (height > bounds.height) {
      height = bounds.height;
      width = height * aspectRatio;
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

  static void _drawText(
    PdfGraphics graphics,
    String text,
    PdfFont font,
    ui.Rect bounds, {
    PdfColor? color,
    PdfTextAlignment alignment = PdfTextAlignment.left,
    PdfVerticalAlignment verticalAlignment = PdfVerticalAlignment.top,
  }) {
    graphics.drawString(
      text,
      font,
      brush: PdfSolidBrush(color ?? _navy),
      bounds: bounds,
      format: PdfStringFormat(
        alignment: alignment,
        lineAlignment: verticalAlignment,
      ),
    );
  }

  static void _drawMetric(
    PdfGraphics graphics,
    _PdfFonts fonts,
    ui.Rect bounds,
    String value,
    String label,
  ) {
    graphics.drawRectangle(
      brush: PdfSolidBrush(_paleGreen),
      pen: PdfPen(PdfColor(211, 235, 223), width: 0.6),
      bounds: bounds,
    );
    _drawText(
      graphics,
      value,
      fonts.bold(18),
      ui.Rect.fromLTWH(bounds.left, bounds.top + 1, bounds.width, 25),
      alignment: PdfTextAlignment.center,
      verticalAlignment: PdfVerticalAlignment.middle,
    );
    _drawText(
      graphics,
      label,
      fonts.bold(9.8),
      ui.Rect.fromLTWH(bounds.left, bounds.top + 27, bounds.width, 15),
      color: _muted,
      alignment: PdfTextAlignment.center,
    );
  }

  static void _drawSectionTitle(
    PdfGraphics graphics,
    _PdfFonts fonts,
    String title,
    ui.Rect bounds,
  ) {
    graphics.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(bounds.left, bounds.top + 1, 4, 15),
    );
    _drawText(
      graphics,
      title,
      fonts.bold(12.3),
      ui.Rect.fromLTWH(bounds.left + 10, bounds.top, bounds.width - 10, 18),
      verticalAlignment: PdfVerticalAlignment.middle,
    );
  }

  static void _drawSpecTable(
    PdfGraphics graphics,
    _PdfFonts fonts,
    Map<String, String> specs,
    ui.Rect bounds,
  ) {
    final rows = <(String, String)>[
      ('Năng suất', '${specs['Năng suất (tấn/giờ)'] ?? '--'} tấn/giờ'),
      ('Số máng', specs['Số máng'] ?? '--'),
      ('Số ejector', specs['Số ejector'] ?? '--'),
      ('Số camera', specs['Số Camera'] ?? '--'),
      ('Độ chính xác', specs['Độ chính xác phân loại'] ?? '--'),
      ('Công suất điện', '${specs['Công suất điện (kW)'] ?? '--'} kW'),
      ('Điện áp', specs['Điện áp'] ?? '--'),
      ('Áp suất khí nén', specs['Áp suất khí nén'] ?? '--'),
      ('Kích thước D×R×C', '${specs['Kích thước (D x R x C mm)'] ?? '--'} mm'),
      ('Trọng lượng', '${specs['Trọng lượng (kg)'] ?? '--'} kg'),
    ];
    final rowHeight = bounds.height / rows.length;
    graphics.drawRectangle(pen: PdfPen(_border, width: 0.6), bounds: bounds);
    for (var i = 0; i < rows.length; i++) {
      final top = bounds.top + rowHeight * i;
      if (i.isEven) {
        graphics.drawRectangle(
          brush: PdfSolidBrush(_paleBlue),
          bounds: ui.Rect.fromLTWH(bounds.left, top, bounds.width, rowHeight),
        );
      }
      if (i > 0) {
        graphics.drawLine(
          PdfPen(_border, width: 0.45),
          ui.Offset(bounds.left, top),
          ui.Offset(bounds.right, top),
        );
      }
      _drawText(
        graphics,
        rows[i].$1,
        fonts.regular(10),
        ui.Rect.fromLTWH(bounds.left + 7, top, bounds.width * 0.42, rowHeight),
        color: _muted,
        verticalAlignment: PdfVerticalAlignment.middle,
      );
      _drawText(
        graphics,
        rows[i].$2,
        fonts.bold(10),
        ui.Rect.fromLTWH(
          bounds.left + bounds.width * 0.41,
          top,
          bounds.width * 0.56 - 6,
          rowHeight,
        ),
        alignment: PdfTextAlignment.right,
        verticalAlignment: PdfVerticalAlignment.middle,
      );
    }
  }

  static void _drawTechnologyFeatures(
    PdfGraphics graphics,
    _PdfFonts fonts,
    ui.Rect bounds,
  ) {
    const features = <(String, String)>[
      (
        'AI Deep Learning',
        'Tự học vật liệu, nhận diện chính xác lỗi phức tạp.',
      ),
      (
        'Analyzer Cloud Control',
        'Giám sát, cảnh báo và tối ưu vận hành từ xa.',
      ),
      ('Mắt diều hâu 3.0', 'Chụp sắc nét từng hạt ở vận tốc cao.'),
      (
        'Tích hợp đa điểm ảnh',
        'Visible, NIR và SWIR phát hiện màu, cấu trúc, tạp chất.',
      ),
      ('Công nghệ PLOV', 'Phân phối hạt ổn định, tăng độ chính xác tia phun.'),
      ('Hút bụi độc lập', 'Giữ camera và đèn LED sạch suốt ca làm việc.'),
    ];
    const gap = 6.0;
    final cardWidth = (bounds.width - gap) / 2;
    final cardHeight = (bounds.height - gap * 2) / 3;
    for (var i = 0; i < features.length; i++) {
      final column = i % 2;
      final row = i ~/ 2;
      final rect = ui.Rect.fromLTWH(
        bounds.left + column * (cardWidth + gap),
        bounds.top + row * (cardHeight + gap),
        cardWidth,
        cardHeight,
      );
      graphics.drawRectangle(
        brush: PdfBrushes.white,
        pen: PdfPen(_border, width: 0.6),
        bounds: rect,
      );
      graphics.drawEllipse(
        ui.Rect.fromLTWH(rect.left + 7, rect.top + 7, 20, 20),
        brush: PdfSolidBrush(_paleGreen),
      );
      _drawText(
        graphics,
        '${i + 1}'.padLeft(2, '0'),
        fonts.bold(8.3),
        ui.Rect.fromLTWH(rect.left + 7, rect.top + 7, 20, 20),
        color: _green,
        alignment: PdfTextAlignment.center,
        verticalAlignment: PdfVerticalAlignment.middle,
      );
      _drawText(
        graphics,
        features[i].$1,
        fonts.bold(9.5),
        ui.Rect.fromLTWH(rect.left + 32, rect.top + 7, rect.width - 38, 18),
        verticalAlignment: PdfVerticalAlignment.middle,
      );
      _drawText(
        graphics,
        features[i].$2,
        fonts.regular(8.4),
        ui.Rect.fromLTWH(
          rect.left + 8,
          rect.top + 31,
          rect.width - 16,
          rect.height - 34,
        ),
        color: _muted,
      );
    }
  }

  static void _drawApplications(
    PdfGraphics graphics,
    _PdfFonts fonts,
    ui.Rect bounds,
  ) {
    const applications = <(String, String)>[
      ('Tách màu sắc', 'Gạo vàng, hạt đỏ, hạt đen, bạc bụng, chấm kim.'),
      ('Tách hình dạng', 'Phân loại hạt tròn, dài, ngắn theo kích thước.'),
      ('Tách tạp chất', 'Loại sạn, đá, nhựa, bông cỏ và mảnh thủy tinh.'),
      ('Bắn ngược', 'Thu hồi gạo tốt, tối ưu lượng khí nén tiêu thụ.'),
    ];
    const gap = 6.0;
    final cardWidth = (bounds.width - gap) / 2;
    final cardHeight = (bounds.height - gap) / 2;
    for (var i = 0; i < applications.length; i++) {
      final column = i % 2;
      final row = i ~/ 2;
      final rect = ui.Rect.fromLTWH(
        bounds.left + column * (cardWidth + gap),
        bounds.top + row * (cardHeight + gap),
        cardWidth,
        cardHeight,
      );
      graphics.drawRectangle(
        brush: PdfSolidBrush(_paleGreen),
        pen: PdfPen(PdfColor(211, 235, 223), width: 0.5),
        bounds: rect,
      );
      _drawApplicationIcon(
        graphics,
        ui.Rect.fromLTWH(rect.left + 8, rect.top + 7, 28, 28),
        i,
      );
      _drawText(
        graphics,
        applications[i].$1,
        fonts.bold(9.8),
        ui.Rect.fromLTWH(rect.left + 44, rect.top + 5, rect.width - 51, 15),
        verticalAlignment: PdfVerticalAlignment.middle,
      );
      _drawText(
        graphics,
        applications[i].$2,
        fonts.regular(8.3),
        ui.Rect.fromLTWH(
          rect.left + 44,
          rect.top + 20,
          rect.width - 51,
          rect.height - 23,
        ),
        color: _muted,
      );
    }
  }

  static void _drawApplicationIcon(
    PdfGraphics graphics,
    ui.Rect bounds,
    int index,
  ) {
    final pen = PdfPen(_green, width: 1.25);
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;
    if (index == 0) {
      graphics.drawRectangle(pen: pen, bounds: bounds);
      graphics.drawEllipse(
        ui.Rect.fromCircle(center: bounds.center, radius: 7),
        pen: pen,
      );
      graphics.drawEllipse(
        ui.Rect.fromCircle(center: bounds.center, radius: 2),
        brush: PdfSolidBrush(_green),
      );
    } else if (index == 1) {
      graphics.drawRectangle(
        pen: pen,
        bounds: ui.Rect.fromLTWH(bounds.left, bounds.top, 8, 8),
      );
      graphics.drawEllipse(
        ui.Rect.fromLTWH(bounds.right - 11, bounds.top, 11, 11),
        pen: pen,
      );
      graphics.drawEllipse(
        ui.Rect.fromCircle(center: ui.Offset(cx, cy + 7), radius: 5.5),
        pen: pen,
      );
    } else if (index == 2) {
      graphics.drawEllipse(bounds, pen: pen);
      graphics.drawEllipse(
        ui.Rect.fromCircle(center: bounds.center, radius: 5.5),
        pen: pen,
      );
      graphics.drawLine(
        pen,
        ui.Offset(cx, bounds.top - 2),
        ui.Offset(cx, bounds.bottom + 2),
      );
      graphics.drawLine(
        pen,
        ui.Offset(bounds.left - 2, cy),
        ui.Offset(bounds.right + 2, cy),
      );
    } else {
      graphics.drawLine(
        pen,
        ui.Offset(bounds.left, cy - 6),
        ui.Offset(bounds.right, cy - 6),
      );
      graphics.drawLine(
        pen,
        ui.Offset(bounds.left, cy + 6),
        ui.Offset(bounds.right, cy + 6),
      );
      graphics.drawLine(
        pen,
        ui.Offset(bounds.left, cy - 6),
        ui.Offset(bounds.left + 5, cy - 11),
      );
      graphics.drawLine(
        pen,
        ui.Offset(bounds.left, cy - 6),
        ui.Offset(bounds.left + 5, cy - 1),
      );
      graphics.drawLine(
        pen,
        ui.Offset(bounds.right, cy + 6),
        ui.Offset(bounds.right - 5, cy + 1),
      );
      graphics.drawLine(
        pen,
        ui.Offset(bounds.right, cy + 6),
        ui.Offset(bounds.right - 5, cy + 11),
      );
    }
  }

  static void _drawFooter(
    PdfGraphics graphics,
    _PdfFonts fonts,
    ui.Rect bounds,
    String contactName,
    String contactPhone,
  ) {
    graphics.drawRectangle(
      brush: PdfSolidBrush(_paleGreen),
      pen: PdfPen(PdfColor(211, 235, 223), width: 0.6),
      bounds: bounds,
    );
    final dividerX = bounds.left + 224;
    final contactCard = ui.Rect.fromLTWH(
      bounds.left + 8,
      bounds.top + 9,
      dividerX - bounds.left - 16,
      bounds.height - 18,
    );
    graphics.drawRectangle(
      brush: PdfSolidBrush(_paleGreen),
      pen: PdfPen(PdfColor(211, 235, 223), width: 0.55),
      bounds: contactCard,
    );
    graphics.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(
        contactCard.left,
        contactCard.top,
        3.5,
        contactCard.height,
      ),
    );
    const contactGroupWidth = 185.0;
    const contactGroupHeight = 54.0;
    final contactGroupLeft =
        contactCard.left + (contactCard.width - contactGroupWidth) / 2;
    final contactGroupTop =
        contactCard.top + (contactCard.height - contactGroupHeight) / 2;
    final contactTextLeft = contactGroupLeft + 35;
    const contactTextWidth = 150.0;
    graphics.drawLine(
      PdfPen(PdfColor(167, 207, 185), width: 0.7),
      ui.Offset(dividerX, bounds.top + 8),
      ui.Offset(dividerX, bounds.bottom - 8),
    );
    _drawPhoneIcon(
      graphics,
      ui.Rect.fromLTWH(contactGroupLeft, contactGroupTop + 11, 30, 30),
    );
    _drawText(
      graphics,
      'LIÊN HỆ TƯ VẤN',
      fonts.bold(7.2),
      ui.Rect.fromLTWH(contactTextLeft, contactGroupTop, contactTextWidth, 12),
      color: _green,
      alignment: PdfTextAlignment.center,
    );
    _drawText(
      graphics,
      contactName,
      fonts.bold(10.8),
      ui.Rect.fromLTWH(
        contactTextLeft,
        contactGroupTop + 16,
        contactTextWidth,
        17,
      ),
      color: _green,
      alignment: PdfTextAlignment.center,
    );
    _drawText(
      graphics,
      contactPhone,
      fonts.bold(9.2),
      ui.Rect.fromLTWH(
        contactTextLeft,
        contactGroupTop + 37,
        contactTextWidth,
        14,
      ),
      color: _green,
      alignment: PdfTextAlignment.center,
    );

    final addressX = dividerX + 8;
    final addressWidth = bounds.right - addressX - 3;
    _drawText(
      graphics,
      'ĐỊA CHỈ',
      fonts.bold(7),
      ui.Rect.fromLTWH(addressX, bounds.top + 4, addressWidth, 11),
      color: _green,
      alignment: PdfTextAlignment.right,
    );
    const addresses = [
      ('Trụ sở chính', 'Số 86, Đường 65, Phường Tân Hưng, TP.HCM'),
      ('VP Hà Nội', '33 Phố Lộc, phường Xuân Đỉnh, Thành phố Hà Nội'),
      ('VP Tây Ninh', 'Thửa 1305, tờ bản đồ số 5, Xã Lương Hòa, Tây Ninh'),
      ('VP Cần Thơ', 'KV. Lân Thạnh 1, Phường Thuận Hưng, Tp. Cần Thơ'),
      ('Showroom', 'Ấp Mỹ Trung, Xã Hội Cư, Đồng Tháp'),
    ];
    for (var i = 0; i < addresses.length; i++) {
      final y = bounds.top + 18 + i * 11.5;
      _drawText(
        graphics,
        '${addresses[i].$1}: ${addresses[i].$2}',
        fonts.regular(6.3),
        ui.Rect.fromLTWH(addressX, y, addressWidth, 10.5),
        alignment: PdfTextAlignment.right,
        verticalAlignment: PdfVerticalAlignment.middle,
      );
    }
  }

  static void _drawPhoneIcon(PdfGraphics graphics, ui.Rect bounds) {
    graphics.drawEllipse(bounds, brush: PdfSolidBrush(PdfColor(218, 241, 229)));
    final left = bounds.left;
    final top = bounds.top;
    final receiver = <ui.Offset>[
      ui.Offset(left + 7, top + 6),
      ui.Offset(left + 12, top + 4),
      ui.Offset(left + 16, top + 10),
      ui.Offset(left + 13, top + 13),
      ui.Offset(left + 16, top + 19),
      ui.Offset(left + 22, top + 22),
      ui.Offset(left + 25, top + 19),
      ui.Offset(left + 30, top + 23),
      ui.Offset(left + 28, top + 29),
      ui.Offset(left + 23, top + 31),
      ui.Offset(left + 15, top + 27),
      ui.Offset(left + 8, top + 20),
      ui.Offset(left + 4, top + 12),
    ];
    graphics.drawPolygon(receiver, brush: PdfSolidBrush(_green));
    graphics.drawLine(
      PdfPen(PdfColor(255, 255, 255), width: 1.1),
      ui.Offset(left + 8, top + 8),
      ui.Offset(left + 12, top + 6),
    );
    graphics.drawLine(
      PdfPen(PdfColor(255, 255, 255), width: 1.1),
      ui.Offset(left + 25, top + 28),
      ui.Offset(left + 29, top + 24),
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
      regular.buffer.asUint8List(regular.offsetInBytes, regular.lengthInBytes),
      bold.buffer.asUint8List(bold.offsetInBytes, bold.lengthInBytes),
    );
  }

  PdfFont regular(double size) => PdfTrueTypeFont(regularBytes, size);
  PdfFont bold(double size) => PdfTrueTypeFont(boldBytes, size);
}
