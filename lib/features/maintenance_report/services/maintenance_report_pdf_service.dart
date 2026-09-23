import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/maintenance_checklist_task.dart';
import '../models/maintenance_item.dart';
import '../models/maintenance_part.dart';
import '../models/maintenance_photo.dart';
import '../models/maintenance_report.dart';

/// Xuất PDF "Maintenance Service Report" — dùng syncfusion_flutter_pdf theo
/// đúng phong cách các PDF service hiện có trong app (top bar xanh, logo,
/// con dấu Verified DTC Product, footer DTCGroup). Nội dung dài/biến thiên
/// (checklist, phụ tùng, thông số) dùng PdfGrid với
/// `PdfLayoutType.paginate` để tự tràn trang, phần Before/After vẽ tay theo
/// từng trang riêng vì cần hiển thị ảnh lớn cạnh nhau.
abstract final class MaintenanceReportPdfService {
  static final _navy = PdfColor(10, 39, 64);
  static final _green = PdfColor(20, 129, 71);
  static final _muted = PdfColor(96, 119, 134);
  static final _border = PdfColor(211, 225, 229);
  static final _paleGreen = PdfColor(235, 247, 241);
  static final _paleBlue = PdfColor(243, 247, 249);
  static final _orange = PdfColor(234, 88, 12);

  static Future<Uint8List> build({
    required MaintenanceReport report,
    required List<MaintenanceItem> items,
    required List<MaintenancePhoto> photos,
    required List<MaintenanceChecklistTask> checklist,
    required List<MaintenancePart> parts,
    required Map<String, Uint8List> photoBytes,
  }) async {
    final fonts = await _MtPdfFonts.load();
    final logo = Uint8List.sublistView(
      await rootBundle.load('assets/images/DTCGroup-Slogan.png'),
    );
    final stamp = Uint8List.sublistView(
      await rootBundle.load('assets/images/verified_dtc_product_ink.png'),
    );

    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a4
      ..margins.all = 0;

    final completedTasks = checklist.where((task) => task.isChecked).toList();
    _drawOverviewPage(
      document,
      document.pages.add(),
      report,
      parts,
      completedTasks,
      logo,
      fonts,
    );

    for (final item in items) {
      final itemPhotos = photos.where((p) => p.itemId == item.id).toList();
      final before = itemPhotos
          .where((p) => p.kind == MaintenancePhotoKind.before)
          .toList();
      final after = itemPhotos
          .where((p) => p.kind == MaintenancePhotoKind.after)
          .toList();
      _drawItemPages(document, item, before, after, photoBytes, fonts);
    }
    _drawFinalResultPage(document.pages.add(), report, stamp, fonts);

    for (var i = 0; i < document.pages.count; i++) {
      final current = document.pages[i];
      _footer(
        current.graphics,
        current.getClientSize(),
        fonts,
        i + 1,
        document.pages.count,
      );
    }

    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  // ---------------------------------------------------------------------
  // Page 1 — Overview (Customer / Machine / Maintenance Information)
  // ---------------------------------------------------------------------

  static void _drawOverviewPage(
    PdfDocument document,
    PdfPage page,
    MaintenanceReport report,
    List<MaintenancePart> parts,
    List<MaintenanceChecklistTask> completedTasks,
    Uint8List logo,
    _MtPdfFonts fonts,
  ) {
    final graphics = page.graphics;
    var size = page.getClientSize();
    const margin = 28.0;
    final contentWidth = size.width - margin * 2;

    _header(graphics, size, logo, fonts, 'BÁO CÁO TÌNH TRẠNG MÁY');

    var y = 82.0;
    y = _sectionTitle(graphics, fonts, 'THÔNG TIN KHÁCH HÀNG', y, margin, contentWidth);
    y = _keyValueGrid(graphics, fonts, margin, y, contentWidth, [
      ('Khách hàng', report.customerName),
      ('Địa điểm', report.factorySite),
    ]);

    y += 10;
    y = _sectionTitle(graphics, fonts, 'THÔNG TIN MÁY', y, margin, contentWidth);
    y = _keyValueGrid(graphics, fonts, margin, y, contentWidth, [
      ('Model', report.machineModel),
      ('Tagname', report.machineTagName),
      ('Giờ vận hành', report.machineRunningHours),
    ]);

    y += 10;
    y = _sectionTitle(graphics, fonts, 'THÔNG TIN BẢO TRÌ', y, margin, contentWidth);
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    y = _keyValueGrid(graphics, fonts, margin, y, contentWidth, [
      ('Kỹ sư', report.engineerNamesDisplay),
      ('Ngày', dateFormat.format(report.maintenanceDate)),
      (
        'Giờ bắt đầu',
        report.startTime == null ? '—' : timeFormat.format(report.startTime!),
      ),
      (
        'Giờ kết thúc',
        report.endTime == null ? '—' : timeFormat.format(report.endTime!),
      ),
      ('Mã phiên bảo trì', report.sessionId ?? '—'),
      ('Trạng thái', report.status.label),
    ]);

    if (parts.isNotEmpty) {
      y += 10;
      final result = _drawPartsGrid(page, parts, fonts, y, margin, contentWidth)!;
      page = result.page;
      size = page.getClientSize();
      y = result.bounds.bottom + 14;
    }

    if (completedTasks.isNotEmpty) {
      if (y > size.height - 90) {
        page = document.pages.add();
        size = page.getClientSize();
        y = 40;
      } else {
        y += 10;
      }
      _drawChecklistGrid(page, completedTasks, fonts, y, margin, contentWidth);
    }
  }

  /// Bảng "Vật tư thay thế" — đặt ngay dưới Thông tin bảo trì trên trang đầu
  /// thay vì 1 trang riêng (danh sách thường ngắn, tránh để trống cả trang).
  /// Vẫn dùng `PdfLayoutType.paginate` nên nếu danh sách dài, bảng tự tràn
  /// sang các trang tiếp theo bình thường.
  static PdfLayoutResult? _drawPartsGrid(
    PdfPage page,
    List<MaintenancePart> parts,
    _MtPdfFonts fonts,
    double y,
    double margin,
    double contentWidth,
  ) {
    final size = page.getClientSize();
    y = _sectionTitle(page.graphics, fonts, 'VẬT TƯ THAY THẾ', y, margin, contentWidth);

    final grid = PdfGrid();
    grid.columns.add(count: 5);
    grid.columns[0].width = contentWidth * 0.32;
    grid.columns[1].width = contentWidth * 0.20;
    grid.columns[2].width = contentWidth * 0.12;
    grid.columns[3].width = contentWidth * 0.12;
    grid.columns[4].width = contentWidth * 0.24;
    grid.style = PdfGridStyle(
      font: fonts.regular(9),
      textBrush: PdfSolidBrush(_navy),
      cellPadding: PdfPaddings(left: 8, right: 8, top: 6, bottom: 6),
    );
    final header = grid.headers.add(1)[0];
    header.style
      ..backgroundBrush = PdfSolidBrush(_navy)
      ..textBrush = PdfBrushes.white
      ..font = fonts.bold(8.5);
    const headings = ['Tên vật tư', 'Mã vật tư', 'Số lượng', 'Đơn vị', 'Ghi chú'];
    for (var i = 0; i < headings.length; i++) {
      header.cells[i].value = headings[i];
    }
    for (final part in parts) {
      final row = grid.rows.add();
      row.cells[0].value = part.partName;
      row.cells[1].value = part.partNumber.isEmpty ? '—' : part.partNumber;
      row.cells[2].value = part.quantity == part.quantity.roundToDouble()
          ? part.quantity.toInt().toString()
          : part.quantity.toString();
      row.cells[3].value = part.unit;
      row.cells[4].value = part.note;
    }
    return grid.draw(
      page: page,
      bounds: ui.Rect.fromLTWH(margin, y, contentWidth, size.height - y - 40),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );
  }

  // ---------------------------------------------------------------------
  // Maintenance Work (checklist) — bảng tự tràn trang
  // ---------------------------------------------------------------------

  /// Bảng "Công việc đã thực hiện" — đặt ngay dưới "Vật tư thay thế" trên
  /// trang tổng quan (thay vì 1 trang riêng luôn để trống nhiều) trừ khi
  /// không còn đủ chỗ, khi đó [_drawOverviewPage] đã tự thêm trang mới và
  /// truyền [y] = 40 cho hàm này.
  static void _drawChecklistGrid(
    PdfPage page,
    List<MaintenanceChecklistTask> tasks,
    _MtPdfFonts fonts,
    double y,
    double margin,
    double contentWidth,
  ) {
    final size = page.getClientSize();
    y = _sectionTitle(
      page.graphics,
      fonts,
      'CÔNG VIỆC ĐÃ THỰC HIỆN',
      y,
      margin,
      contentWidth,
    );

    final grid = PdfGrid();
    grid.columns.add(count: 1);
    grid.style = PdfGridStyle(
      font: fonts.regular(9.5),
      textBrush: PdfSolidBrush(_navy),
      cellPadding: PdfPaddings(left: 10, right: 10, top: 7, bottom: 7),
    );
    for (final task in tasks) {
      final row = grid.rows.add();
      row.cells[0].value = '✓  ${task.label}';
    }
    grid.draw(
      page: page,
      bounds: ui.Rect.fromLTWH(margin, y, contentWidth, size.height - y - 40),
      format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
    );
  }

  // ---------------------------------------------------------------------
  // Maintenance Items — Before | After (có thể nhiều trang cho 1 hạng mục
  // nếu chụp nhiều hơn 1 ảnh Before/After)
  // ---------------------------------------------------------------------

  /// Vẽ TOÀN BỘ ảnh Before/After của 1 hạng mục (có thể nhiều hơn 1 ảnh mỗi
  /// bên) — ghép theo cặp cùng thứ tự chụp, mỗi cặp 1 khối cỡ lớn. Không ép
  /// buộc gói gọn trong 1 trang: hết chỗ thì tự sang trang mới (tiêu đề lặp
  /// lại kèm "(TIẾP THEO)") thay vì chỉ hiển thị ảnh đầu tiên như trước.
  static void _drawItemPages(
    PdfDocument document,
    MaintenanceItem item,
    List<MaintenancePhoto> beforePhotos,
    List<MaintenancePhoto> afterPhotos,
    Map<String, Uint8List> photoBytes,
    _MtPdfFonts fonts,
  ) {
    const margin = 28.0;
    const gap = 16.0;
    const safeBottom = 800.0;
    const pairHeight = 280.0;

    var page = document.pages.add();
    var y = _drawItemHeader(page, item, fonts, continued: false);

    final pairCount = beforePhotos.length > afterPhotos.length
        ? beforePhotos.length
        : afterPhotos.length;
    final effectivePairCount = pairCount == 0 ? 1 : pairCount;

    for (var i = 0; i < effectivePairCount; i++) {
      if (y + pairHeight > safeBottom) {
        page = document.pages.add();
        y = _drawItemHeader(page, item, fonts, continued: true);
      }
      final size = page.getClientSize();
      final contentWidth = size.width - margin * 2;
      final cardWidth = (contentWidth - gap) / 2;
      final before = i < beforePhotos.length ? beforePhotos[i] : null;
      final after = i < afterPhotos.length ? afterPhotos[i] : null;
      _drawBeforeAfterCard(
        page.graphics,
        fonts,
        'TRƯỚC',
        before,
        photoBytes,
        ui.Rect.fromLTWH(margin, y, cardWidth, pairHeight),
      );
      _drawBeforeAfterCard(
        page.graphics,
        fonts,
        'SAU',
        after,
        photoBytes,
        ui.Rect.fromLTWH(margin + cardWidth + gap, y, cardWidth, pairHeight),
      );
      y += pairHeight + gap;
    }

    final textBlockHeight =
        _estimateParagraphHeight(item.beforeFinding) +
        8 +
        _estimateParagraphHeight(item.actionTaken) +
        8 +
        _estimateParagraphHeight(item.afterResult);
    if (y + textBlockHeight > safeBottom) {
      page = document.pages.add();
      y = _drawItemHeader(page, item, fonts, continued: true);
    }
    final size = page.getClientSize();
    final contentWidth = size.width - margin * 2;
    y = _labelledParagraph(
      page.graphics,
      fonts,
      'Ghi nhận',
      item.beforeFinding,
      margin,
      y,
      contentWidth,
    );
    y = _labelledParagraph(
      page.graphics,
      fonts,
      'Đã xử lý',
      item.actionTaken,
      margin,
      y + 8,
      contentWidth,
    );
    _labelledParagraph(
      page.graphics,
      fonts,
      'Kết quả',
      item.afterResult,
      margin,
      y + 8,
      contentWidth,
    );
  }

  /// Vẽ thanh tiêu đề đầu trang cho 1 hạng mục — [continued] = true khi đây
  /// là trang nối tiếp của cùng 1 hạng mục (chỉ lặp lại tên, không lặp lại
  /// dòng Trạng thái). Trả về y kế tiếp để bắt đầu vẽ nội dung.
  static double _drawItemHeader(
    PdfPage page,
    MaintenanceItem item,
    _MtPdfFonts fonts, {
    required bool continued,
  }) {
    final graphics = page.graphics;
    final size = page.getClientSize();
    const margin = 28.0;
    final contentWidth = size.width - margin * 2;
    graphics.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(0, 0, size.width, 7),
    );
    _text(
      graphics,
      continued
          ? '${item.name.toUpperCase()} (TIẾP THEO)'
          : item.name.toUpperCase(),
      fonts.bold(15),
      ui.Rect.fromLTWH(margin, 24, contentWidth, 24),
      color: _navy,
    );
    if (continued) return 58.0;
    _text(
      graphics,
      'Trạng thái: ${item.status.label}',
      fonts.regular(9.5),
      ui.Rect.fromLTWH(margin, 50, contentWidth, 16),
      color: _muted,
    );
    return 76.0;
  }

  /// Ước lượng chiều cao (label + nội dung) mà [_labelledParagraph] sẽ chiếm,
  /// dùng để quyết định có cần sang trang mới trước khi vẽ hay không.
  static double _estimateParagraphHeight(String value) {
    final lineCount = (value.trim().length / 95).ceil().clamp(1, 6);
    return 15 + 16.0 * lineCount;
  }

  static void _drawBeforeAfterCard(
    PdfGraphics graphics,
    _MtPdfFonts fonts,
    String label,
    MaintenancePhoto? photo,
    Map<String, Uint8List> photoBytes,
    ui.Rect bounds,
  ) {
    graphics.drawRectangle(
      pen: PdfPen(_border, width: 0.8),
      brush: PdfSolidBrush(_paleBlue),
      bounds: bounds,
    );
    _text(
      graphics,
      label,
      fonts.bold(10),
      ui.Rect.fromLTWH(bounds.left + 10, bounds.top + 8, bounds.width - 20, 16),
      color: _navy,
    );
    final photoArea = ui.Rect.fromLTWH(
      bounds.left + 10,
      bounds.top + 28,
      bounds.width - 20,
      bounds.height - 66,
    );
    final bytes = photo == null ? null : photoBytes[photo.id];
    if (bytes != null) {
      final bitmap = PdfBitmap(bytes);
      _drawImageContain(
        graphics,
        bitmap,
        photoArea,
        bitmap.width / bitmap.height,
      );
    } else {
      graphics.drawRectangle(
        pen: PdfPen(_border, width: 0.6),
        bounds: photoArea,
      );
      _text(
        graphics,
        'Chưa có ảnh',
        fonts.regular(9),
        photoArea,
        color: _muted,
        align: PdfTextAlignment.center,
      );
    }
    final captionY = bounds.top + bounds.height - 34;
    if (photo != null) {
      _text(
        graphics,
        DateFormat('HH:mm').format(photo.capturedAt),
        fonts.regular(8.5),
        ui.Rect.fromLTWH(bounds.left + 10, captionY, bounds.width - 20, 14),
        color: _muted,
      );
      _text(
        graphics,
        photo.verified ? '✓ Đã xác thực' : '⚠ Ảnh không toàn vẹn',
        fonts.bold(8.5),
        ui.Rect.fromLTWH(bounds.left + 10, captionY + 15, bounds.width - 20, 14),
        color: photo.verified ? _green : _orange,
      );
    }
  }

  // ---------------------------------------------------------------------
  // Final Result + Recommendation + Photo Verification
  // ---------------------------------------------------------------------

  static void _drawFinalResultPage(
    PdfPage page,
    MaintenanceReport report,
    Uint8List stamp,
    _MtPdfFonts fonts,
  ) {
    final graphics = page.graphics;
    final size = page.getClientSize();
    const margin = 28.0;
    final contentWidth = size.width - margin * 2;

    var y = _sectionTitle(graphics, fonts, 'KẾT QUẢ CUỐI CÙNG', 40, margin, contentWidth);
    graphics.drawRectangle(
      brush: PdfSolidBrush(_paleGreen),
      pen: PdfPen(_border, width: 0.7),
      bounds: ui.Rect.fromLTWH(margin, y, contentWidth, 26),
    );
    _text(
      graphics,
      report.overallResult?.label ?? 'Chưa xác định',
      fonts.bold(11),
      ui.Rect.fromLTWH(margin + 12, y + 4, contentWidth - 24, 18),
      color: _navy,
    );
    y += 36;
    y = _labelledParagraph(
      graphics,
      fonts,
      'Tình trạng máy sau bảo trì',
      report.machineCondition,
      margin,
      y,
      contentWidth,
    );
    y = _labelledParagraph(
      graphics,
      fonts,
      'Nhận xét',
      report.finalComment,
      margin,
      y + 8,
      contentWidth,
    );
    y = _labelledParagraph(
      graphics,
      fonts,
      'Đề xuất',
      report.recommendation,
      margin,
      y + 8,
      contentWidth,
    );
    final nextParts = <String>[];
    if (report.nextMaintenanceDate != null) {
      nextParts.add(DateFormat('dd/MM/yyyy').format(report.nextMaintenanceDate!));
    }
    if (report.nextMaintenanceRunningHours.trim().isNotEmpty) {
      nextParts.add('${report.nextMaintenanceRunningHours} giờ vận hành');
    }
    y = _labelledParagraph(
      graphics,
      fonts,
      'Bảo trì tiếp theo',
      nextParts.isEmpty ? '—' : nextParts.join(' / '),
      margin,
      y + 8,
      contentWidth,
    );

    y += 16;
    y = _sectionTitle(graphics, fonts, 'XÁC MINH HÌNH ẢNH', y, margin, contentWidth);
    final lines = [
      if (report.sessionId != null) 'Phiên bảo trì: ${report.sessionId}',
      if (report.startTime != null)
        'Bắt đầu bảo trì: ${DateFormat('dd/MM/yyyy HH:mm').format(report.startTime!)}',
      if (report.endTime != null)
        'Hoàn tất bảo trì: ${DateFormat('dd/MM/yyyy HH:mm').format(report.endTime!)}',
    ];
    for (final line in lines) {
      _text(
        graphics,
        line,
        fonts.regular(9.5),
        ui.Rect.fromLTWH(margin, y, contentWidth - 90, 16),
        color: _navy,
      );
      y += 17;
    }
    _drawImageContain(
      graphics,
      PdfBitmap(stamp),
      ui.Rect.fromLTWH(size.width - margin - 70, y - lines.length * 17, 62, 54),
      PdfBitmap(stamp).width / PdfBitmap(stamp).height,
    );
  }

  // ---------------------------------------------------------------------
  // Shared drawing helpers
  // ---------------------------------------------------------------------

  static void _header(
    PdfGraphics graphics,
    ui.Size size,
    Uint8List logo,
    _MtPdfFonts fonts,
    String title,
  ) {
    const margin = 28.0;
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
      title,
      fonts.bold(15),
      ui.Rect.fromLTWH(190, 26, size.width - 218, 24),
      color: _navy,
      align: PdfTextAlignment.right,
    );
    graphics.drawLine(
      PdfPen(_border, width: 0.8),
      const ui.Offset(margin, 70),
      ui.Offset(size.width - margin, 70),
    );
  }

  static double _sectionTitle(
    PdfGraphics graphics,
    _MtPdfFonts fonts,
    String title,
    double y,
    double x,
    double width,
  ) {
    graphics.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(x, y, 4, 16),
    );
    _text(
      graphics,
      title,
      fonts.bold(10.5),
      ui.Rect.fromLTWH(x + 10, y - 1, width - 10, 16),
      color: _navy,
    );
    return y + 24;
  }

  /// Vẽ danh sách (label, value) 2 cột — nhãn và giá trị nằm CÙNG 1 hàng
  /// (không tách 2 dòng), giá trị dùng cùng font thường (không in đậm) để
  /// đồng nhất với các đoạn văn bản khác trong báo cáo.
  static double _keyValueGrid(
    PdfGraphics graphics,
    _MtPdfFonts fonts,
    double x,
    double y,
    double width,
    List<(String, String)> pairs,
  ) {
    const rowHeight = 18.0;
    const columnWidth = 0.5;
    const labelWidth = 96.0;
    for (var i = 0; i < pairs.length; i++) {
      final column = i % 2;
      final row = i ~/ 2;
      final columnX = x + column * width * columnWidth;
      final rowY = y + row * rowHeight;
      final (label, value) = pairs[i];
      _text(
        graphics,
        label,
        fonts.regular(8.5),
        ui.Rect.fromLTWH(columnX, rowY, labelWidth, 16),
        color: _muted,
      );
      _text(
        graphics,
        value.trim().isEmpty ? '—' : value,
        fonts.regular(9.5),
        ui.Rect.fromLTWH(
          columnX + labelWidth,
          rowY,
          width * columnWidth - labelWidth - 10,
          16,
        ),
        color: _navy,
      );
    }
    final rows = (pairs.length / 2).ceil();
    return y + rows * rowHeight + 6;
  }

  static double _labelledParagraph(
    PdfGraphics graphics,
    _MtPdfFonts fonts,
    String label,
    String value,
    double x,
    double y,
    double width,
  ) {
    _text(
      graphics,
      label,
      fonts.bold(9),
      ui.Rect.fromLTWH(x, y, width, 14),
      color: _muted,
    );
    final displayValue = value.trim().isEmpty ? '—' : value.trim();
    final lineCount = (displayValue.length / 95).ceil().clamp(1, 6);
    final height = 16.0 * lineCount;
    _text(
      graphics,
      displayValue,
      fonts.regular(9.5),
      ui.Rect.fromLTWH(x, y + 15, width, height),
      color: _navy,
    );
    return y + 15 + height;
  }

  static void _footer(
    PdfGraphics graphics,
    ui.Size size,
    _MtPdfFonts fonts,
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
      'CSKH: 0832 66 67 68',
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
        lineAlignment: PdfVerticalAlignment.top,
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

class _MtPdfFonts {
  final Uint8List regularBytes;
  final Uint8List boldBytes;

  const _MtPdfFonts(this.regularBytes, this.boldBytes);

  static Future<_MtPdfFonts> load() async {
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return _MtPdfFonts(
      Uint8List.sublistView(regular),
      Uint8List.sublistView(bold),
    );
  }

  PdfFont regular(double size) => PdfTrueTypeFont(regularBytes, size);
  PdfFont bold(double size) => PdfTrueTypeFont(boldBytes, size);
}
