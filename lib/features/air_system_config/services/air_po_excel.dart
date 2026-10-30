import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Mẫu form "Đề nghị vật tư" — `assets/templates/po_vat_tu`, sinh từ file PO
/// 30HP bằng `tool/data/build_install_kits.dart`: style, theme, logo và các
/// dòng tiêu đề 1–12 giữ nguyên như file gốc.
class PoTemplate {
  const PoTemplate({
    required this.head,
    required this.styles,
    required this.theme,
    required this.drawing,
    required this.logo,
  });

  static const dir = 'assets/templates/po_vat_tu';

  /// Nạp mẫu qua [read] (trong app: rootBundle; trong test: đọc file).
  static Future<PoTemplate> load(
    Future<Uint8List> Function(String path) read,
  ) async {
    Future<String> text(String name) async =>
        utf8.decode(await read('$dir/$name'));
    return PoTemplate(
      head: jsonDecode(await text('head.json')) as Map<String, dynamic>,
      styles: await text('styles.xml'),
      theme: await text('theme1.xml'),
      drawing: await text('drawing1.xml'),
      logo: await read('$dir/logo.png'),
    );
  }

  /// Tên sheet, cột, dòng 1–12 (chỗ điền `{{DATE}}`, `{{PROJECT}}`), ô gộp
  /// của các dòng đó, chỉ số style thêm cho tên vật tư xuống dòng.
  final Map<String, dynamic> head;
  final String styles;
  final String theme;
  final String drawing;
  final Uint8List logo;

  /// Tên, địa chỉ, MST công ty như đầu form (dùng cho phiếu PDF).
  List<String> get company =>
      (head['company'] as List? ?? const []).cast<String>();
}

/// Màu dòng tiêu đề mục, như form: xanh dương (vật tư lắp đặt), xanh lá (van
/// xả đáy bình), vàng (vật tư điện).
enum PoBand { blue, green, yellow }

/// Một dòng vật tư / thiết bị.
class PoLine {
  const PoLine({
    required this.name,
    this.code,
    this.unit = '',
    this.qty,
    this.spec,
    this.note,
  });
  final String? code;
  final String name;
  final String unit;
  final num? qty;

  /// Cột "Diễn giải quy cách / yêu cầu".
  final String? spec;

  /// Cột "Ghi chú".
  final String? note;
}

class PoSection {
  const PoSection({
    required this.title,
    required this.band,
    required this.lines,
    this.note,
    this.numbered = true,
  });
  final String title;
  final PoBand band;
  final List<PoLine> lines;

  /// Ghi chú chung của mục: ô gộp dọc cột quy cách (như mục van xả, điện).
  final String? note;
  final bool numbered;
}

/// Thông tin người đề nghị ở đầu phiếu (nhập khi xuất file).
class PoRequester {
  const PoRequester({
    this.requester = '',
    this.employeeId = '',
    this.position = '',
    this.department = '',
    this.projectCode = '',
    this.requestNo = '',
  });

  /// Người đề nghị, mã nhân viên, chức vụ, bộ phận.
  final String requester;
  final String employeeId;
  final String position;
  final String department;

  /// Mã dự án ("DTC-…"), số lần đề nghị / dự án ("001").
  final String projectCode;
  final String requestNo;
}

/// Nội dung phiếu: thông tin người đề nghị, dòng "Tên dự án", ngày, thiết bị
/// chính (dòng nền vàng không đánh số), các mục vật tư.
class PoDocument {
  const PoDocument({
    required this.projectTitle,
    required this.date,
    required this.equipment,
    required this.sections,
    this.requester = const PoRequester(),
  });
  final String projectTitle;
  final String date;
  final List<PoLine> equipment;
  final List<PoSection> sections;
  final PoRequester requester;

  PoDocument withRequester(PoRequester info) => PoDocument(
    projectTitle: projectTitle,
    date: date,
    equipment: equipment,
    sections: sections,
    requester: info,
  );

  /// Kiểu gộp mã: giữ thiết bị chính, mọi vật tư gộp vào một mục, mỗi vật tư
  /// một dòng (cộng số lượng). Cùng mã (và ĐVT) là một vật tư; không có mã
  /// thì theo tên + quy cách + ĐVT. Giữ thứ tự xuất hiện đầu tiên, vật tư
  /// tiêu hao xuống cuối. Dòng chỉ là thông báo (không số lượng) bỏ qua.
  PoDocument merged({String title = 'VẬT TƯ LẮP ĐẶT'}) {
    String norm(String? v) =>
        (v ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final byKey = <String, PoLine>{};
    for (final section in sections) {
      for (final l in section.lines) {
        final qty = l.qty;
        if (qty == null) continue;
        final code = l.code?.trim() ?? '';
        final key = code.isNotEmpty
            ? 'c:${norm(code)}|${norm(l.unit)}'
            : 'n:${norm(l.name)}|${norm(l.spec)}|${norm(l.unit)}';
        final old = byKey[key];
        byKey[key] = old == null
            ? l
            : PoLine(
                code: old.code,
                name: old.name,
                unit: old.unit,
                qty: old.qty! + qty,
                spec: old.spec ?? l.spec,
                note: old.note ?? l.note,
              );
      }
    }
    const consumable = 'VT tiêu hao';
    final lines = [
      ...byKey.values.where((l) => l.note != consumable),
      ...byKey.values.where((l) => l.note == consumable),
    ];
    return PoDocument(
      projectTitle: projectTitle,
      date: date,
      equipment: equipment,
      requester: requester,
      sections: [
        if (lines.isNotEmpty)
          PoSection(title: title, band: PoBand.blue, lines: lines),
      ],
    );
  }
}

/// Ghép file xlsx theo form "Đề nghị vật tư".
Uint8List buildPoWorkbook(PoTemplate t, PoDocument doc) {
  final sheet = _PoSheet(t);
  for (final line in doc.equipment) {
    sheet.line(line, equipment: true);
  }
  for (final section in doc.sections) {
    sheet.section(section);
  }
  sheet.footer();

  final sheetName = t.head['sheetName'] as String;
  final quoted = "'${sheetName.replaceAll("'", "''")}'";
  final head = (t.head['rows'] as String)
      .replaceAll('{{DATE}}', _esc(doc.date))
      .replaceAll('{{PROJECT}}', _esc(doc.projectTitle))
      .replaceAll('{{REQUESTER}}', _esc(doc.requester.requester))
      .replaceAll('{{EMPLOYEE_ID}}', _esc(doc.requester.employeeId))
      .replaceAll('{{POSITION}}', _esc(doc.requester.position))
      .replaceAll('{{DEPARTMENT}}', _esc(doc.requester.department))
      .replaceAll('{{PROJECT_CODE}}', _esc(doc.requester.projectCode))
      .replaceAll('{{REQUEST_NO}}', _esc(doc.requester.requestNo));
  final last = sheet.row - 1;
  final merges = [
    ...(t.head['merges'] as List).cast<String>(),
    ...sheet.merges,
  ];

  final sheetXml =
      '$_xmlDecl<worksheet xmlns="$_ns" xmlns:r="$_nsR">'
      '<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>'
      '<dimension ref="A1:O$last"/>'
      '<sheetViews><sheetView showGridLines="0" tabSelected="1" '
      'zoomScale="70" zoomScaleNormal="70" workbookViewId="0"/></sheetViews>'
      '<sheetFormatPr defaultColWidth="9" defaultRowHeight="15.5"/>'
      '${t.head['cols']}'
      '<sheetData>$head${sheet.rows}</sheetData>'
      '<mergeCells count="${merges.length}">'
      '${merges.map((m) => '<mergeCell ref="$m"/>').join()}</mergeCells>'
      '<printOptions horizontalCentered="1"/>'
      '<pageMargins left="0.2" right="0.2" top="0.43" bottom="0.51" '
      'header="0.31" footer="0.31"/>'
      '<pageSetup paperSize="9" orientation="landscape" fitToWidth="1" '
      'fitToHeight="0"/>'
      '<drawing r:id="rId1"/></worksheet>';

  final parts = <String, List<int>>{
    '[Content_Types].xml': utf8.encode(
      '$_xmlDecl<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Default Extension="png" ContentType="image/png"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '<Override PartName="/xl/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>'
      '<Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>'
      '</Types>',
    ),
    '_rels/.rels': utf8.encode(
      _rels({
        'rId1': (
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument',
          'xl/workbook.xml',
        ),
      }),
    ),
    'xl/workbook.xml': utf8.encode(
      '$_xmlDecl<workbook xmlns="$_ns" xmlns:r="$_nsR">'
      '<bookViews><workbookView/></bookViews>'
      '<sheets><sheet name="${_esc(sheetName)}" sheetId="1" r:id="rId1"/></sheets>'
      '<definedNames>'
      '<definedName name="_xlnm.Print_Area" localSheetId="0">${_esc(quoted)}!\$A\$1:\$O\$$last</definedName>'
      '<definedName name="_xlnm.Print_Titles" localSheetId="0">${_esc(quoted)}!\$1:\$11</definedName>'
      '</definedNames></workbook>',
    ),
    'xl/_rels/workbook.xml.rels': utf8.encode(
      _rels({
        'rId1': ('$_relBase/worksheet', 'worksheets/sheet1.xml'),
        'rId2': ('$_relBase/styles', 'styles.xml'),
        'rId3': ('$_relBase/theme', 'theme/theme1.xml'),
      }),
    ),
    'xl/worksheets/sheet1.xml': utf8.encode(sheetXml),
    'xl/worksheets/_rels/sheet1.xml.rels': utf8.encode(
      _rels({'rId1': ('$_relBase/drawing', '../drawings/drawing1.xml')}),
    ),
    'xl/drawings/drawing1.xml': utf8.encode(t.drawing),
    'xl/drawings/_rels/drawing1.xml.rels': utf8.encode(
      _rels({'rId1': ('$_relBase/image', '../media/image1.png')}),
    ),
    'xl/media/image1.png': t.logo,
    'xl/styles.xml': utf8.encode(t.styles),
    'xl/theme/theme1.xml': utf8.encode(t.theme),
  };
  final archive = Archive();
  parts.forEach(
    (name, bytes) => archive.addFile(ArchiveFile(name, bytes.length, bytes)),
  );
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

const _xmlDecl = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
const _ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const _nsR =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _relBase =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

String _rels(Map<String, (String, String)> rels) =>
    '$_xmlDecl<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '${rels.entries.map((e) => '<Relationship Id="${e.key}" Type="${e.value.$1}" Target="${e.value.$2}"/>').join()}'
    '</Relationships>';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

const _cols = 'ABCDEFGHIJKLMNO';

/// Chỉ số style của form gốc (styles.xml) cho từng cột A–O.
const _equipmentStyles = [
  43,
  88,
  0,
  0,
  0,
  0,
  93,
  93,
  93,
  80,
  81,
  81,
  129,
  129,
  129,
];
const _itemStyles = [46, 46, 0, 0, 0, 0, 45, 45, 45, 46, 62, 62, 135, 135, 135];
const _bandStyles = {
  PoBand.blue: (43, 153, 154, 155),
  PoBand.green: (79, 176, 177, 178),
  PoBand.yellow: (94, 187, 188, 189),
};

/// Ô quy cách gộp dọc (đầu, giữa, cuối) × (M, N).
const _noteTop = (190, 191), _noteMid = (192, 193), _noteBottom = (194, 195);

/// Ước lượng số ký tự mỗi dòng (cỡ chữ 13) của tên (C:F), quy cách (M:N),
/// ghi chú (O) để đặt chiều cao dòng.
const _nameChars = 50, _specChars = 28, _noteChars = 15;
const _minHeight = 35.5, _lineHeight = 17.0;

int _lines(String? text, int perLine) =>
    text == null || text.isEmpty ? 1 : (text.length / perLine).ceil();

class _PoSheet {
  _PoSheet(PoTemplate t)
    : _xfName = t.head['xfItemName'] as int,
      _xfEquipment = t.head['xfEquipmentName'] as int;

  final int _xfName;
  final int _xfEquipment;
  final rows = StringBuffer();
  final merges = <String>[];

  /// Dòng kế tiếp (dòng 13–18 của form gốc là dòng ẩn, bỏ qua — bắt đầu 13).
  int row = 13;

  void _row(double height, Map<int, int> styles, Map<int, Object> values) {
    rows.write(
      '<row r="$row" ht="${height.toStringAsFixed(2)}" customHeight="1">',
    );
    for (var c = 0; c < _cols.length; c++) {
      final ref = '${_cols[c]}$row';
      final s = styles[c];
      final v = values[c];
      final style = s == null ? '' : ' s="$s"';
      if (v is num) {
        rows.write('<c r="$ref"$style><v>$v</v></c>');
      } else if (v is String && v.isNotEmpty) {
        rows.write(
          '<c r="$ref"$style t="inlineStr"><is><t xml:space="preserve">'
          '${_esc(v)}</t></is></c>',
        );
      } else if (s != null) {
        rows.write('<c r="$ref"$style/>');
      }
    }
    rows.write('</row>');
    row++;
  }

  double _height(PoLine l, {bool withSpec = true}) => math.max(
    _minHeight,
    6 +
        _lineHeight *
            [
              _lines(l.name, _nameChars),
              if (withSpec) _lines(l.spec, _specChars),
              _lines(l.note, _noteChars),
            ].reduce(math.max),
  );

  void line(
    PoLine l, {
    bool equipment = false,
    int? no,
    (int, int)? noteStyle,
    double? height,
  }) {
    final base = equipment ? _equipmentStyles : _itemStyles;
    final styles = {
      for (var c = 0; c < base.length; c++) c: base[c],
      for (var c = 2; c <= 5; c++) c: equipment ? _xfEquipment : _xfName,
      if (noteStyle != null) 12: noteStyle.$1,
      if (noteStyle != null) 13: noteStyle.$2,
    };
    merges.add('C$row:F$row');
    if (noteStyle == null) merges.add('M$row:N$row');
    _row(height ?? _height(l), styles, {
      0: ?no,
      1: ?l.code,
      2: l.name,
      9: l.unit,
      10: ?l.qty,
      if (noteStyle == null) 12: ?l.spec,
      14: ?l.note,
    });
  }

  void section(PoSection s) {
    // Dải màu từ cột B tới hết cột Ghi chú (O).
    final (a, b, mid, end) = _bandStyles[s.band]!;
    merges.add('B$row:O$row');
    _row(
      _minHeight,
      {0: a, 1: b, for (var c = 2; c <= 13; c++) c: mid, 14: end},
      {1: s.title},
    );

    final note = s.note;
    if (note == null || s.lines.length < 2) {
      for (var k = 0; k < s.lines.length; k++) {
        final l = s.lines[k];
        line(
          note == null
              ? l
              : PoLine(
                  code: l.code,
                  name: l.name,
                  unit: l.unit,
                  qty: l.qty,
                  spec: note,
                  note: l.note,
                ),
          no: s.numbered ? k + 1 : null,
        );
      }
      return;
    }
    // Ghi chú chung: gộp dọc cột quy cách, chia đều chiều cao cho đủ chữ.
    final first = row;
    final heights = [for (final l in s.lines) _height(l, withSpec: false)];
    final need = 6 + _lineHeight * _lines(note, _specChars);
    final total = heights.fold(0.0, (a, b) => a + b);
    final extra = need > total ? (need - total) / heights.length : 0.0;
    for (var k = 0; k < s.lines.length; k++) {
      final style = k == 0
          ? _noteTop
          : k == s.lines.length - 1
          ? _noteBottom
          : _noteMid;
      line(
        s.lines[k],
        no: s.numbered ? k + 1 : null,
        noteStyle: style,
        height: heights[k] + extra,
      );
    }
    merges.add('M$first:N${row - 1}');
    // Chữ ghi chú nằm ở ô đầu của vùng gộp.
    final marker = '<c r="M$first" s="${_noteTop.$1}"/>';
    final text = rows.toString().replaceFirst(
      marker,
      '<c r="M$first" s="${_noteTop.$1}" t="inlineStr"><is>'
      '<t xml:space="preserve">${_esc(note)}</t></is></c>',
    );
    rows
      ..clear()
      ..write(text);
  }

  /// Dòng đóng khung bảng + dòng ký tên, như form gốc.
  void footer() {
    _row(_minHeight, {
      0: 47,
      1: 96,
      2: 97,
      3: 97,
      4: 97,
      5: 98,
      6: 99,
      7: 99,
      8: 99,
      9: 96,
      10: 100,
      11: 95,
      12: 113,
      13: 114,
      14: 67,
    }, const {});
    merges.add('M$row:N$row');
    _row(
      17.5,
      {
        2: 49,
        3: 50,
        4: 51,
        5: 51,
        6: 52,
        7: 52,
        8: 71,
        9: 71,
        10: 52,
        11: 52,
        12: 183,
        13: 183,
      },
      {3: 'Người đề nghị', 8: 'Trưởng bộ phận', 12: 'Giám đốc'},
    );
  }
}
