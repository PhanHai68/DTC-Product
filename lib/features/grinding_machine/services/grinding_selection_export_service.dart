import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/grinding_machine.dart';
import '../models/grinding_machine_match.dart';
import '../models/grinding_selection_project.dart';
import '../models/grinding_series.dart';
import '../utils/grinding_format.dart';

/// Xuất PDF "Grinding Machine Selection Report" (Phase 7, mục 13) — logic
/// dựng PDF nằm hoàn toàn ở đây, KHÔNG trong Widget (mục 15). Nhận dữ liệu
/// ĐÃ ĐƯỢC RESOLVE sẵn (project/machine/recommendation) từ caller — service
/// này không tự đọc SQLite. Dùng `syncfusion_flutter_pdf` + font Roboto sẵn
/// có trong app (không thêm dependency mới).
abstract final class GrindingSelectionExportService {
  static final _navy = PdfColor(10, 39, 64);
  static final _green = PdfColor(20, 129, 71);
  static final _muted = PdfColor(96, 119, 134);
  static final _border = PdfColor(211, 225, 229);
  static final _paleBlue = PdfColor(243, 247, 249);

  static Future<Uint8List> buildPdf({
    required GrindingSelectionProject project,
    List<GrindingMachineMatch> recommendations = const [],
    GrindingMachine? selectedMachine,
    GrindingSeries? selectedSeries,
    List<GrindingMachine> comparisonMachines = const [],
    Map<String, GrindingSeries> seriesByCode = const {},
  }) async {
    final fonts = await _ExportFonts.load();
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

    y = _header(page.graphics, fonts, logo, verifiedStamp, contentWidth);
    y = _projectSection(page.graphics, fonts, project, y, contentWidth);
    y = _requirementSection(page.graphics, fonts, project, y, contentWidth);

    if (recommendations.isNotEmpty) {
      y = _sectionTitle(
        page.graphics,
        fonts,
        'III. MÁY ĐƯỢC ĐỀ XUẤT',
        y,
        contentWidth,
      );
      y = _recommendationsGrid(
        document,
        page,
        fonts,
        recommendations,
        y,
        contentWidth,
      );
    }

    y = _sectionTitle(page.graphics, fonts, 'IV. MÁY ĐÃ CHỌN', y, contentWidth);
    y = _selectedMachineBlock(
      page.graphics,
      fonts,
      selectedMachine,
      selectedSeries,
      y,
      contentWidth,
    );

    if (comparisonMachines.length >= 2) {
      y = _sectionTitle(
        page.graphics,
        fonts,
        'V. SO SÁNH MÁY',
        y,
        contentWidth,
      );
      y = _comparisonGrid(
        document,
        page,
        fonts,
        comparisonMachines,
        seriesByCode,
        y,
        contentWidth,
      );
    }

    if (project.notes != null && project.notes!.isNotEmpty) {
      y = _sectionTitle(page.graphics, fonts, 'VI. GHI CHÚ', y, contentWidth);
      page.graphics.drawString(
        project.notes!,
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
    _ExportFonts fonts,
    Uint8List logo,
    Uint8List verifiedStamp,
    double width,
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
      'BÁO CÁO LỰA CHỌN MÁY NGHIỀN',
      fonts.bold(15),
      bounds: ui.Rect.fromLTWH(142, 14, width - 210, 22),
      brush: PdfSolidBrush(_navy),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.right,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );
    g.drawString(
      'DTC PRODUCT · GIẢI PHÁP THIẾT BỊ',
      fonts.regular(8.5),
      bounds: ui.Rect.fromLTWH(142, 37, width - 210, 14),
      brush: PdfSolidBrush(_muted),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    g.drawLine(
      PdfPen(_border, width: 1),
      ui.Offset(0, 68),
      ui.Offset(width, 68),
    );
    return 76;
  }

  static double _sectionTitle(
    PdfGraphics g,
    _ExportFonts fonts,
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
    _ExportFonts fonts,
    List<(String, String?)> rows,
    double y,
    double width,
  ) {
    for (final (label, value) in rows) {
      g.drawString(
        label,
        fonts.regular(10),
        bounds: ui.Rect.fromLTWH(0, y, 150, 16),
        brush: PdfSolidBrush(_muted),
      );
      g.drawString(
        // Null KHÔNG được biến thành 0/chuỗi rỗng khi hiển thị — luôn "—".
        (value == null || value.isEmpty) ? '—' : value,
        fonts.regular(10),
        bounds: ui.Rect.fromLTWH(150, y, width - 150, 16),
        brush: PdfSolidBrush(_navy),
      );
      y += 18;
    }
    return y + 8;
  }

  static double _projectSection(
    PdfGraphics g,
    _ExportFonts fonts,
    GrindingSelectionProject project,
    double y,
    double width,
  ) {
    y = _sectionTitle(g, fonts, 'I. THÔNG TIN DỰ ÁN', y, width);
    return _keyValueRows(
      g,
      fonts,
      [
        ('Tên dự án', project.projectName),
        ('Khách hàng', project.customerName),
        (
          'Ngày cập nhật',
          DateFormat('dd/MM/yyyy HH:mm').format(project.updatedAt),
        ),
      ],
      y,
      width,
    );
  }

  static double _requirementSection(
    PdfGraphics g,
    _ExportFonts fonts,
    GrindingSelectionProject project,
    double y,
    double width,
  ) {
    y = _sectionTitle(g, fonts, 'II. YÊU CẦU KHÁCH HÀNG', y, width);
    return _keyValueRows(
      g,
      fonts,
      [
        ('Nguyên liệu', project.materialName),
        (
          'Năng suất',
          project.requiredCapacityKgH == null
              ? null
              : '${_num(project.requiredCapacityKgH!)} kg/h',
        ),
        (
          'Độ mịn',
          project.requiredFinenessValue == null
              ? null
              : '${_num(project.requiredFinenessValue!)} ${project.requiredFinenessUnit ?? ''}',
        ),
        (
          'Kích thước đầu vào',
          project.feedSizeMm == null ? null : '${_num(project.feedSizeMm!)} mm',
        ),
        (
          'Động cơ tối đa',
          project.maxMotorKw == null ? null : '${_num(project.maxMotorKw!)} kW',
        ),
        ('Ứng dụng', project.application),
      ],
      y,
      width,
    );
  }

  static double _recommendationsGrid(
    PdfDocument document,
    PdfPage page,
    _ExportFonts fonts,
    List<GrindingMachineMatch> recommendations,
    double y,
    double width,
  ) {
    final grid = PdfGrid();
    grid.columns.add(count: 6);
    grid.columns[0].width = width * 0.24;
    grid.columns[1].width = width * 0.10;
    grid.columns[2].width = width * 0.17;
    grid.columns[3].width = width * 0.16;
    grid.columns[4].width = width * 0.14;
    grid.columns[5].width = width * 0.19;
    grid.style = PdfGridStyle(
      font: fonts.regular(8.2),
      textBrush: PdfSolidBrush(_navy),
      cellPadding: PdfPaddings(left: 6, right: 6, top: 5, bottom: 5),
    );
    final header = grid.headers.add(1)[0];
    header.style
      ..backgroundBrush = PdfSolidBrush(_navy)
      ..textBrush = PdfBrushes.white
      ..font = fonts.bold(7.5);
    const headings = [
      'MODEL / TÊN MÁY',
      'DÒNG MÁY',
      'NĂNG SUẤT',
      'ĐỘ MỊN',
      'ĐỘNG CƠ',
      'MỨC ĐỘ PHÙ HỢP',
    ];
    for (var i = 0; i < headings.length; i++) {
      header.cells[i].value = headings[i];
      header.cells[i].stringFormat = _centeredCellFormat();
    }
    for (final match in recommendations.take(5)) {
      final row = grid.rows.add();
      row.style.backgroundBrush = PdfSolidBrush(
        grid.rows.count.isEven ? _paleBlue : PdfColor(255, 255, 255),
      );
      row.cells[0].value = _machineName(match.machine, match.series);
      row.cells[1].value = match.series?.displayCode ?? '—';
      row.cells[2].value = GrindingFormat.capacityRange(match.machine) ?? '—';
      row.cells[3].value = GrindingFormat.finenessRange(match.machine) ?? '—';
      row.cells[4].value = GrindingFormat.motorRange(match.machine) ?? '—';
      row.cells[5].value = switch (match.label) {
        GrindingMatchLabel.strong => 'Phù hợp cao',
        GrindingMatchLabel.possible => 'Có thể phù hợp',
        GrindingMatchLabel.closest => 'Gần phù hợp',
      };
      for (var column = 0; column < row.cells.count; column++) {
        row.cells[column].stringFormat = _centeredCellFormat();
      }
    }
    final result = grid.draw(
      page: page,
      bounds: ui.Rect.fromLTWH(0, y, width, 500),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );
    return (result?.bounds.bottom ?? y) + 16;
  }

  static double _selectedMachineBlock(
    PdfGraphics g,
    _ExportFonts fonts,
    GrindingMachine? machine,
    GrindingSeries? series,
    double y,
    double width,
  ) {
    if (machine == null) {
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
        ('Model / Tên máy', _machineName(machine, series, separator: ' · ')),
        ('Dòng máy', series?.displayCode),
        ('Năng suất', GrindingFormat.capacityRange(machine)),
        ('Độ mịn', GrindingFormat.finenessRange(machine)),
        ('Động cơ', GrindingFormat.motorRange(machine)),
      ],
      y,
      width,
    );
  }

  static double _comparisonGrid(
    PdfDocument document,
    PdfPage page,
    _ExportFonts fonts,
    List<GrindingMachine> machines,
    Map<String, GrindingSeries> seriesByCode,
    double y,
    double width,
  ) {
    final rows = <(String, List<String?>)>[
      ('Năng suất', machines.map(GrindingFormat.capacityRange).toList()),
      ('Độ mịn', machines.map(GrindingFormat.finenessRange).toList()),
      ('Động cơ', machines.map(GrindingFormat.motorRange).toList()),
      ('Kích thước', machines.map((m) => m.dimensionsDisplay).toList()),
    ];
    final grid = PdfGrid();
    grid.columns.add(count: machines.length + 1);
    grid.columns[0].width = width * 0.25;
    for (var i = 1; i <= machines.length; i++) {
      grid.columns[i].width = (width * 0.75) / machines.length;
    }
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
    header.cells[0].value = 'THÔNG SỐ';
    header.cells[0].stringFormat = _centeredCellFormat();
    for (var i = 0; i < machines.length; i++) {
      header.cells[i + 1].value = _machineName(
        machines[i],
        seriesByCode[machines[i].seriesCode],
      );
      header.cells[i + 1].stringFormat = _centeredCellFormat();
    }
    for (final (label, values) in rows) {
      final row = grid.rows.add();
      row.cells[0].value = label;
      for (var i = 0; i < values.length; i++) {
        row.cells[i + 1].value = values[i] ?? '—';
      }
      for (var column = 0; column < row.cells.count; column++) {
        row.cells[column].stringFormat = _centeredCellFormat();
      }
    }
    final result = grid.draw(
      page: page,
      bounds: ui.Rect.fromLTWH(0, y, width, 300),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );
    return (result?.bounds.bottom ?? y) + 16;
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static String _machineName(
    GrindingMachine machine,
    GrindingSeries? series, {
    String separator = '\n',
  }) {
    final nameVi = series?.nameVi.trim() ?? '';
    return nameVi.isEmpty ? machine.model : '${machine.model}$separator$nameVi';
  }

  static PdfStringFormat _centeredCellFormat() => PdfStringFormat(
    alignment: PdfTextAlignment.center,
    lineAlignment: PdfVerticalAlignment.middle,
  );

  static void _footer(
    PdfPage page,
    _ExportFonts fonts,
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
      'DTCGroup · Báo cáo lựa chọn Máy nghiền',
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

class _ExportFonts {
  final Uint8List regularBytes;
  final Uint8List boldBytes;

  const _ExportFonts(this.regularBytes, this.boldBytes);

  static Future<_ExportFonts> load() async {
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return _ExportFonts(
      Uint8List.sublistView(regular),
      Uint8List.sublistView(bold),
    );
  }

  PdfFont regular(double size) => PdfTrueTypeFont(regularBytes, size);
  PdfFont bold(double size) => PdfTrueTypeFont(boldBytes, size);
}
