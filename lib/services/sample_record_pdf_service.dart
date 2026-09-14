import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/sample_record.dart';

abstract final class SampleRecordPdfService {
  static final _navy = PdfColor(10, 39, 64);
  static final _green = PdfColor(20, 129, 71);
  static final _muted = PdfColor(96, 119, 134);
  static final _border = PdfColor(211, 225, 229);
  static final _paleGreen = PdfColor(235, 247, 241);
  static final _paleBlue = PdfColor(243, 247, 249);

  static Future<Uint8List> build({
    required SampleRecordData record,
    required Map<SampleStreamType, Uint8List> photos,
    Map<SampleStreamType, List<Uint8List?>> categoryPhotos = const {},
    bool isDraft = false,
  }) async {
    final fonts = await _SamplePdfFonts.load();
    final logoData = await rootBundle.load('assets/images/DTCGroup-Slogan.png');
    final verifiedData = await rootBundle.load(
      'assets/images/verified_dtc_product_ink.png',
    );
    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a4
      ..margins.all = 0;

    final totalPages = record.streams.length + 1;
    _drawOverviewPage(
      document.pages.add(),
      record,
      photos,
      Uint8List.sublistView(logoData),
      Uint8List.sublistView(verifiedData),
      fonts,
      totalPages,
      isDraft,
    );
    _drawAnalysisPages(
      document,
      record,
      categoryPhotos,
      Uint8List.sublistView(verifiedData),
      fonts,
      totalPages,
      isDraft,
    );

    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  static void _drawOverviewPage(
    PdfPage page,
    SampleRecordData record,
    Map<SampleStreamType, Uint8List> photos,
    Uint8List logo,
    Uint8List verifiedLogo,
    _SamplePdfFonts fonts,
    int totalPages,
    bool isDraft,
  ) {
    final graphics = page.graphics;
    final size = page.getClientSize();
    const margin = 28.0;
    final contentWidth = size.width - margin * 2;
    graphics.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(0, 0, size.width, 7),
    );
    _drawImageContain(
      graphics,
      PdfBitmap(logo),
      ui.Rect.fromLTWH(margin, 18, 145, 43),
      2048 / 713,
    );
    _text(
      graphics,
      'FORM LƯU MẪU',
      fonts.bold(15.5),
      ui.Rect.fromLTWH(190, 22, size.width - 218, 24),
      color: _navy,
      align: PdfTextAlignment.right,
    );
    _text(
      graphics,
      'COMMISSIONING SAMPLE',
      fonts.regular(8.5),
      ui.Rect.fromLTWH(190, 47, size.width - 218, 14),
      color: _muted,
      align: PdfTextAlignment.right,
    );
    graphics.drawLine(
      PdfPen(_border, width: 0.8),
      const ui.Offset(margin, 70),
      ui.Offset(size.width - margin, 70),
    );

    _sectionTitle(
      graphics,
      fonts,
      'THÔNG TIN CHUNG / GENERAL INFORMATION',
      82,
      margin,
      contentWidth,
    );
    final date = DateFormat('dd/MM/yyyy HH:mm:ss').format(record.createdAt);
    final generalRows = [
      ('Tên nhà máy / Factory', record.factoryName, 'Tagname', record.tagName),
      (
        'Người chạy máy / Operator',
        record.machineOperator,
        'Ngày lập / Date',
        date,
      ),
      (
        'Người lập mẫu / Prepared by',
        record.preparedBy,
        'Nguyên liệu / Material',
        record.materialName,
      ),
    ];
    _drawFourColumnTable(
      graphics,
      fonts,
      generalRows,
      margin,
      105,
      contentWidth,
      69,
    );

    _sectionTitle(
      graphics,
      fonts,
      'HÌNH ẢNH & KẾT QUẢ / PHOTOS & RESULTS',
      188,
      margin,
      contentWidth,
    );
    const gap = 8.0;
    final cardWidth = (contentWidth - gap * 2) / 3;
    for (var i = 0; i < record.streams.length && i < 3; i++) {
      final stream = record.streams[i];
      final x = margin + i * (cardWidth + gap);
      _drawStreamCard(
        graphics,
        fonts,
        stream,
        record,
        photos[stream.type],
        ui.Rect.fromLTWH(x, 211, cardWidth, 264),
      );
    }

    _sectionTitle(
      graphics,
      fonts,
      'TỔNG HỢP / SUMMARY',
      490,
      margin,
      contentWidth,
    );
    _drawSummaryTable(page, fonts, record.streams, margin, 513, contentWidth);

    _sectionTitle(
      graphics,
      fonts,
      'KẾT LUẬN / CONCLUSION',
      642,
      margin,
      contentWidth,
    );
    graphics.drawRectangle(
      brush: PdfSolidBrush(_paleGreen),
      pen: PdfPen(_border, width: 0.7),
      bounds: ui.Rect.fromLTWH(margin, 666, contentWidth, 135),
    );
    _text(
      graphics,
      'Nội dung kỹ sư / Engineer statement',
      fonts.bold(7.5),
      ui.Rect.fromLTWH(margin + 16, 674, contentWidth - 140, 15),
      color: _muted,
    );
    _text(
      graphics,
      record.conclusion.trim().isEmpty ? '—' : record.conclusion,
      fonts.bold(10.5),
      ui.Rect.fromLTWH(margin + 16, 692, contentWidth - 145, 43),
      color: _navy,
    );
    _text(
      graphics,
      record.note.trim().isEmpty
          ? 'Không có ghi chú / No additional notes'
          : 'Ghi chú / Notes: ${record.note}',
      fonts.regular(8),
      ui.Rect.fromLTWH(margin + 16, 746, contentWidth - 145, 27),
      color: _muted,
    );
    final stampBounds = ui.Rect.fromLTWH(
      size.width - margin - 80,
      720,
      60,
      60,
    );
    _drawVerifiedStamp(graphics, verifiedLogo, stampBounds);
    _footer(graphics, fonts, size, 1, totalPages);
    if (isDraft) _drawWatermark(graphics, fonts, size);
  }

  static void _drawAnalysisPages(
    PdfDocument document,
    SampleRecordData record,
    Map<SampleStreamType, List<Uint8List?>> categoryPhotos,
    Uint8List verifiedLogo,
    _SamplePdfFonts fonts,
    int totalPages,
    bool isDraft,
  ) {
    const margin = 28.0;
    
    for (var i = 0; i < record.streams.length; i++) {
      final stream = record.streams[i];
      final page = document.pages.add();
      final graphics = page.graphics;
      final size = page.getClientSize();
      final width = size.width - margin * 2;
      
      graphics.drawRectangle(
        brush: PdfSolidBrush(_green),
        bounds: ui.Rect.fromLTWH(0, 0, size.width, 7),
      );
      _text(
        graphics,
        'PHÂN TÍCH CHI TIẾT - ${stream.type.title.toUpperCase()}',
        fonts.bold(17),
        ui.Rect.fromLTWH(margin, 25, width, 24),
        color: _navy,
      );
      _text(
        graphics,
        '${record.tagName}  •  ${record.factoryName}',
        fonts.regular(9),
        ui.Rect.fromLTWH(margin, 52, width, 16),
        color: _muted,
      );

      _drawDetailedStream(
        graphics,
        fonts,
        stream,
        record,
        categoryPhotos[stream.type] ?? const [],
        margin,
        76.0,
        width,
      );

      final stampBounds = ui.Rect.fromLTWH(
        size.width - margin - 80,
        size.height - margin - 80,
        60,
        60,
      );
      _drawVerifiedStamp(graphics, verifiedLogo, stampBounds);

      _footer(graphics, fonts, size, i + 2, totalPages);
      if (isDraft) _drawWatermark(graphics, fonts, size);
    }
  }

  static void _drawStreamCard(
    PdfGraphics graphics,
    _SamplePdfFonts fonts,
    SampleStreamData stream,
    SampleRecordData record,
    Uint8List? photo,
    ui.Rect rect,
  ) {
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      pen: PdfPen(_border, width: 0.8),
      bounds: rect,
    );
    graphics.drawRectangle(
      brush: PdfSolidBrush(_paleGreen),
      bounds: ui.Rect.fromLTWH(rect.left, rect.top, rect.width, 27),
    );
    _text(
      graphics,
      '${stream.type.title}\n${stream.type.englishTitle}',
      fonts.bold(8.5),
      ui.Rect.fromLTWH(rect.left + 7, rect.top + 4, rect.width - 14, 21),
      color: _navy,
      align: PdfTextAlignment.center,
    );
    if (photo != null && photo.isNotEmpty) {
      final bitmap = PdfBitmap(photo);
      _drawImageContain(
        graphics,
        bitmap,
        ui.Rect.fromLTWH(rect.left + 7, rect.top + 34, rect.width - 14, 167),
        bitmap.width / bitmap.height,
      );
    }
    final labels = [
      'Năng suất / Capacity',
      'Hạt tốt / Good',
      'Hạt lỗi / Defect',
    ];
    final capacity = _getAdjustedCapacity(stream, record);
    final values = [
      '${capacity.toStringAsFixed(1)} t/h',
      '${stream.goodPercentage.toStringAsFixed(1)}%',
      '${stream.defectPercentage.toStringAsFixed(1)}%',
    ];
    for (var i = 0; i < 3; i++) {
      final y = rect.top + 208 + i * 16;
      _text(
        graphics,
        labels[i],
        fonts.regular(7.3),
        ui.Rect.fromLTWH(rect.left + 8, y, rect.width * 0.62, 13),
        color: _muted,
      );
      _text(
        graphics,
        values[i],
        fonts.bold(8),
        ui.Rect.fromLTWH(
          rect.left + rect.width * 0.56,
          y,
          rect.width * 0.38 - 8,
          13,
        ),
        color: i == 2 ? _green : _navy,
        align: PdfTextAlignment.right,
      );
    }
  }

  static void _drawSummaryTable(
    PdfPage page,
    _SamplePdfFonts fonts,
    List<SampleStreamData> streams,
    double x,
    double y,
    double width,
  ) {
    final grid = PdfGrid();
    grid.columns.add(count: 5);
    grid.headers.add(1);
    grid.headers[0].cells[0].value = 'Dòng mẫu / Stream';
    grid.headers[0].cells[1].value = 'Khối lượng / Weight';
    grid.headers[0].cells[2].value = 'Thời gian / Time';
    grid.headers[0].cells[3].value = 'Năng suất / Capacity';
    grid.headers[0].cells[4].value = 'Mẫu tốt / Good';
    for (final stream in streams) {
      final row = grid.rows.add();
      final capacity = _getAdjustedCapacity(stream, streams);
      row.cells[0].value = stream.type.title;
      row.cells[1].value = '${stream.measuredWeightKg.toStringAsFixed(1)} kg';
      row.cells[2].value = '${stream.minutes}p ${stream.seconds}g';
      row.cells[3].value =
          '${capacity.toStringAsFixed(1)} t/h';
      row.cells[4].value = '${stream.goodPercentage.toStringAsFixed(1)}%';
    }
    grid.style = PdfGridStyle(
      font: fonts.regular(8),
      cellPadding: PdfPaddings(left: 6, right: 6, top: 6, bottom: 6),
    );
    grid.headers[0].style = PdfGridRowStyle(
      backgroundBrush: PdfSolidBrush(_navy),
      textBrush: PdfSolidBrush(PdfColor(255, 255, 255)),
      font: fonts.bold(8),
    );
    for (var column = 0; column < grid.headers[0].cells.count; column++) {
      grid.headers[0].cells[column].stringFormat = PdfStringFormat(
        alignment: column == 0
            ? PdfTextAlignment.left
            : PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.middle,
      );
    }
    for (var index = 0; index < grid.rows.count; index++) {
      final row = grid.rows[index];
      row.style = PdfGridRowStyle(
        backgroundBrush: PdfSolidBrush(_paleBlue),
        textBrush: PdfSolidBrush(_navy),
      );
      for (var column = 0; column < row.cells.count; column++) {
        row.cells[column].stringFormat = PdfStringFormat(
          alignment: column == 0
              ? PdfTextAlignment.left
              : PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        );
      }
    }
    grid.draw(page: page, bounds: ui.Rect.fromLTWH(x, y, width, 0));
  }

  static void _drawDetailedStream(
    PdfGraphics graphics,
    _SamplePdfFonts fonts,
    SampleStreamData stream,
    SampleRecordData record,
    List<Uint8List?> categoryPhotos,
    double x,
    double y,
    double width,
  ) {
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      pen: PdfPen(_border, width: 0.8),
      bounds: ui.Rect.fromLTWH(x, y, width, 500),
    );
    graphics.drawRectangle(
      brush: PdfSolidBrush(_paleGreen),
      bounds: ui.Rect.fromLTWH(x, y, width, 30),
    );
    _text(
      graphics,
      '${stream.type.title.toUpperCase()} / ${stream.type.englishTitle.toUpperCase()}',
      fonts.bold(12),
      ui.Rect.fromLTWH(x + 10, y + 5, width - 20, 20),
      color: _green,
    );
    
    final informationWidth = width * .40;
    final capacity = _getAdjustedCapacity(stream, record);
    _text(
      graphics,
      'Năng suất / Capacity: ${capacity.toStringAsFixed(1)} t/h',
      fonts.bold(9),
      ui.Rect.fromLTWH(x + 10, y + 42, informationWidth - 14, 16),
      color: _navy,
    );
    _text(
      graphics,
      'Tổng mẫu / Total sample: ${stream.sampleWeightGram.toStringAsFixed(1)} g',
      fonts.regular(9),
      ui.Rect.fromLTWH(x + 10, y + 60, informationWidth - 14, 16),
      color: _muted,
    );
    
    const headerYGap = 86.0;
    final colWidths = [width * .42, width * .19, width * .19, width * .20];
    final headers = [
      'Loại / Category',
      'Khối lượng / Weight',
      'Tỷ lệ / Rate',
      'Kết quả / Result',
    ];
    var left = x;
    for (var i = 0; i < headers.length; i++) {
      graphics.drawRectangle(
        brush: PdfSolidBrush(_navy),
        bounds: ui.Rect.fromLTWH(left, y + headerYGap, colWidths[i], 20),
      );
      _text(
        graphics,
        headers[i],
        fonts.bold(8),
        ui.Rect.fromLTWH(left + 5, y + headerYGap + 3, colWidths[i] - 10, 14),
        color: PdfColor(255, 255, 255),
        align: i == 0 ? PdfTextAlignment.left : PdfTextAlignment.center,
      );
      left += colWidths[i];
    }
    final effective = stream.effectiveItems;
    for (var row = 0; row < effective.length && row < 4; row++) {
      final rowY = y + headerYGap + 20 + row * 18;
      final item = effective[row];
      final weight = item.weightGram;
      final percentage = stream.sampleWeightGram <= 0
          ? 0.0
          : weight / stream.sampleWeightGram * 100;
      final displayLabel = item.name;
      final values = [
        displayLabel,
        '${weight.toStringAsFixed(1)} g',
        '${percentage.toStringAsFixed(1)}%',
        percentage == 0 ? '—' : 'Ghi nhận',
      ];
      left = x;
      for (var col = 0; col < values.length; col++) {
        graphics.drawRectangle(
          brush: PdfSolidBrush(
            row.isEven ? _paleBlue : PdfColor(255, 255, 255),
          ),
          pen: PdfPen(_border, width: 0.35),
          bounds: ui.Rect.fromLTWH(left, rowY, colWidths[col], 18),
        );
        _text(
          graphics,
          values[col],
          fonts.regular(8),
          ui.Rect.fromLTWH(left + 5, rowY + 2, colWidths[col] - 10, 14),
          color: _navy,
          align: col == 0 ? PdfTextAlignment.left : PdfTextAlignment.center,
        );
        left += colWidths[col];
      }
    }
    const resultY = 186.0;
    final resultWidth = width / 2;
    final resultValues = [
      'Tổng hạt lỗi / Total defects: ${stream.defectPercentage.toStringAsFixed(1)}%',
      'Hạt tốt / Good grain: ${stream.goodPercentage.toStringAsFixed(1)}%',
    ];
    for (var column = 0; column < resultValues.length; column++) {
      final left = x + column * resultWidth;
      graphics.drawRectangle(
        brush: PdfSolidBrush(_paleGreen),
        pen: PdfPen(_border, width: 0.4),
        bounds: ui.Rect.fromLTWH(left, y + resultY, resultWidth, 30),
      );
      _text(
        graphics,
        resultValues[column],
        fonts.bold(9),
        ui.Rect.fromLTWH(left + 5, y + resultY + 5, resultWidth - 10, 20),
        color: _green,
        align: PdfTextAlignment.center,
      );
    }
    
    _drawCategoryThumbnails(
      graphics,
      fonts,
      stream,
      categoryPhotos,
      ui.Rect.fromLTWH(
        x + 10,
        y + 226,
        width - 20,
        264,
      ),
    );
  }

  static void _drawCategoryThumbnails(
    PdfGraphics graphics,
    _SamplePdfFonts fonts,
    SampleStreamData stream,
    List<Uint8List?> photos,
    ui.Rect bounds,
  ) {
    final effective = stream.effectiveItems;
    final count = effective.isEmpty ? 1 : effective.length.clamp(1, 4);
    const gap = 8.0;
    final cardWidth = (bounds.width - gap * (count - 1)) / count;
    for (var index = 0; index < count; index++) {
      final left = bounds.left + index * (cardWidth + gap);
      final label = index < effective.length ? effective[index].name.trim() : '';
      graphics.drawRectangle(
        brush: PdfSolidBrush(_paleBlue),
        pen: PdfPen(_border, width: .4),
        bounds: ui.Rect.fromLTWH(left, bounds.top, cardWidth, bounds.height),
      );
      _text(
        graphics,
        label.isEmpty ? 'Không sử dụng' : label,
        fonts.bold(9),
        ui.Rect.fromLTWH(left + 2, bounds.top + 4, cardWidth - 4, 16),
        color: label.isEmpty ? _muted : _navy,
        align: PdfTextAlignment.center,
      );
      final photo = index < photos.length ? photos[index] : null;
      final imageBounds = ui.Rect.fromLTWH(
        left + 2,
        bounds.top + 24,
        cardWidth - 4,
        bounds.height - 28,
      );
      if (photo != null && photo.isNotEmpty) {
        final bitmap = PdfBitmap(photo);
        _drawImageContain(
          graphics,
          bitmap,
          imageBounds,
          bitmap.width / bitmap.height,
        );
      } else {
        _text(
          graphics,
          'Chưa có ảnh',
          fonts.regular(8),
          imageBounds,
          color: _muted,
          align: PdfTextAlignment.center,
        );
      }
    }
  }

  static void _drawFourColumnTable(
    PdfGraphics graphics,
    _SamplePdfFonts fonts,
    List<(String, String, String, String)> rows,
    double x,
    double y,
    double width,
    double height,
  ) {
    final labelWidth = width * .19;
    final valueWidth = width * .31;
    final rowHeight = height / rows.length;
    for (var row = 0; row < rows.length; row++) {
      final values = [rows[row].$1, rows[row].$2, rows[row].$3, rows[row].$4];
      final widths = [labelWidth, valueWidth, labelWidth, valueWidth];
      var left = x;
      for (var col = 0; col < 4; col++) {
        graphics.drawRectangle(
          brush: PdfSolidBrush(
            col.isEven ? _paleBlue : PdfColor(255, 255, 255),
          ),
          pen: PdfPen(_border, width: 0.4),
          bounds: ui.Rect.fromLTWH(
            left,
            y + row * rowHeight,
            widths[col],
            rowHeight,
          ),
        );
        _text(
          graphics,
          values[col],
          col.isEven ? fonts.bold(7.2) : fonts.regular(8),
          ui.Rect.fromLTWH(
            left + 6,
            y + row * rowHeight + 7,
            widths[col] - 12,
            rowHeight - 8,
          ),
          color: col.isEven ? _muted : _navy,
        );
        left += widths[col];
      }
    }
  }

  static void _sectionTitle(
    PdfGraphics graphics,
    _SamplePdfFonts fonts,
    String title,
    double y,
    double x,
    double width,
  ) {
    graphics.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(x, y, 4, 18),
    );
    _text(
      graphics,
      title,
      fonts.bold(10),
      ui.Rect.fromLTWH(x + 10, y + 2, width - 10, 16),
      color: _navy,
    );
  }

  static void _drawVerifiedStamp(
    PdfGraphics graphics,
    Uint8List imageBytes,
    ui.Rect bounds,
  ) {
    final bitmap = PdfBitmap(imageBytes);
    _drawImageContain(graphics, bitmap, bounds, bitmap.width / bitmap.height);
  }

  static void _footer(
    PdfGraphics graphics,
    _SamplePdfFonts fonts,
    ui.Size size,
    int page,
    int totalPages,
  ) {
    graphics.drawLine(
      PdfPen(_border, width: 0.6),
      ui.Offset(28, size.height - 31),
      ui.Offset(size.width - 28, size.height - 31),
    );
    _text(
      graphics,
      'DTCGroup · Our Solution, Your Success',
      fonts.regular(7.5),
      ui.Rect.fromLTWH(28, size.height - 24, size.width - 80, 11),
      color: _muted,
    );
    _text(
      graphics,
      '$page / $totalPages',
      fonts.bold(7.5),
      ui.Rect.fromLTWH(size.width - 70, size.height - 24, 42, 11),
      color: _muted,
      align: PdfTextAlignment.right,
    );
  }

  static void _text(
    PdfGraphics graphics,
    String value,
    PdfFont font,
    ui.Rect bounds, {
    required PdfColor color,
    PdfTextAlignment align = PdfTextAlignment.left,
  }) {
    graphics.drawString(
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

  static void _drawWatermark(PdfGraphics graphics, _SamplePdfFonts fonts, ui.Size size) {
    final state = graphics.save();
    graphics.setTransparency(0.25);
    graphics.translateTransform(size.width / 2, size.height / 2);
    graphics.rotateTransform(-45);
    final font = fonts.bold(60);
    final watermarkSize = font.measureString('BẢN NHÁP');
    graphics.drawString(
      'BẢN NHÁP',
      font,
      brush: PdfSolidBrush(PdfColor(255, 0, 0)),
      bounds: ui.Rect.fromLTWH(
        -watermarkSize.width / 2,
        -watermarkSize.height / 2,
        watermarkSize.width,
        watermarkSize.height,
      ),
    );
    graphics.restore(state);
  }

  static double _getAdjustedCapacity(SampleStreamData stream, dynamic context) {
    if (stream.type != SampleStreamType.rejected) {
      return stream.capacityTonPerHour;
    }
    
    final List<SampleStreamData> streams = context is SampleRecordData ? context.streams : context as List<SampleStreamData>;
    
    final rawStream = streams.where((s) => s.type == SampleStreamType.rawMaterial).firstOrNull;
    final accStream = streams.where((s) => s.type == SampleStreamType.accepted).firstOrNull;
    
    if (rawStream != null && accStream != null) {
      final rawRounded = double.tryParse(rawStream.capacityTonPerHour.toStringAsFixed(1)) ?? 0;
      final accRounded = double.tryParse(accStream.capacityTonPerHour.toStringAsFixed(1)) ?? 0;
      final rejRounded = rawRounded - accRounded;
      return rejRounded < 0 ? 0 : rejRounded;
    }
    
    return stream.capacityTonPerHour;
  }
}

class _SamplePdfFonts {
  final Uint8List regularBytes;
  final Uint8List boldBytes;

  const _SamplePdfFonts(this.regularBytes, this.boldBytes);

  static Future<_SamplePdfFonts> load() async {
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return _SamplePdfFonts(
      Uint8List.sublistView(regular),
      Uint8List.sublistView(bold),
    );
  }

  PdfFont regular(double size) => PdfTrueTypeFont(regularBytes, size);
  PdfFont bold(double size) => PdfTrueTypeFont(boldBytes, size);
}
