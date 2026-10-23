// Sinh assets/database/dictionary/technical_terms.json từ file Excel
// "4.7 Tu_dien_chuyen_nganh_DTC.xlsx" (docs_database/04_Cong_Cu_Tinh_Toan),
// sheet "Tu dien".
//
// Chạy: dart run tool/data/build_technical_dictionary.dart
//
// Chỉ lấy các cột dữ liệu chung. Cột "Đã thuộc?" và "Ghi chú của bạn" là dữ
// liệu riêng từng người nên app tự lưu trên máy, không đóng gói.
// Đọc thẳng XML trong file xlsx (không dùng package excel) để không phụ
// thuộc định dạng ô, ô gộp hay chuỗi inline do LibreOffice ghi ra.
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

const _input =
    'docs_database/04_Cong_Cu_Tinh_Toan/4.7 Tu_dien_chuyen_nganh_DTC.xlsx';
const _output = 'assets/database/dictionary/technical_terms.json';
const _sheetName = 'Tu dien';

/// Tên cột trong Excel → khóa JSON.
const _columns = {
  'STT': 'id',
  'Thuật ngữ (EN)': 'term',
  'Viết tắt': 'abbreviation',
  'Phiên âm (IPA)': 'ipa',
  'Nghĩa tiếng Việt': 'meaning',
  'Nhóm máy': 'group',
  'Loại': 'type',
  'Giải thích': 'explanation',
  'Câu mẫu (EN)': 'example',
  'Nghĩa câu mẫu': 'exampleMeaning',
  'Từ liên quan': 'related',
  'Tên gọi khác': 'aliases',
};
const _required = ['id', 'term', 'meaning', 'group', 'type'];

/// Thứ tự hiển thị, khớp danh sách chọn trong Excel.
const _groups = [
  'Máy tách màu',
  'Máy nghiền & dây chuyền bột',
  'Máy nén khí',
  'Cân đóng gói & đóng bao',
  'Xay xát lúa gạo',
  'Điện & cơ khí chung',
  'Thương mại & dịch vụ',
];
const _types = [
  'Loại máy',
  'Bộ phận',
  'Thông số',
  'Công nghệ / vận hành',
  'Nguyên liệu / sản phẩm',
  'Điện & điều khiển',
  'Sự cố / bảo trì',
  'Thương mại',
  'Chứng từ & vận chuyển',
  'Dịch vụ kỹ thuật',
];

void main() {
  final archive = ZipDecoder().decodeBytes(File(_input).readAsBytesSync());
  String part(String name) {
    final file = archive.findFile(name);
    if (file == null) throw StateError('Thiếu $name trong $_input');
    return utf8.decode(file.content as List<int>);
  }

  final shared = archive.findFile('xl/sharedStrings.xml') == null
      ? const <String>[]
      : XmlDocument.parse(part('xl/sharedStrings.xml'))
            .findAllElements('si')
            .map(_text)
            .toList();
  final sheetPath = _sheetPath(
    XmlDocument.parse(part('xl/workbook.xml')),
    XmlDocument.parse(part('xl/_rels/workbook.xml.rels')),
  );
  final rows = XmlDocument.parse(part(sheetPath)).findAllElements('row');

  List<String>? header;
  final records = <Map<String, String>>[];
  for (final row in rows) {
    final values = <int, String>{};
    for (final cell in row.findElements('c')) {
      final column = _columnIndex(cell.getAttribute('r')!);
      values[column] = _cellValue(cell, shared).trim();
    }
    final width = values.isEmpty
        ? 0
        : values.keys.reduce((a, b) => a > b ? a : b) + 1;
    final cells = [for (var i = 0; i < width; i++) values[i] ?? ''];
    if (header == null) {
      header = cells;
      continue;
    }
    if (cells.every((value) => value.isEmpty)) continue;
    records.add({
      for (var i = 0; i < header.length; i++)
        ?_columns[header[i]]: i < cells.length ? cells[i] : '',
    });
  }
  if (header == null) throw StateError('Sheet $_sheetName trống');
  final missingColumns = _columns.keys.where((c) => !header!.contains(c));
  if (missingColumns.isNotEmpty) {
    throw StateError('Thiếu cột: ${missingColumns.join(', ')}');
  }

  // Thuật ngữ có dấu phẩy trong tên ("no bag, no fill") không được tách khi
  // đọc cột "Từ liên quan" (ngăn cách bằng dấu phẩy).
  final commaTerms = [
    for (final r in records)
      if (r['term']!.contains(',')) r['term']!,
  ]..sort((a, b) => b.length.compareTo(a.length));

  final ids = <int>{};
  final terms = <Map<String, Object>>[];
  for (final r in records) {
    for (final key in _required) {
      if (r[key]!.isEmpty) {
        throw StateError('STT ${r['id']}: thiếu "$key" (${r['term']})');
      }
    }
    final id = int.tryParse(r['id']!.replaceAll(RegExp(r'\.0$'), ''));
    if (id == null || !ids.add(id)) {
      throw StateError('STT không hợp lệ hoặc trùng: ${r['id']}');
    }
    if (!_groups.contains(r['group'])) {
      throw StateError('STT $id: nhóm máy lạ "${r['group']}"');
    }
    if (!_types.contains(r['type'])) {
      throw StateError('STT $id: loại lạ "${r['type']}"');
    }
    terms.add({
      'id': id,
      for (final key in [
        'term',
        'abbreviation',
        'ipa',
        'meaning',
        'group',
        'type',
        'explanation',
        'example',
        'exampleMeaning',
      ])
        if (r[key]!.isNotEmpty) key: r[key]!,
      if (_splitRelated(r['related']!, commaTerms) case final list
          when list.isNotEmpty)
        'related': list,
      if (_splitList(r['aliases']!, ';') case final list when list.isNotEmpty)
        'aliases': list,
    });
  }

  final root = {
    'source': _input,
    'groups': _groups,
    'types': _types,
    'terms': terms,
  };
  File(_output)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(root)}\n');
  stdout.writeln('Đã ghi $_output: ${terms.length} thuật ngữ.');
}

List<String> _splitList(String value, String separator) => [
  for (final item in value.split(separator))
    if (item.trim().isNotEmpty) item.trim(),
];

List<String> _splitRelated(String value, List<String> commaTerms) {
  const placeholder = '\u0001';
  var text = value;
  for (final term in commaTerms) {
    text = text.replaceAll(term, term.replaceAll(',', placeholder));
  }
  return [
    for (final item in _splitList(text, ','))
      item.replaceAll(placeholder, ','),
  ];
}

String _sheetPath(XmlDocument workbook, XmlDocument rels) {
  final sheet = workbook
      .findAllElements('sheet')
      .firstWhere(
        (s) => s.getAttribute('name') == _sheetName,
        orElse: () => throw StateError('Không có sheet "$_sheetName"'),
      );
  final relId = sheet.attributes
      .firstWhere((a) => a.name.local == 'id' && a.name.prefix == 'r')
      .value;
  final target = rels
      .findAllElements('Relationship')
      .firstWhere((r) => r.getAttribute('Id') == relId)
      .getAttribute('Target')!;
  return target.startsWith('/') ? target.substring(1) : 'xl/$target';
}

/// "L12" → 11.
int _columnIndex(String ref) {
  var index = 0;
  for (final code in ref.codeUnits) {
    if (code < 65 || code > 90) break;
    index = index * 26 + code - 64;
  }
  return index - 1;
}

String _cellValue(XmlElement cell, List<String> shared) {
  switch (cell.getAttribute('t')) {
    case 's':
      return shared[int.parse(cell.getElement('v')!.innerText)];
    case 'inlineStr':
      final inline = cell.getElement('is');
      return inline == null ? '' : _text(inline);
    default:
      return cell.getElement('v')?.innerText ?? '';
  }
}

/// Ghép mọi `<t>` (kể cả chuỗi nhiều định dạng `<r><t>`), bỏ phần phiên âm.
String _text(XmlElement element) => element
    .findAllElements('t')
    .where((t) => t.parentElement?.name.local != 'rPh')
    .map((t) => t.innerText)
    .join();
