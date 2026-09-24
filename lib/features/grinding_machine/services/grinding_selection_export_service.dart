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
  static final _cyan = PdfColor(11, 145, 168);
  static final _muted = PdfColor(96, 119, 134);
  static final _border = PdfColor(211, 225, 229);

  static Future<Uint8List> buildPdf({
    required GrindingSelectionProject project,
    List<GrindingMachineMatch> recommendations = const [],
    GrindingMachine? selectedMachine,
    GrindingSeries? selectedSeries,
    List<GrindingMachine> comparisonMachines = const [],
  }) async {
    final fonts = await _ExportFonts.load();
    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a4
      ..margins.all = 36;

    final page = document.pages.add();
    final size = page.getClientSize();
    final contentWidth = size.width;
    var y = 0.0;

    y = _header(page.graphics, fonts, contentWidth);
    y = _projectSection(page.graphics, fonts, project, y, contentWidth);
    y = _requirementSection(page.graphics, fonts, project, y, contentWidth);

    if (recommendations.isNotEmpty) {
      y = _sectionTitle(page.graphics, fonts, 'RECOMMENDED MACHINES', y, contentWidth);
      y = _recommendationsGrid(document, page, fonts, recommendations, y, contentWidth);
    }

    y = _sectionTitle(page.graphics, fonts, 'SELECTED MACHINE', y, contentWidth);
    y = _selectedMachineBlock(page.graphics, fonts, selectedMachine, selectedSeries, y, contentWidth);

    if (comparisonMachines.length >= 2) {
      y = _sectionTitle(page.graphics, fonts, 'COMPARISON', y, contentWidth);
      y = _comparisonGrid(document, page, fonts, comparisonMachines, y, contentWidth);
    }

    if (project.notes != null && project.notes!.isNotEmpty) {
      y = _sectionTitle(page.graphics, fonts, 'NOTES', y, contentWidth);
      page.graphics.drawString(
        project.notes!,
        fonts.regular(10),
        bounds: ui.Rect.fromLTWH(0, y, contentWidth, 60),
        brush: PdfSolidBrush(_navy),
      );
    }

    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  static double _header(PdfGraphics g, _ExportFonts fonts, double width) {
    g.drawString(
      'DTC Product',
      fonts.bold(20),
      bounds: ui.Rect.fromLTWH(0, 0, width, 26),
      brush: PdfSolidBrush(_navy),
    );
    g.drawString(
      'Grinding Machine Selection Report',
      fonts.regular(13),
      bounds: ui.Rect.fromLTWH(0, 26, width, 20),
      brush: PdfSolidBrush(_cyan),
    );
    g.drawLine(
      PdfPen(_border, width: 1),
      ui.Offset(0, 54),
      ui.Offset(width, 54),
    );
    return 66;
  }

  static double _sectionTitle(
    PdfGraphics g,
    _ExportFonts fonts,
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
    y = _sectionTitle(g, fonts, 'PROJECT', y, width);
    return _keyValueRows(g, fonts, [
      ('Project name', project.projectName),
      ('Customer', project.customerName),
      ('Date', DateFormat('yyyy-MM-dd HH:mm').format(project.updatedAt)),
    ], y, width);
  }

  static double _requirementSection(
    PdfGraphics g,
    _ExportFonts fonts,
    GrindingSelectionProject project,
    double y,
    double width,
  ) {
    y = _sectionTitle(g, fonts, 'CUSTOMER REQUIREMENTS', y, width);
    return _keyValueRows(g, fonts, [
      ('Material', project.materialName),
      (
        'Capacity',
        project.requiredCapacityKgH == null
            ? null
            : '${_num(project.requiredCapacityKgH!)} kg/h',
      ),
      (
        'Fineness',
        project.requiredFinenessValue == null
            ? null
            : '${_num(project.requiredFinenessValue!)} ${project.requiredFinenessUnit ?? ''}',
      ),
      (
        'Feed size',
        project.feedSizeMm == null ? null : '${_num(project.feedSizeMm!)} mm',
      ),
      (
        'Max motor',
        project.maxMotorKw == null ? null : '${_num(project.maxMotorKw!)} kW',
      ),
      ('Application', project.application),
    ], y, width);
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
    for (var i = 0; i < 6; i++) {
      grid.columns[i].width = width / 6;
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
    const headings = ['Model', 'Series', 'Capacity', 'Fineness', 'Motor', 'Match status'];
    for (var i = 0; i < headings.length; i++) {
      header.cells[i].value = headings[i];
    }
    for (final match in recommendations.take(5)) {
      final row = grid.rows.add();
      row.cells[0].value = match.machine.model;
      row.cells[1].value = match.series?.displayCode ?? '—';
      row.cells[2].value = GrindingFormat.capacityRange(match.machine) ?? '—';
      row.cells[3].value = GrindingFormat.finenessRange(match.machine) ?? '—';
      row.cells[4].value = GrindingFormat.motorRange(match.machine) ?? '—';
      row.cells[5].value = switch (match.label) {
        GrindingMatchLabel.strong => 'Strong Match',
        GrindingMatchLabel.possible => 'Possible Match',
        GrindingMatchLabel.closest => 'Insufficient Data',
      };
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
        'No machine selected',
        fonts.regular(10),
        bounds: ui.Rect.fromLTWH(0, y, width, 16),
        brush: PdfSolidBrush(_muted),
      );
      return y + 26;
    }
    return _keyValueRows(g, fonts, [
      ('Model', machine.model),
      ('Series', series?.displayCode),
      ('Capacity', GrindingFormat.capacityRange(machine)),
      ('Fineness', GrindingFormat.finenessRange(machine)),
      ('Motor', GrindingFormat.motorRange(machine)),
    ], y, width);
  }

  static double _comparisonGrid(
    PdfDocument document,
    PdfPage page,
    _ExportFonts fonts,
    List<GrindingMachine> machines,
    double y,
    double width,
  ) {
    final rows = <(String, List<String?>)>[
      ('Capacity', machines.map(GrindingFormat.capacityRange).toList()),
      ('Fineness', machines.map(GrindingFormat.finenessRange).toList()),
      ('Motor', machines.map(GrindingFormat.motorRange).toList()),
      (
        'Dimensions',
        machines.map((m) => m.dimensionsDisplay).toList(),
      ),
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
    header.cells[0].value = 'Specification';
    for (var i = 0; i < machines.length; i++) {
      header.cells[i + 1].value = machines[i].model;
    }
    for (final (label, values) in rows) {
      final row = grid.rows.add();
      row.cells[0].value = label;
      for (var i = 0; i < values.length; i++) {
        row.cells[i + 1].value = values[i] ?? '—';
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
