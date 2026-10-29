// Sinh dữ liệu "Vật tư lắp đặt cụm máy" và mẫu Excel "Đề nghị vật tư" từ các
// file PO trong docs_database/02_May_Nen_Khi/PO:
//   - assets/database/air_compressor/install_kits.json: vật tư theo công suất
//     (mục "VẬT TƯ LẮP ĐẶT BỘ MÁY NÉN KHÍ ...", "VAN XẢ TỰ ĐỘNG ĐÁY BÌNH TÍCH
//     KHÍ", "VẬT TƯ ĐIỆN TẠM TÍNH").
//   - assets/templates/po_vat_tu/: phần cố định của form (style, theme, logo,
//     các dòng tiêu đề 1–12) lấy từ file 30HP, để app ghép thành file xlsx.
//
// Chạy: dart run tool/data/build_install_kits.dart
//
// Đọc thẳng XML trong file xlsx (không dùng package excel) để giữ nguyên
// định dạng ô của form.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

const _dir = 'docs_database/02_May_Nen_Khi/PO';
const _filePrefix = 'DTC - ĐỀ NGHỊ VẬT TƯ LẮP ĐẶT MNK ACOMP TIÊU CHUẨN ';
const _templateHp = 30;
const _output = 'assets/database/air_compressor/install_kits.json';
const _templateDir = 'assets/templates/po_vat_tu';

/// Công suất động cơ (kW) theo mã HP trên tên file — khớp `powerKW` trong
/// specs.json / oil_free_specs.json.
const _kwByHp = {30: 22, 50: 37, 75: 55, 100: 75};

/// Tiêu đề mục trong file (cột B) → khóa JSON.
const _sections = {
  'VẬT TƯ LẮP ĐẶT BỘ MÁY NÉN KHÍ': 'items',
  'VAN XẢ TỰ ĐỘNG ĐÁY BÌNH TÍCH KHÍ': 'drain',
  'VẬT TƯ ĐIỆN TẠM TÍNH': 'electric',
};

/// Cột form: B mã, C tên, J đơn vị, K số lượng, M quy cách (với mục van xả /
/// điện là ghi chú chung của cả mục, ô gộp dọc).
const _colCode = 1, _colName = 2, _colUnit = 9, _colQty = 10, _colSpec = 12;

/// Sửa lỗi gõ trong file nguồn.
const _fixes = {'Van bi đòng': 'Van bi đồng'};

/// Vật tư tiêu hao trong mục tiêu chuẩn (tên sau khi làm sạch): ghi chú
/// "VT tiêu hao", gom xuống cuối danh sách theo thứ tự này.
const _consumables = [
  'Tắc kê nhựa 8 + vít',
  'Keo dán ống nhựa 0.5kg',
  'Cọ sơn 30mm',
  'Đá cắt 100mm',
  'Nhớt máy ren ống',
  'Con lăn sơn 50mm',
  'Sơn bạc (Bạch Tuyết) 0.5Kg',
  'Bao tay len',
  'Giẻ lau',
  'Que hàn 2.5mm',
];
const _consumableNote = 'VT tiêu hao';

/// Vật tư bỏ khỏi mục tiêu chuẩn (tên sau khi làm sạch).
const _removed = ['Bộ dao ren ống 1-2"'];

void main() {
  final kits = <Map<String, Object?>>[];
  for (final hp in _kwByHp.keys) {
    final book = _Book('$_dir/$_filePrefix${hp}HP.xlsx');
    kits.add(_readKit(book, hp));
    if (hp == _templateHp) _writeTemplate(book);
  }
  // Ghi chú mục van xả chỉ có trong một số file: dùng chung cho mọi công suất.
  for (final key in ['drain', 'electric']) {
    final note = kits
        .map((k) => (k[key] as Map)['note'] as String?)
        .firstWhere((n) => n != null && n.isNotEmpty, orElse: () => null);
    for (final kit in kits) {
      final section = kit[key] as Map<String, Object?>;
      if ((section['note'] as String?)?.isNotEmpty != true) {
        section['note'] = note;
      }
    }
  }
  final root = {'source': _dir, 'kits': kits};
  File(
    _output,
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(root)}\n');
  stdout.writeln('Đã ghi $_output: ${kits.length} bộ (${_kwByHp.keys}HP).');
}

Map<String, Object?> _readKit(_Book book, int hp) {
  final sections = <String, Map<String, Object?>>{};
  Map<String, Object?>? current;
  for (final row in book.sheet.findAllElements('row')) {
    final cells = book.rowValues(row);
    final b = _clean(cells[_colCode] ?? '');
    final key = _sections.entries
        .where((e) => b.toUpperCase().startsWith(e.key))
        .map((e) => e.value)
        .firstOrNull;
    if (key != null) {
      current = sections[key] = {'title': b, 'items': <Object>[]};
      continue;
    }
    if (current == null) continue;
    if ((cells[3] ?? '').contains('Người đề nghị')) break;
    final name = _clean(cells[_colName] ?? '');
    final qty = num.tryParse(cells[_colQty] ?? '');
    if (name.isEmpty || qty == null) continue;
    final spec = _clean(cells[_colSpec] ?? '');
    final items = current['items'] as List<Object>;
    if (current != sections['items'] && spec.isNotEmpty) {
      current['note'] = spec;
    }
    items.add({
      if (b.isNotEmpty) 'code': b,
      'name': name,
      'unit': _clean(cells[_colUnit] ?? ''),
      'qty': qty == qty.roundToDouble() ? qty.round() : qty,
      if (current == sections['items'] && spec.isNotEmpty) 'spec': spec,
    });
  }
  for (final key in _sections.values) {
    if (!sections.containsKey(key)) {
      throw StateError('${hp}HP: thiếu mục "$key"');
    }
  }
  // Vật tư tiêu hao: ghi chú và gom xuống cuối.
  final all = (sections['items']!['items'] as List).cast<Map<String, Object>>();
  final consumables = [
    for (final name in _consumables)
      all.firstWhere(
        (i) => i['name'] == name,
        orElse: () => throw StateError('${hp}HP: không thấy "$name"'),
      )..['note'] = _consumableNote,
  ];
  // Ống kẽm: thành ống 3mm → 3.2mm (tên, mã, quy cách).
  final pipes = all.where((i) => (i['name'] as String).startsWith('Ống kẽm'));
  if (pipes.length != 1) throw StateError('${hp}HP: cần đúng 1 dòng ống kẽm');
  for (final pipe in pipes) {
    for (final (key, from, to) in [
      ('name', '*3mm*', '*3.2mm*'),
      ('code', '*3*', '*3.2*'),
      ('spec', '*3mm*', '*3.2mm*'),
    ]) {
      if (pipe[key] case final String v) pipe[key] = v.replaceFirst(from, to);
    }
  }
  for (final name in _removed) {
    if (!all.any((i) => i['name'] == name)) {
      throw StateError('${hp}HP: không thấy "$name" để bỏ');
    }
  }
  final standard = [
    for (final i in all)
      if (!consumables.contains(i) && !_removed.contains(i['name'])) i,
    ...consumables,
  ];
  return {
    'hp': hp,
    'kw': _kwByHp[hp],
    'title': sections['items']!['title'],
    'items': standard,
    'drain': sections['drain'],
    'electric': sections['electric'],
  };
}

/// Phần cố định của form: style (thêm 2 kiểu ô tên vật tư xuống dòng), theme,
/// logo, bản vẽ đặt logo, cột và các dòng 1–12 (chuỗi inline, có chỗ điền
/// `{{DATE}}`, `{{PROJECT}}`).
void _writeTemplate(_Book book) {
  Directory(_templateDir).createSync(recursive: true);
  // Tên vật tư dài: căn trái, xuống dòng (form gốc không xuống dòng).
  var styles = book.part('xl/styles.xml');
  final count = int.parse(
    RegExp(r'<cellXfs count="(\d+)"').firstMatch(styles)!.group(1)!,
  );
  const wrapItem =
      '<xf numFmtId="0" fontId="13" fillId="0" borderId="14" xfId="0" '
      'applyFont="1" applyBorder="1" applyAlignment="1">'
      '<alignment vertical="center" wrapText="1"/></xf>';
  const wrapEquipment =
      '<xf numFmtId="0" fontId="13" fillId="4" borderId="14" xfId="0" '
      'applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
      '<alignment vertical="center" wrapText="1"/></xf>';
  styles = styles
      .replaceFirst('<cellXfs count="$count"', '<cellXfs count="${count + 2}"')
      .replaceFirst('</cellXfs>', '$wrapItem$wrapEquipment</cellXfs>');
  File('$_templateDir/styles.xml').writeAsStringSync(styles);
  File('$_templateDir/theme1.xml')
      .writeAsStringSync(book.part('xl/theme/theme1.xml'));
  File('$_templateDir/drawing1.xml')
      .writeAsStringSync(book.part('xl/drawings/drawing1.xml'));
  File('$_templateDir/logo.png')
      .writeAsBytesSync(book.bytes('xl/media/image1.png'));

  final sheet = book.sheet;
  final cols = sheet
      .findAllElements('col')
      .where((c) => int.parse(c.getAttribute('min')!) <= 24);
  final rows = <String>[];
  for (final row in sheet.findAllElements('row')) {
    final r = int.parse(row.getAttribute('r')!);
    if (r > 12) break;
    final copy = row.copy();
    copy.removeAttribute('spans');
    for (final cell in copy.findElements('c').toList()) {
      final ref = cell.getAttribute('r')!;
      if (ref == 'X10') {
        copy.children.remove(cell);
        continue;
      }
      final value = switch (ref) {
        'M10' => '{{PROJECT}}',
        'N2' => '{{DATE}}',
        _ => cell.getAttribute('t') == 's' ? book.cellValue(cell) : null,
      };
      if (value == null) continue;
      cell
        ..setAttribute('t', 'inlineStr')
        ..children.clear()
        ..children.add(
          XmlElement(XmlName('is'), [], [
            XmlElement(
              XmlName('t'),
              [XmlAttribute(XmlName('space', 'xml'), 'preserve')],
              [XmlText(value)],
            ),
          ]),
        );
    }
    rows.add(copy.toXmlString());
  }
  final merges = [
    for (final m in sheet.findAllElements('mergeCell'))
      if (RegExp(r'^[A-Z]+(\d+):[A-Z]+(\d+)$')
              .firstMatch(m.getAttribute('ref')!)
          case final match? when int.parse(match.group(2)!) <= 12)
        m.getAttribute('ref')!,
  ];
  final head = {
    'source': '$_filePrefix${_templateHp}HP.xlsx',
    'sheetName': 'ĐỀ NGHỊ VẬT TƯ',
    'xfItemName': count,
    'xfEquipmentName': count + 1,
    'cols': '<cols>${cols.map((c) => c.toXmlString()).join()}</cols>',
    'rows': rows.join(),
    'merges': merges,
  };
  File(
    '$_templateDir/head.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(head)}\n');
  stdout.writeln('Đã ghi mẫu Excel vào $_templateDir.');
}

String _clean(String s) {
  var out = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  _fixes.forEach((from, to) => out = out.replaceAll(from, to));
  return out;
}

/// Một file xlsx: phần XML, chuỗi dùng chung, sheet đầu tiên.
class _Book {
  _Book(this.path)
    : _archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync()) {
    final sharedXml = _archive.findFile('xl/sharedStrings.xml');
    _shared = sharedXml == null
        ? const []
        : XmlDocument.parse(part('xl/sharedStrings.xml'))
              .findAllElements('si')
              .map(_text)
              .toList();
    sheet = XmlDocument.parse(part('xl/worksheets/sheet1.xml'));
  }

  final String path;
  final Archive _archive;
  late final List<String> _shared;
  late final XmlDocument sheet;

  List<int> bytes(String name) {
    final file = _archive.findFile(name);
    if (file == null) throw StateError('Thiếu $name trong $path');
    return file.content as List<int>;
  }

  String part(String name) => utf8.decode(bytes(name));

  Map<int, String> rowValues(XmlElement row) => {
    for (final cell in row.findElements('c'))
      _columnIndex(cell.getAttribute('r')!): cellValue(cell).trim(),
  };

  String cellValue(XmlElement cell) {
    switch (cell.getAttribute('t')) {
      case 's':
        return _shared[int.parse(cell.getElement('v')!.innerText)];
      case 'inlineStr':
        final inline = cell.getElement('is');
        return inline == null ? '' : _text(inline);
      case 'e':
        return '';
      default:
        return cell.getElement('v')?.innerText ?? '';
    }
  }
}

int _columnIndex(String ref) {
  var index = 0;
  for (final code in ref.codeUnits) {
    if (code < 65 || code > 90) break;
    index = index * 26 + code - 64;
  }
  return index - 1;
}

/// Ghép mọi `<t>` (kể cả chuỗi nhiều định dạng `<r><t>`), bỏ phần phiên âm.
String _text(XmlElement element) => element
    .findAllElements('t')
    .where((t) => t.parentElement?.name.local != 'rPh')
    .map((t) => t.innerText)
    .join();
