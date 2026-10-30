import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'air_po_excel.dart';

/// Phiếu "Đề nghị vật tư" dạng PDF (A4 dọc): cùng nội dung, cột và màu dòng
/// mục như file Excel theo form PO — thiết bị chính nền vàng, tiêu đề mục
/// xanh dương / xanh lá / vàng, ghi chú chung của mục ở cuối mục, dòng ký
/// tên. Hàm thuần: font và logo truyền vào.
Uint8List buildPoPdf(
  PoDocument doc, {
  required List<String> company,
  required Uint8List regular,
  required Uint8List bold,
  required Uint8List logo,
  String title = 'ĐỀ NGHỊ VẬT TƯ',
}) {
  PdfFont font(double size) => PdfTrueTypeFont(regular, size);
  PdfFont fontBold(double size) => PdfTrueTypeFont(bold, size);
  final navy = PdfColor(10, 39, 64);
  final muted = PdfColor(96, 119, 134);
  final left = PdfStringFormat(lineAlignment: PdfVerticalAlignment.middle);
  final center = PdfStringFormat(
    alignment: PdfTextAlignment.center,
    lineAlignment: PdfVerticalAlignment.middle,
  );
  final right = PdfStringFormat(
    alignment: PdfTextAlignment.right,
    lineAlignment: PdfVerticalAlignment.middle,
  );

  final document = PdfDocument();
  document.pageSettings
    ..size = PdfPageSize.a4
    ..orientation = PdfPageOrientation.portrait
    ..margins.all = 28;
  final page = document.pages.add();
  final g = page.graphics;
  final w = page.getClientSize().width;

  // Đầu trang: logo (tỉ lệ 2048 × 713) trái, tên / địa chỉ / MST công ty phải.
  const logoH = 40.0;
  g.drawImage(
    PdfBitmap(logo),
    ui.Rect.fromLTWH(0, 0, logoH * 2048 / 713, logoH),
  );
  for (final (k, line) in company.indexed) {
    g.drawString(
      line,
      k == 0 ? fontBold(10) : font(9),
      brush: PdfSolidBrush(navy),
      bounds: ui.Rect.fromLTWH(0, k * 13.0, w, 13),
      format: right,
    );
  }
  g.drawString(
    title,
    fontBold(18),
    brush: PdfSolidBrush(navy),
    bounds: ui.Rect.fromLTWH(0, 52, w, 26),
    format: center,
  );
  g.drawString(
    'Tên dự án: ${doc.projectTitle}',
    fontBold(10),
    brush: PdfSolidBrush(navy),
    bounds: ui.Rect.fromLTWH(0, 84, w * 0.72, 16),
    format: left,
  );
  g.drawString(
    'Ngày: ${doc.date}',
    font(10),
    brush: PdfSolidBrush(navy),
    bounds: ui.Rect.fromLTWH(0, 84, w, 16),
    format: right,
  );
  // Thông tin người đề nghị: 3 hàng × 2 cột như đầu form PO.
  final info = doc.requester;
  for (final (k, (label, value)) in [
    ('Người đề nghị', info.requester),
    ('Mã NV', info.employeeId),
    ('Chức vụ', info.position),
    ('Bộ phận', info.department),
    ('Mã dự án', info.projectCode),
    ('Số lần đề nghị/DA', info.requestNo),
  ].indexed) {
    final bounds = ui.Rect.fromLTWH(
      k.isEven ? 0 : w / 2,
      104 + (k ~/ 2) * 15.0,
      w / 2,
      15,
    );
    g.drawString(
      '$label: ',
      fontBold(9.5),
      brush: PdfSolidBrush(navy),
      bounds: bounds,
      format: left,
    );
    g.drawString(
      value,
      font(9.5),
      brush: PdfSolidBrush(navy),
      bounds: bounds.translate(k.isEven ? 92 : 110, 0),
      format: left,
    );
  }

  // Bảng: STT, Mã, Thông tin sản phẩm, ĐVT, SL, Quy cách, Ghi chú.
  final grid = PdfGrid()..repeatHeader = true;
  grid.columns.add(count: 7);
  const fixed = [26.0, 80.0, 0.0, 34.0, 32.0, 100.0, 56.0];
  final nameW = w - fixed.fold(0.0, (a, b) => a + b);
  for (var c = 0; c < 7; c++) {
    grid.columns[c]
      ..width = c == 2 ? nameW : fixed[c]
      ..format = c == 2 || c == 5 || c == 6 ? left : center;
  }
  grid.style = PdfGridStyle(
    font: font(8.5),
    textBrush: PdfSolidBrush(navy),
    cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
  );
  final header = grid.headers.add(1)[0];
  header.style
    ..backgroundBrush = PdfSolidBrush(PdfColor(204, 232, 228))
    ..font = fontBold(8.5);
  for (final (c, h) in [
    'STT',
    'Mã',
    'Thông tin sản phẩm',
    'ĐVT',
    'SL',
    'Diễn giải quy cách / yêu cầu',
    'Ghi chú',
  ].indexed) {
    header.cells[c]
      ..value = h
      ..stringFormat = center;
  }

  String qty(num? v) {
    if (v == null) return '';
    return v == v.roundToDouble()
        ? '${v.round()}'
        : v.toString().replaceAll('.', ',');
  }

  void line(PoLine l, {int? no, PdfColor? fill}) {
    final row = grid.rows.add();
    if (fill != null) {
      row.style = PdfGridRowStyle(backgroundBrush: PdfSolidBrush(fill));
    }
    final values = [
      no == null ? '' : '$no',
      l.code ?? '',
      l.name,
      l.unit,
      qty(l.qty),
      l.spec ?? '',
      l.note ?? '',
    ];
    for (final (c, v) in values.indexed) {
      row.cells[c].value = v;
    }
  }

  void band(String text, PdfColor fill) {
    final row = grid.rows.add();
    row.style = PdfGridRowStyle(
      backgroundBrush: PdfSolidBrush(fill),
      font: fontBold(9),
    );
    row.cells[0]
      ..value = text
      ..columnSpan = 7
      ..stringFormat = center;
  }

  final yellow = PdfColor(255, 255, 0);
  for (final l in doc.equipment) {
    line(l, fill: yellow);
  }
  for (final s in doc.sections) {
    band(s.title, switch (s.band) {
      PoBand.blue => PdfColor(0, 176, 240),
      PoBand.green => PdfColor(146, 208, 80),
      PoBand.yellow => yellow,
    });
    for (final (k, l) in s.lines.indexed) {
      line(l, no: s.numbered ? k + 1 : null);
    }
    if (s.note case final note?) {
      final row = grid.rows.add();
      row.style = PdfGridRowStyle(
        font: font(8),
        textBrush: PdfSolidBrush(muted),
      );
      row.cells[0]
        ..value = 'Ghi chú: $note'
        ..columnSpan = 7
        ..stringFormat = left;
    }
  }
  final result = grid.draw(
    page: page,
    bounds: ui.Rect.fromLTWH(0, 156, w, 0),
    format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate),
  )!;

  // Ký tên dưới bảng (sang trang mới nếu không đủ chỗ).
  var signPage = result.page;
  var signY = result.bounds.bottom + 22;
  if (signY + 20 > signPage.getClientSize().height - 16) {
    signPage = document.pages.add();
    signY = 0;
  }
  for (final (k, who) in [
    'Người đề nghị',
    'Trưởng bộ phận',
    'Giám đốc',
  ].indexed) {
    signPage.graphics.drawString(
      who,
      fontBold(10),
      brush: PdfSolidBrush(navy),
      bounds: ui.Rect.fromLTWH(k * w / 3, signY, w / 3, 16),
      format: center,
    );
  }

  // Số trang.
  final pages = document.pages.count;
  for (var i = 0; i < pages; i++) {
    final p = document.pages[i];
    final size = p.getClientSize();
    p.graphics.drawString(
      'Trang ${i + 1}/$pages',
      font(8),
      brush: PdfSolidBrush(muted),
      bounds: ui.Rect.fromLTWH(0, size.height - 12, size.width, 12),
      format: right,
    );
  }
  final bytes = document.saveSync();
  document.dispose();
  return Uint8List.fromList(bytes);
}
