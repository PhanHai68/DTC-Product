import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/fault_record.dart';
import '../utils/fault_duration.dart';

/// Xuất 1 sự cố thành PDF "Hướng dẫn khắc phục lỗi" để kỹ sư chia sẻ cho
/// nhau: mô tả lỗi, nguyên nhân, từng bước xử lý (kèm ảnh bước), ảnh chung,
/// vật tư & thời gian. Cùng phong cách các PDF DTC Product khác (dải xanh,
/// logo, font Roboto có dấu tiếng Việt); nội dung dài tự sang trang.
abstract final class FaultRecordPdfService {
  static final _navy = PdfColor(10, 39, 64);
  static final _green = PdfColor(20, 129, 71);
  static final _muted = PdfColor(96, 119, 134);
  static final _border = PdfColor(211, 225, 229);
  static final _paleBlue = PdfColor(243, 247, 249);

  static const _margin = 32.0;

  /// Lề trên của các trang tiếp theo (trang 1 có header riêng).
  static const _top = 32.0;

  /// Chừa chỗ cho chân trang.
  static const _bottomReserve = 50.0;

  static final _date = DateFormat('dd/MM/yyyy');

  static String fileName(FaultRecord record) {
    final model = record.machineModelName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
        .replaceAll(RegExp(r'\s+'), '');
    return 'KhacPhucLoi_${model}_${DateFormat('yyyyMMdd').format(record.updatedAt)}.pdf';
  }

  /// [photoBytes]: nội dung ảnh theo [FaultAttachment.fileName]; ảnh thiếu
  /// (đã bị xóa khỏi máy) thì bỏ qua.
  static Future<Uint8List> build(
    FaultRecord record, {
    Map<String, Uint8List> photoBytes = const {},
  }) async {
    final fonts = await _Fonts.load();
    final logo = Uint8List.sublistView(
      await rootBundle.load('assets/images/DTCGroup-Slogan.png'),
    );

    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a4
      ..margins.all = 0;

    final w = _Writer(document, fonts);
    _header(w, logo);
    _machineInfo(w, record);

    w.section('MÔ TẢ LỖI');
    w.paragraph(record.symptom);
    w.y += 10;
    for (final photo in record.photos) {
      final bitmap = _bitmap(photoBytes[photo.fileName]);
      if (bitmap != null) _photo(w, bitmap);
    }
    w.y += 4;

    w.section('NGUYÊN NHÂN');
    w.paragraph(record.cause);
    w.y += 14;

    w.section('CÁC BƯỚC KHẮC PHỤC');
    for (final step in record.steps) {
      _step(w, step, photoBytes);
    }
    w.y += 6;

    final extras = [
      if (record.parts != null) ('Vật tư cần thay thế', record.parts!),
      if (record.tools != null) ('Dụng cụ', record.tools!),
      if (record.durationMinutes != null)
        ('Thời gian xử lý', FaultDuration.label(record.durationMinutes!)),
    ];
    if (extras.isNotEmpty) {
      w.section('VẬT TƯ & THỜI GIAN');
      for (final (label, value) in extras) {
        _labelValue(w, label, value);
      }
    }

    final count = document.pages.count;
    for (var i = 0; i < count; i++) {
      _footer(document.pages[i], fonts, record, i + 1, count);
    }

    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }

  // ------------------------------------------------------------- Các khối

  static void _header(_Writer w, Uint8List logo) {
    final g = w.page.graphics;
    final width = w.size.width;
    g.drawRectangle(
      brush: PdfSolidBrush(_green),
      bounds: ui.Rect.fromLTWH(0, 0, width, 8),
    );
    _drawImageContain(
      g,
      PdfBitmap(logo),
      const ui.Rect.fromLTWH(_margin, 22, 130, 40),
    );
    _text(
      g,
      'HƯỚNG DẪN KHẮC PHỤC LỖI',
      w.fonts.bold(16),
      ui.Rect.fromLTWH(180, 24, width - _margin - 180, 22),
      _navy,
      align: PdfTextAlignment.right,
    );
    _text(
      g,
      'NGÂN HÀNG LỖI · DTC PRODUCT',
      w.fonts.regular(9),
      ui.Rect.fromLTWH(180, 48, width - _margin - 180, 14),
      _muted,
      align: PdfTextAlignment.right,
    );
    g.drawLine(
      PdfPen(_border, width: 0.8),
      const ui.Offset(_margin, 76),
      ui.Offset(width - _margin, 76),
    );
    w.y = 90;
  }

  static void _machineInfo(_Writer w, FaultRecord r) {
    final g = w.page.graphics;
    final meta = [
      if (r.serialNumber != null) 'Tagname: ${r.serialNumber}',
      if (r.faultGroup != null) 'Nhóm lỗi: ${r.faultGroup}',
      'Cập nhật: ${_date.format(r.updatedAt)}',
    ].join('   ·   ');
    const boxHeight = 52.0;
    g.drawRectangle(
      brush: PdfSolidBrush(_paleBlue),
      pen: PdfPen(_border, width: 0.6),
      bounds: ui.Rect.fromLTWH(_margin, w.y, w.width, boxHeight),
    );
    _text(
      g,
      'Model máy: ${r.machineModelName}',
      w.fonts.bold(14),
      ui.Rect.fromLTWH(_margin + 12, w.y + 8, w.width - 24, 20),
      _navy,
    );
    _text(
      g,
      meta,
      w.fonts.regular(9.5),
      ui.Rect.fromLTWH(_margin + 12, w.y + 31, w.width - 24, 14),
      _muted,
    );
    w.y += boxHeight + 18;
  }

  static void _step(
    _Writer w,
    SolutionStep step,
    Map<String, Uint8List> photoBytes,
  ) {
    const badge = 20.0;
    const indent = badge + 10;
    final bitmap = _bitmap(photoBytes[step.photo?.fileName]);
    // Bước có ảnh: giữ chữ và ảnh trên cùng 1 trang, không tách rời.
    w.ensure(
      bitmap == null ? 28 : 40 + _fit(bitmap, w.width, _photoMaxHeight).height,
    );
    final g = w.page.graphics;
    g.drawEllipse(
      ui.Rect.fromLTWH(_margin, w.y, badge, badge),
      brush: PdfSolidBrush(_navy),
    );
    _text(
      g,
      '${step.order}',
      w.fonts.bold(10),
      ui.Rect.fromLTWH(_margin, w.y + 4, badge, 12),
      PdfColor(255, 255, 255),
      align: PdfTextAlignment.center,
    );
    w.y += 2;
    w.paragraph(step.content, x: _margin + indent, width: w.width - indent);
    w.y += 8;

    if (bitmap != null) _photo(w, bitmap);
    w.y += 4;
  }

  /// Chiều cao tối đa 1 ảnh — khoảng nửa trang A4 để người đọc nhìn rõ.
  static const _photoMaxHeight = 380.0;

  /// 1 ảnh / 1 hàng, phóng to vừa bề rộng nội dung, căn giữa trang, có
  /// viền mảnh. Không đủ chỗ thì sang trang mới.
  static void _photo(_Writer w, PdfBitmap bitmap) {
    final box = _fit(bitmap, w.width, _photoMaxHeight);
    w.ensure(box.height + 14);
    final rect = ui.Rect.fromLTWH(
      _margin + (w.width - box.width) / 2,
      w.y,
      box.width,
      box.height,
    );
    w.page.graphics
      ..drawImage(bitmap, rect)
      ..drawRectangle(pen: PdfPen(_border, width: 0.8), bounds: rect);
    w.y += box.height + 14;
  }

  static void _labelValue(_Writer w, String label, String value) {
    const labelWidth = 130.0;
    w.ensure(20);
    _text(
      w.page.graphics,
      label,
      w.fonts.regular(10),
      ui.Rect.fromLTWH(_margin, w.y, labelWidth, 14),
      _muted,
    );
    w.paragraph(
      value,
      x: _margin + labelWidth,
      width: w.width - labelWidth,
      bold: true,
    );
    w.y += 6;
  }

  static void _footer(
    PdfPage page,
    _Fonts fonts,
    FaultRecord record,
    int index,
    int count,
  ) {
    final g = page.graphics;
    final size = page.getClientSize();
    final y = size.height - 34;
    g.drawLine(
      PdfPen(_border, width: 0.6),
      ui.Offset(_margin, y),
      ui.Offset(size.width - _margin, y),
    );
    _text(
      g,
      'Người ghi: ${record.authorName}  ·  Chia sẻ từ Ngân hàng lỗi '
      'DTC Product',
      fonts.regular(8),
      ui.Rect.fromLTWH(_margin, y + 7, size.width - _margin * 2 - 60, 12),
      _muted,
    );
    _text(
      g,
      '$index / $count',
      fonts.bold(8),
      ui.Rect.fromLTWH(size.width - _margin - 60, y + 7, 60, 12),
      _muted,
      align: PdfTextAlignment.right,
    );
  }

  // ------------------------------------------------------------ Tiện ích

  static PdfBitmap? _bitmap(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      return PdfBitmap(bytes);
    } catch (_) {
      return null; // Ảnh hỏng — bỏ qua thay vì làm hỏng cả file PDF.
    }
  }

  /// Kích thước vẽ ảnh vừa khung [maxWidth] x [maxHeight], giữ tỉ lệ.
  static ui.Size _fit(PdfBitmap bitmap, double maxWidth, double maxHeight) {
    final aspect = bitmap.width / bitmap.height;
    var width = maxWidth;
    var height = width / aspect;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspect;
    }
    return ui.Size(width, height);
  }

  static void _drawImageContain(
    PdfGraphics graphics,
    PdfBitmap image,
    ui.Rect bounds,
  ) {
    final box = _fit(image, bounds.width, bounds.height);
    graphics.drawImage(
      image,
      ui.Rect.fromLTWH(
        bounds.left + (bounds.width - box.width) / 2,
        bounds.top + (bounds.height - box.height) / 2,
        box.width,
        box.height,
      ),
    );
  }

  static void _text(
    PdfGraphics graphics,
    String value,
    PdfFont font,
    ui.Rect bounds,
    PdfColor color, {
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
}

/// Con trỏ vẽ tuần tự từ trên xuống, tự thêm trang khi hết chỗ.
class _Writer {
  _Writer(this.document, this.fonts) : page = document.pages.add() {
    size = page.getClientSize();
  }

  final PdfDocument document;
  final _Fonts fonts;
  PdfPage page;
  late final ui.Size size;
  double y = FaultRecordPdfService._top;

  double get width => size.width - FaultRecordPdfService._margin * 2;
  double get bottom => size.height - FaultRecordPdfService._bottomReserve;

  /// Sang trang mới nếu không còn đủ [height] điểm.
  void ensure(double height) {
    if (y + height > bottom) {
      page = document.pages.add();
      y = FaultRecordPdfService._top;
    }
  }

  void section(String title) {
    // Tiêu đề không nằm lẻ loi cuối trang.
    ensure(56);
    final g = page.graphics;
    g.drawRectangle(
      brush: PdfSolidBrush(FaultRecordPdfService._green),
      bounds: ui.Rect.fromLTWH(FaultRecordPdfService._margin, y + 1, 4, 15),
    );
    FaultRecordPdfService._text(
      g,
      title,
      fonts.bold(11),
      ui.Rect.fromLTWH(FaultRecordPdfService._margin + 10, y, width - 10, 16),
      FaultRecordPdfService._navy,
    );
    y += 26;
  }

  /// Đoạn văn tự xuống dòng, tràn trang thì vẽ tiếp ở trang sau.
  void paragraph(String text, {double? x, double? width, bool bold = false}) {
    final left = x ?? FaultRecordPdfService._margin;
    final w = width ?? this.width;
    ensure(16);
    final result =
        PdfTextElement(
          text: text,
          font: bold ? fonts.bold(10.5) : fonts.regular(10.5),
          brush: PdfSolidBrush(FaultRecordPdfService._navy),
        ).draw(
          page: page,
          bounds: ui.Rect.fromLTWH(left, y, w, bottom - y),
          format: PdfLayoutFormat(
            layoutType: PdfLayoutType.paginate,
            paginateBounds: ui.Rect.fromLTWH(
              left,
              FaultRecordPdfService._top,
              w,
              bottom - FaultRecordPdfService._top,
            ),
          ),
        )!;
    page = result.page;
    y = result.bounds.bottom + 2;
  }
}

class _Fonts {
  const _Fonts(this.regularBytes, this.boldBytes);

  final Uint8List regularBytes;
  final Uint8List boldBytes;

  static Future<_Fonts> load() async {
    final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    return _Fonts(Uint8List.sublistView(regular), Uint8List.sublistView(bold));
  }

  PdfFont regular(double size) => PdfTrueTypeFont(regularBytes, size);
  PdfFont bold(double size) => PdfTrueTypeFont(boldBytes, size);
}
