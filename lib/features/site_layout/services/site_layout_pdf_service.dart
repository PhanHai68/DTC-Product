import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/site_layout_models.dart';
import 'layout_geometry_service.dart';
import 'site_layout_image_service.dart';
import 'site_photo_service.dart';

abstract final class SiteLayoutPdfService {
  static final _navy = PdfColor(10, 39, 64);
  static final _teal = PdfColor(0, 139, 132);
  static final _muted = PdfColor(86, 106, 119);
  static final _border = PdfColor(211, 225, 229);
  static final _warning = PdfColor(185, 28, 28);

  static Future<Uint8List> build(SiteLayoutBundle bundle) async {
    final fonts = await _SitePdfFonts.load();
    final logo = Uint8List.sublistView(
      await rootBundle.load('assets/images/DTCGroup-Slogan.png'),
    );
    final stamp = Uint8List.sublistView(
      await rootBundle.load('assets/images/verified_dtc_product_ink.png'),
    );
    final layoutPng = await SiteLayoutImageService.buildPng(
      bundle,
      renderProfile: SiteLayoutRenderProfile.pdf,
    );
    final warnings = LayoutGeometryService.validate(bundle);
    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a4
      ..margins.all = 0;

    final introSection = document.sections!.add();
    introSection.pageSettings = PdfPageSettings(
      PdfPageSize.a4,
      PdfPageOrientation.portrait,
    )..margins.all = 0;
    _drawOverview(
      introSection.pages.add(),
      bundle,
      warnings,
      logo,
      stamp,
      fonts,
    );

    final layoutOrientation =
        bundle.project.siteWidthMm > bundle.project.siteLengthMm
        ? PdfPageOrientation.landscape
        : PdfPageOrientation.portrait;
    final layoutSection = document.sections!.add();
    layoutSection.pageSettings = PdfPageSettings(
      PdfPageSize.a4,
      layoutOrientation,
    )..margins.all = 0;
    final layoutPage = layoutSection.pages.add();
    _header(layoutPage, logo, fonts, 'SƠ ĐỒ BỐ TRÍ MẶT BẰNG');
    final bitmap = PdfBitmap(layoutPng);
    final pageSize = layoutPage.getClientSize();
    final available = ui.Rect.fromLTWH(
      20,
      82,
      pageSize.width - 40,
      pageSize.height - 122,
    );
    layoutPage.graphics.drawImage(
      bitmap,
      _containRect(
        bitmap.width.toDouble(),
        bitmap.height.toDouble(),
        available,
      ),
    );

    final detailSection = document.sections!.add();
    detailSection.pageSettings = PdfPageSettings(
      PdfPageSize.a4,
      PdfPageOrientation.portrait,
    )..margins.all = 0;
    _drawMachinePages(detailSection, bundle, fonts, logo);
    _drawNotesPage(detailSection.pages.add(), bundle, warnings, logo, fonts);
    await _drawPhotoPages(detailSection, bundle, logo, fonts);

    for (var index = 0; index < document.pages.count; index++) {
      _footer(document.pages[index], fonts, index + 1, document.pages.count);
    }
    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  static void _drawOverview(
    PdfPage page,
    SiteLayoutBundle bundle,
    List<LayoutWarning> warnings,
    Uint8List logo,
    Uint8List stamp,
    _SitePdfFonts fonts,
  ) {
    _header(page, logo, fonts, 'BÁO CÁO KHẢO SÁT & BỐ TRÍ MẶT BẰNG');
    final g = page.graphics;
    var y = 88.0;
    y = _section(g, fonts, 'THÔNG TIN DỰ ÁN', y);
    final values = <(String, String)>[
      ('Tên dự án', bundle.project.name),
      ('Khách hàng', bundle.project.customer),
      ('Địa điểm', bundle.project.location),
      ('Người khảo sát', bundle.project.surveyor),
      (
        'Ngày khảo sát',
        DateFormat('dd/MM/yyyy').format(bundle.project.surveyDate),
      ),
      ('Phương án', bundle.layout.name),
      (
        'Kích thước mặt bằng lắp đặt',
        '${bundle.project.dimensionUnit.formatValue(bundle.project.siteWidthMm)} × ${bundle.project.dimensionUnit.formatValue(bundle.project.siteLengthMm)} ${bundle.project.dimensionUnit.symbol}',
      ),
      (
        'Chiều cao trần',
        _optionalDimension(
          bundle.project.ceilingHeightMm,
          bundle.project.dimensionUnit,
        ),
      ),
      (
        'Dầm thấp nhất',
        _optionalDimension(
          bundle.project.lowestBeamHeightMm,
          bundle.project.dimensionUnit,
        ),
      ),
    ];
    for (final item in values) {
      _text(
        g,
        item.$1,
        fonts.regular(9),
        ui.Rect.fromLTWH(34, y, 135, 18),
        _muted,
      );
      _text(
        g,
        item.$2.isEmpty ? '—' : item.$2,
        fonts.bold(9.5),
        ui.Rect.fromLTWH(172, y, 370, 18),
        _navy,
      );
      y += 23;
    }
    y += 8;
    y = _section(g, fonts, 'TỔNG QUAN KỸ THUẬT', y);
    final summary = [
      ('Thiết bị', '${bundle.machines.length}'),
      ('Đối tượng mặt bằng', '${bundle.objects.length}'),
      ('Phép đo', '${bundle.measurements.length}'),
      ('Ảnh khảo sát', '${bundle.photos.length}'),
      ('Cảnh báo', '${warnings.length}'),
    ];
    final boxWidth = 98.0;
    for (var index = 0; index < summary.length; index++) {
      final x = 28 + index * 107.0;
      g.drawRectangle(
        bounds: ui.Rect.fromLTWH(x, y, boxWidth, 58),
        pen: PdfPen(_border),
      );
      _text(
        g,
        summary[index].$2,
        fonts.bold(18),
        ui.Rect.fromLTWH(x, y + 8, boxWidth, 22),
        _teal,
        align: PdfTextAlignment.center,
      );
      _text(
        g,
        summary[index].$1,
        fonts.regular(7.5),
        ui.Rect.fromLTWH(x + 2, y + 34, boxWidth - 4, 14),
        _muted,
        align: PdfTextAlignment.center,
      );
    }
    y += 78;
    y = _section(g, fonts, 'GHI CHÚ DỰ ÁN', y);
    _text(
      g,
      bundle.project.notes.trim().isEmpty
          ? 'Không có ghi chú.'
          : bundle.project.notes,
      fonts.regular(9),
      ui.Rect.fromLTWH(34, y, 520, 70),
      _navy,
    );
    g.drawImage(PdfBitmap(stamp), ui.Rect.fromLTWH(470, 657, 72, 72));
    _text(
      g,
      'Báo cáo hỗ trợ khảo sát sơ bộ. Kích thước và điều kiện lắp đặt phải được xác nhận tại hiện trường trước khi thi công.',
      fonts.regular(7.5),
      ui.Rect.fromLTWH(34, 735, 390, 34),
      _muted,
    );
  }

  static void _drawMachinePages(
    PdfSection section,
    SiteLayoutBundle bundle,
    _SitePdfFonts fonts,
    Uint8List logo,
  ) {
    final machines = bundle.machines;
    if (machines.isEmpty) return;
    const rowsPerPage = 12;
    for (var start = 0; start < machines.length; start += rowsPerPage) {
      final page = section.pages.add();
      _header(page, logo, fonts, 'DANH SÁCH THIẾT BỊ');
      final g = page.graphics;
      var y = 90.0;
      const x = 28.0;
      const widths = [82.0, 92.0, 85.0, 70.0, 90.0, 124.0];
      const headers = [
        'Model',
        'Nhóm máy',
        'D × R × C',
        'Góc xoay',
        'Tọa độ X/Y',
        'Khoảng hở T/S/Tr/P',
      ];
      var cursor = x;
      for (var i = 0; i < headers.length; i++) {
        g.drawRectangle(
          bounds: ui.Rect.fromLTWH(cursor, y, widths[i], 30),
          brush: PdfSolidBrush(_navy),
        );
        _text(
          g,
          headers[i],
          fonts.bold(7),
          ui.Rect.fromLTWH(cursor + 3, y + 8, widths[i] - 6, 16),
          PdfColor(255, 255, 255),
          align: PdfTextAlignment.center,
        );
        cursor += widths[i];
      }
      y += 30;
      final chunk = machines.skip(start).take(rowsPerPage);
      for (final machine in chunk) {
        final values = [
          machine.displayName,
          machine.category,
          '${bundle.project.dimensionUnit.formatValue(machine.lengthMm)}×${bundle.project.dimensionUnit.formatValue(machine.widthMm)}×${bundle.project.dimensionUnit.formatValue(machine.heightMm)} ${bundle.project.dimensionUnit.symbol}',
          '${machine.rotationDeg}°',
          '${bundle.project.dimensionUnit.formatValue(machine.xMm)} / ${bundle.project.dimensionUnit.formatValue(machine.yMm)} ${bundle.project.dimensionUnit.symbol}',
          machine.clearanceVerified
              ? '${bundle.project.dimensionUnit.formatValue(machine.clearanceFrontMm)}/${bundle.project.dimensionUnit.formatValue(machine.clearanceRearMm)}/${bundle.project.dimensionUnit.formatValue(machine.clearanceLeftMm)}/${bundle.project.dimensionUnit.formatValue(machine.clearanceRightMm)} ${bundle.project.dimensionUnit.symbol}'
              : 'Chưa xác nhận',
        ];
        cursor = x;
        for (var i = 0; i < values.length; i++) {
          g.drawRectangle(
            bounds: ui.Rect.fromLTWH(cursor, y, widths[i], 38),
            pen: PdfPen(_border),
          );
          _text(
            g,
            values[i],
            fonts.regular(7.5),
            ui.Rect.fromLTWH(cursor + 3, y + 7, widths[i] - 6, 27),
            _navy,
            align: PdfTextAlignment.center,
          );
          cursor += widths[i];
        }
        y += 38;
      }
    }
  }

  static void _drawNotesPage(
    PdfPage page,
    SiteLayoutBundle bundle,
    List<LayoutWarning> warnings,
    Uint8List logo,
    _SitePdfFonts fonts,
  ) {
    _header(page, logo, fonts, 'ĐO ĐẠC, GHI CHÚ & CẢNH BÁO');
    final g = page.graphics;
    var y = 88.0;
    y = _section(g, fonts, 'KẾT QUẢ ĐO', y);
    if (bundle.measurements.isEmpty) {
      _text(
        g,
        'Chưa có phép đo.',
        fonts.regular(9),
        ui.Rect.fromLTWH(34, y, 510, 18),
        _muted,
      );
      y += 28;
    } else {
      for (var i = 0; i < bundle.measurements.length && y < 300; i++) {
        final item = bundle.measurements[i];
        _text(
          g,
          '${i + 1}. ${bundle.project.dimensionUnit.format(item.distanceMm)}',
          fonts.regular(9),
          ui.Rect.fromLTWH(34, y, 510, 18),
          _navy,
        );
        y += 20;
      }
    }
    y += 8;
    y = _section(g, fonts, 'GHI CHÚ VỊ TRÍ', y);
    if (bundle.annotations.isEmpty) {
      _text(
        g,
        'Chưa có ghi chú vị trí.',
        fonts.regular(9),
        ui.Rect.fromLTWH(34, y, 510, 18),
        _muted,
      );
      y += 28;
    } else {
      for (final item in bundle.annotations.take(10)) {
        _text(
          g,
          '${item.markerNumber ?? '•'}. ${item.text}',
          fonts.regular(9),
          ui.Rect.fromLTWH(34, y, 510, 24),
          _navy,
        );
        y += 24;
      }
    }
    y += 8;
    y = _section(g, fonts, 'CẢNH BÁO KỸ THUẬT', y);
    if (warnings.isEmpty) {
      _text(
        g,
        'Không phát hiện cảnh báo trong phương án này.',
        fonts.bold(9),
        ui.Rect.fromLTWH(34, y, 510, 20),
        _teal,
      );
    } else {
      for (final warning in warnings.take(14)) {
        _text(
          g,
          '• ${warning.title}: ${warning.message}',
          fonts.regular(8.3),
          ui.Rect.fromLTWH(34, y, 510, 30),
          _warning,
        );
        y += 31;
        if (y > 745) break;
      }
    }
  }

  static Future<void> _drawPhotoPages(
    PdfSection section,
    SiteLayoutBundle bundle,
    Uint8List logo,
    _SitePdfFonts fonts,
  ) async {
    for (var index = 0; index < bundle.photos.length; index++) {
      final photo = bundle.photos[index];
      final bytes = await SitePhotoService.reportBytes(photo);
      final page = section.pages.add();
      _header(
        page,
        logo,
        fonts,
        'ẢNH KHẢO SÁT ${index + 1}/${bundle.photos.length}',
      );
      final markers = bundle.photoMarkers
          .where((marker) => marker.photoId == photo.id)
          .map((marker) => marker.markerNumber)
          .toList();
      _text(
        page.graphics,
        'Vị trí trên sơ đồ: ${markers.isEmpty ? 'Chưa gắn marker' : markers.join(', ')}',
        fonts.bold(9),
        const ui.Rect.fromLTWH(28, 88, 539, 20),
        _navy,
      );
      if (bytes != null) {
        page.graphics.drawImage(
          PdfBitmap(bytes),
          const ui.Rect.fromLTWH(28, 118, 539, 560),
        );
      } else {
        _text(
          page.graphics,
          'Không thể đọc tệp ảnh gốc.',
          fonts.regular(10),
          const ui.Rect.fromLTWH(28, 180, 539, 30),
          _warning,
          align: PdfTextAlignment.center,
        );
      }
      _text(
        page.graphics,
        photo.caption.isEmpty ? 'Không có chú thích' : photo.caption,
        fonts.bold(10),
        const ui.Rect.fromLTWH(28, 696, 539, 22),
        _navy,
      );
      _text(
        page.graphics,
        photo.note,
        fonts.regular(8.5),
        const ui.Rect.fromLTWH(28, 721, 539, 35),
        _muted,
      );
    }
  }

  static void _header(
    PdfPage page,
    Uint8List logo,
    _SitePdfFonts fonts,
    String title,
  ) {
    final g = page.graphics;
    final size = page.getClientSize();
    g.drawRectangle(
      bounds: ui.Rect.fromLTWH(0, 0, size.width, 8),
      brush: PdfSolidBrush(_teal),
    );
    g.drawImage(PdfBitmap(logo), const ui.Rect.fromLTWH(28, 22, 122, 39));
    _text(
      g,
      title,
      fonts.bold(13),
      ui.Rect.fromLTWH(165, 30, size.width - 193, 24),
      _navy,
      align: PdfTextAlignment.right,
    );
    g.drawLine(
      PdfPen(_border),
      const ui.Offset(28, 72),
      ui.Offset(size.width - 28, 72),
    );
  }

  static double _section(
    PdfGraphics g,
    _SitePdfFonts fonts,
    String title,
    double y,
  ) {
    g.drawRectangle(
      bounds: ui.Rect.fromLTWH(28, y, 4, 20),
      brush: PdfSolidBrush(_teal),
    );
    _text(
      g,
      title,
      fonts.bold(10.5),
      ui.Rect.fromLTWH(39, y + 2, 510, 18),
      _navy,
    );
    return y + 30;
  }

  static void _footer(
    PdfPage page,
    _SitePdfFonts fonts,
    int current,
    int total,
  ) {
    final size = page.getClientSize();
    page.graphics.drawLine(
      PdfPen(_border),
      ui.Offset(28, size.height - 30),
      ui.Offset(size.width - 28, size.height - 30),
    );
    _text(
      page.graphics,
      'DTCGroup · Báo cáo bố trí mặt bằng',
      fonts.regular(7.5),
      ui.Rect.fromLTWH(28, size.height - 23, 350, 12),
      _muted,
    );
    _text(
      page.graphics,
      '$current / $total',
      fonts.bold(7.5),
      ui.Rect.fromLTWH(size.width - 75, size.height - 23, 47, 12),
      _muted,
      align: PdfTextAlignment.right,
    );
  }

  static void _text(
    PdfGraphics g,
    String value,
    PdfFont font,
    ui.Rect bounds,
    PdfColor color, {
    PdfTextAlignment align = PdfTextAlignment.left,
  }) {
    g.drawString(
      value,
      font,
      brush: PdfSolidBrush(color),
      bounds: bounds,
      format: PdfStringFormat(
        alignment: align,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );
  }

  static String _optionalDimension(double? value, SiteDimensionUnit unit) =>
      value == null ? 'Chưa nhập' : unit.format(value);

  static ui.Rect _containRect(
    double sourceWidth,
    double sourceHeight,
    ui.Rect available,
  ) {
    final scale = math.min(
      available.width / sourceWidth,
      available.height / sourceHeight,
    );
    final width = sourceWidth * scale;
    final height = sourceHeight * scale;
    return ui.Rect.fromLTWH(
      available.left + (available.width - width) / 2,
      available.top + (available.height - height) / 2,
      width,
      height,
    );
  }
}

class _SitePdfFonts {
  const _SitePdfFonts(this.regularBytes, this.boldBytes);
  final Uint8List regularBytes;
  final Uint8List boldBytes;

  static Future<_SitePdfFonts> load() async {
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return _SitePdfFonts(
      Uint8List.sublistView(regular),
      Uint8List.sublistView(bold),
    );
  }

  PdfFont regular(double size) => PdfTrueTypeFont(regularBytes, size);
  PdfFont bold(double size) => PdfTrueTypeFont(boldBytes, size);
}
