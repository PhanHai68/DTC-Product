import 'dart:convert';
import 'dart:ui' as ui;

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../diagram/air_diagram.dart';
import '../diagram/air_diagram_render.dart';
import '../diagram/air_diagram_svg.dart';
import '../l10n/air_strings.dart';
import '../models/air_config.dart';
import '../models/air_result.dart';
import '../pipe/install_kit.dart';
import '../pipe/material_list.dart';
import '../pipe/pipe_engine.dart';
import '../pipe/pipe_strings.dart';
import 'air_po_excel.dart';

/// Một file xuất: tên, kiểu MIME, nội dung.
class AirExportFile {
  const AirExportFile(this.name, this.mimeType, this.bytes);
  final String name;
  final String mimeType;
  final Uint8List bytes;
}

/// Xuất cấu hình: PDF A3 ngang, PNG/SVG sơ đồ, Excel danh mục, JSON cấu hình.
/// Mọi file lấy từ cùng [AirResult] và [AirDiagram] với màn hình.
abstract final class AirConfigExportService {
  static const excelMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static String baseName(AirConfig config, DateTime now) {
    final name = config.project.name.trim().isEmpty
        ? 'CauHinhKhiNen'
        : config.project.name
              .trim()
              .replaceAll(RegExp(r'[^A-Za-z0-9À-ỹ_-]+'), '_')
              .replaceAll(RegExp(r'_+'), '_');
    return 'DTC_${name}_${DateFormat('yyyyMMdd_HHmm').format(now)}';
  }

  static Future<AirExportFile> png(
    AirDiagram diagram,
    String base, {
    double scale = 2,
  }) async => AirExportFile(
    '$base.png',
    'image/png',
    await airDiagramPng(diagram, scale: scale),
  );

  static Future<AirExportFile> svg(AirDiagram diagram, String base) async =>
      AirExportFile(
        '$base.svg',
        'image/svg+xml',
        Uint8List.fromList(
          utf8.encode(
            airDiagramSvg(diagram, images: await AirDiagramImages.bytes()),
          ),
        ),
      );

  static AirExportFile json(AirConfig config, String base) => AirExportFile(
    '$base.json',
    'application/json',
    Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(config.toJson())),
    ),
  );

  /// Danh mục thiết bị: STT, tên, thông số, SL, đơn giá (trống), thành tiền.
  static AirExportFile excel(
    AirConfig config,
    AirResult result,
    AirStrings s,
    String base,
  ) {
    final book = Excel.createExcel();
    final sheetName = s.isEn ? 'Equipment' : 'Danh mục thiết bị';
    book.rename(book.getDefaultSheet()!, sheetName);
    final sheet = book[sheetName];
    final bold = CellStyle(bold: true);
    final header = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1F4E9D'),
      fontColorHex: ExcelColor.white,
      textWrapping: TextWrapping.WrapText,
      verticalAlign: VerticalAlign.Center,
    );
    final wrap = CellStyle(
      textWrapping: TextWrapping.WrapText,
      verticalAlign: VerticalAlign.Top,
    );
    void put(int col, int row, CellValue value, [CellStyle? style]) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      cell.value = value;
      if (style != null) cell.cellStyle = style;
    }

    final title = config.project.name.trim().isEmpty
        ? s.title
        : '${s.title} – ${config.project.name.trim()}';
    put(0, 0, TextCellValue(title), CellStyle(bold: true, fontSize: 14));
    put(
      0,
      1,
      TextCellValue(
        '${s.createdOn}: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
      ),
    );
    const headerRow = 3;
    final headings = [
      s.colNo,
      s.colName,
      s.colSpec,
      s.colQty,
      s.colUnitPrice,
      s.colAmount,
    ];
    for (var c = 0; c < headings.length; c++) {
      put(c, headerRow, TextCellValue(headings[c]), header);
    }
    final items = result.equipment;
    for (var i = 0; i < items.length; i++) {
      final row = headerRow + 1 + i;
      final excelRow = row + 1;
      put(0, row, IntCellValue(i + 1), wrap);
      put(1, row, TextCellValue(s.displayName(items[i], config)), wrap);
      put(2, row, TextCellValue(s.displaySpec(items[i], config)), wrap);
      put(3, row, IntCellValue(items[i].qty), wrap);
      put(5, row, FormulaCellValue('D$excelRow*E$excelRow'), wrap);
    }
    final totalRow = headerRow + 1 + items.length;
    put(1, totalRow, TextCellValue(s.total), bold);
    put(
      5,
      totalRow,
      FormulaCellValue('SUM(F${headerRow + 2}:F$totalRow)'),
      bold,
    );
    for (final (col, width) in [
      (0, 6.0),
      (1, 42.0),
      (2, 70.0),
      (3, 6.0),
      (4, 16.0),
      (5, 18.0),
    ]) {
      sheet.setColumnWidth(col, width);
    }
    final bytes = book.encode()!;
    return AirExportFile('$base.xlsx', excelMime, Uint8List.fromList(bytes));
  }

  // ── Excel đề nghị vật tư (form PO) ───────────────────────────────────────

  /// Phiếu "Đề nghị vật tư" theo form PO: thiết bị chính, vật tư lắp đặt cụm
  /// máy, vật tư từ cụm máy đến thiết bị sử dụng khí nén, rồi van xả đáy bình
  /// và vật tư điện khi đã tick chọn. Luôn tiếng Việt như form.
  static AirExportFile po(
    PoTemplate template,
    AirConfig config,
    AirResult result, {
    required String base,
    PipeResult? pipe,
    InstallKits? kits,
    DateTime? now,
  }) => AirExportFile(
    '${base}_DeNghiVatTu.xlsx',
    excelMime,
    buildPoWorkbook(
      template,
      poDocument(config, result, pipe: pipe, kits: kits, now: now),
    ),
  );

  static PoDocument poDocument(
    AirConfig config,
    AirResult result, {
    PipeResult? pipe,
    InstallKits? kits,
    DateTime? now,
  }) {
    final s = AirStrings(AirLang.vi);
    final kw = result.compressor?.powerKw;
    final kit = kits?.forPowerKw(kw);
    final project = config.project.name.trim();
    final power = kit != null
        ? '${kit.hp}HP'
        : kw == null
        ? ''
        : '${s.n2(kw)} kW';
    String cap(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);

    String? equipmentSpec(EquipmentItem e) {
      final o = config.overrides[e.key]?.spec?.trim();
      if (o != null && o.isNotEmpty) return o;
      return switch (e.kind) {
        EquipmentKind.compressor when kw != null =>
          kit == null ? '${s.n2(kw)} kW' : '${kit.hp}HP – ${s.n0(kw)} kW',
        EquipmentKind.tank =>
          '${s.n2((e.params['tank'] as TankPick).volumeM3)} m³',
        _ => null,
      };
    }

    // Phiếu không ghi điện (có mục vật tư điện riêng), van xả tự động, bộ tách
    // dầu – nước; máy sấy đứng ngay sau máy nén.
    const skipped = {
      EquipmentKind.mccb,
      EquipmentKind.cable,
      EquipmentKind.autoDrain,
      EquipmentKind.oilWaterSeparator,
    };
    int rank(EquipmentItem e) => switch (e.kind) {
      EquipmentKind.compressor => 0,
      EquipmentKind.desiccantDryer || EquipmentKind.refrigeratedDryer => 1,
      _ => 2,
    };
    final picked = [
      for (final e in result.equipment)
        if (!skipped.contains(e.kind)) e,
    ];
    // Sắp xếp ổn định: giữ thứ tự gốc trong cùng hạng.
    final ordered = [
      for (var r = 0; r <= 2; r++)
        for (final e in picked)
          if (rank(e) == r) e,
    ];
    // Lọc ghi "Bộ lọc …", bỏ phần nhóm sấy ("– nhóm sấy lạnh"…); tên sửa tay
    // giữ nguyên.
    String equipmentName(EquipmentItem e) {
      final o = config.overrides[e.key]?.name?.trim();
      if (o != null && o.isNotEmpty) return o;
      final filter = switch (e.kind) {
        EquipmentKind.waterSeparator => s.waterSeparator,
        EquipmentKind.coarseFilter => s.coarseFilter,
        EquipmentKind.fineFilter => s.fineFilter,
        EquipmentKind.carbonFilter => s.carbon,
        EquipmentKind.sterileFilter => s.sterile,
        _ => null,
      };
      return filter == null
          ? s.equipmentName(e)
          : 'Bộ ${filter[0].toLowerCase()}${filter.substring(1)}';
    }

    // Cùng tên và quy cách (vd lọc tách thô của hai nhóm sấy): gộp, cộng
    // số lượng.
    final equipment = <PoLine>[];
    for (final e in ordered) {
      final line = PoLine(
        name: equipmentName(e),
        unit: switch (e.kind) {
          EquipmentKind.compressor ||
          EquipmentKind.desiccantDryer ||
          EquipmentKind.refrigeratedDryer => 'Máy',
          EquipmentKind.tank || EquipmentKind.extra => 'Bộ',
          _ => 'Cái',
        },
        qty: e.qty,
        spec: equipmentSpec(e),
      );
      final k = equipment.indexWhere(
        (l) =>
            l.name == line.name && l.spec == line.spec && l.unit == line.unit,
      );
      if (k < 0) {
        equipment.add(line);
      } else {
        final old = equipment[k];
        equipment[k] = PoLine(
          name: old.name,
          unit: old.unit,
          qty: old.qty! + line.qty!,
          spec: old.spec,
        );
      }
    }

    // Danh sách đã áp phần sửa tay (thêm / xoá / sửa) như trên app.
    List<PoLine> lines(MaterialList list) => [
      for (final r in buildMaterialRows(list, config, kit: kit, pipe: pipe))
        PoLine(
          code: r.code,
          name: r.name,
          unit: cap(r.unit),
          qty: r.qty,
          spec: r.spec,
          note: r.note,
        ),
    ];
    final kitLines = lines(MaterialList.kit);
    final pipeLines = lines(MaterialList.pipe);

    // Mục van xả / điện: ghi chú chung gộp dọc cột quy cách, trừ khi có dòng
    // đã ghi quy cách (sửa tay) thì bỏ ghi chú chung để không che mất.
    PoSection? optional(
      InstallKitSection section,
      MaterialList list,
      PoBand band,
    ) {
      final rows = lines(list);
      if (rows.isEmpty) return null;
      return PoSection(
        title: section.title,
        band: band,
        lines: rows,
        note: rows.any((l) => l.spec?.isNotEmpty ?? false)
            ? null
            : section.note,
      );
    }

    final sections = [
      if (kitLines.isNotEmpty)
        PoSection(
          title: kit?.standard.title ?? 'VẬT TƯ LẮP ĐẶT CỤM MÁY',
          band: PoBand.blue,
          lines: kitLines,
        )
      else if (kit == null)
        PoSection(
          title: 'VẬT TƯ LẮP ĐẶT CỤM MÁY',
          band: PoBand.blue,
          numbered: false,
          lines: [
            PoLine(
              name:
                  '${s.kitNotUpdated}. ${s.kitNotUpdatedDetail(kw, [for (final k in kits?.kits ?? const <InstallKit>[]) k.hp])}',
            ),
          ],
        ),
      if (pipe != null)
        PoSection(
          title: 'VẬT TƯ TỪ CỤM MÁY ĐẾN THIẾT BỊ SỬ DỤNG KHÍ NÉN',
          band: PoBand.blue,
          numbered: pipeLines.isNotEmpty,
          lines: pipeLines.isEmpty
              ? [for (final w in pipe.warnings) PoLine(name: s.pipeWarning(w))]
              : pipeLines,
        ),
      if (kit != null && config.pipe.drainKit)
        ?optional(kit.drain, MaterialList.drain, PoBand.green),
      if (kit != null && config.pipe.electricKit)
        ?optional(kit.electric, MaterialList.electric, PoBand.yellow),
    ];

    return PoDocument(
      projectTitle: [
        'Vật tư lắp đặt hệ máy nén khí${power.isEmpty ? '' : ' $power'}',
        if (project.isNotEmpty) project,
      ].join(' – '),
      date: DateFormat('dd/MM/yyyy').format(now ?? DateTime.now()),
      equipment: equipment,
      sections: sections,
    );
  }

  // ── PDF ──────────────────────────────────────────────────────────────────
  // Cùng kiểu với file PDF máy tách màu (DtcPdfExportService): thanh xanh lá
  // mảnh đầu trang, logo, tiêu đề chữ đậm căn giữa (không nền), chân trang.

  static final _navy = PdfColor(10, 39, 64);
  static final _green = PdfColor(20, 129, 71);
  static final _paleGreen = PdfColor(234, 247, 241);
  static final _muted = PdfColor(96, 119, 134);
  static final _border = PdfColor(220, 231, 235);

  /// Một file PDF A3 ngang: trang 1 sơ đồ lắp đặt, trang 2 mặt bằng phòng
  /// lắp đặt (khi có [room]).
  static Future<AirExportFile> pdf(
    AirConfig config,
    AirStrings s,
    AirDiagram diagram,
    String base, {
    AirDiagram? room,
    String? roomHeading,
  }) async => AirExportFile(
    '$base.pdf',
    'application/pdf',
    await _drawingsPdf(config, s.createdOn, [
      (diagram, s.diagramTitle),
      if (room != null) (room, roomHeading ?? ''),
    ]),
  );

  /// Mỗi bản vẽ một trang A3 ngang: đầu trang (logo, tiêu đề căn giữa, tên
  /// dự án, ngày lập), bản vẽ căn giữa giữ tỉ lệ, chân trang.
  static Future<Uint8List> _drawingsPdf(
    AirConfig config,
    String createdOn,
    List<(AirDiagram, String)> pages,
  ) async {
    final regular = Uint8List.sublistView(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final boldBytes = Uint8List.sublistView(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    PdfFont font(double size) => PdfTrueTypeFont(regular, size);
    PdfFont bold(double size) => PdfTrueTypeFont(boldBytes, size);
    final logo = Uint8List.sublistView(
      await rootBundle.load('assets/images/DTCGroup-Slogan.png'),
    );
    final name = config.project.name.trim();
    final date = DateFormat('dd/MM/yyyy').format(DateTime.now());

    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a3
      ..orientation = PdfPageOrientation.landscape
      ..margins.all = 0;
    for (final (drawing, heading) in pages) {
      final png = await airDiagramPng(drawing, scale: 3);
      final page = document.pages.add();
      final g = page.graphics;
      final size = page.getClientSize();
      const margin = 28.0;
      final width = size.width - 2 * margin;
      final center = PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.middle,
      );

      // Thanh xanh lá mảnh đầu trang, logo bên trái (tỉ lệ 2048 × 713).
      g.drawRectangle(
        brush: PdfSolidBrush(_green),
        bounds: ui.Rect.fromLTWH(0, 0, size.width, 7),
      );
      const logoH = 44.0;
      g.drawImage(
        PdfBitmap(logo),
        ui.Rect.fromLTWH(margin, 16, logoH * 2048 / 713, logoH),
      );
      // Tiêu đề chữ đậm căn giữa trang (không nền), tên dự án bên dưới.
      g.drawString(
        heading.toUpperCase(),
        bold(20),
        brush: PdfSolidBrush(_navy),
        bounds: ui.Rect.fromLTWH(margin, 14, width, 28),
        format: center,
      );
      if (name.isNotEmpty) {
        g.drawString(
          name,
          font(12),
          brush: PdfSolidBrush(_muted),
          bounds: ui.Rect.fromLTWH(margin, 42, width, 18),
          format: center,
        );
      }
      g.drawString(
        '$createdOn: $date',
        font(11),
        brush: PdfSolidBrush(_muted),
        bounds: ui.Rect.fromLTWH(margin, 20, width, 18),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.right,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );
      g.drawLine(
        PdfPen(_border, width: 0.7),
        ui.Offset(margin, 70),
        ui.Offset(size.width - margin, 70),
      );

      // Chân trang.
      const footerH = 22.0;
      final footer = ui.Rect.fromLTWH(
        margin,
        size.height - margin / 2 - footerH,
        width,
        footerH,
      );
      g.drawRectangle(
        brush: PdfSolidBrush(_paleGreen),
        pen: PdfPen(PdfColor(211, 235, 223), width: 0.6),
        bounds: footer,
      );
      g.drawRectangle(
        brush: PdfSolidBrush(_green),
        bounds: ui.Rect.fromLTWH(footer.left, footer.top, 3.5, footer.height),
      );
      final inner = ui.Rect.fromLTWH(
        footer.left + 12,
        footer.top,
        footer.width - 24,
        footer.height,
      );
      g.drawString(
        'DTC Group · DTC Product',
        bold(9),
        brush: PdfSolidBrush(_green),
        bounds: inner,
        format: PdfStringFormat(lineAlignment: PdfVerticalAlignment.middle),
      );
      g.drawString(
        '$heading · ${document.pages.count}/${pages.length}',
        font(9),
        brush: PdfSolidBrush(_muted),
        bounds: inner,
        format: PdfStringFormat(
          alignment: PdfTextAlignment.right,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );

      // Bản vẽ căn giữa vùng còn lại, giữ tỉ lệ.
      const top = 82.0;
      final availH = footer.top - 10 - top;
      final scale = [
        width / drawing.width,
        availH / drawing.height,
      ].reduce((a, b) => a < b ? a : b);
      final w = drawing.width * scale;
      final h = drawing.height * scale;
      g.drawImage(
        PdfBitmap(png),
        ui.Rect.fromLTWH(
          margin + (width - w) / 2,
          top + (availH - h) / 2,
          w,
          h,
        ),
      );
    }
    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }
}
