import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models/grinding_import_report.dart';
import 'grinding_database_validator.dart';

abstract final class GrindingExcelParser {
  static GrindingImportReport parse(List<int> bytes) {
    try {
      return _parse(decodeWorkbook(bytes));
    } catch (_) {
      return GrindingImportReport(
        issues: const [
          GrindingImportIssue(
            'Excel',
            'Không đọc được workbook. Hãy chọn file .xlsx hợp lệ, không khóa mật khẩu.',
          ),
        ],
      );
    }
  }

  static const _mainNs =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

  /// Một số công cụ xuất workbook gắn prefix (vd. `x:`) cho namespace
  /// spreadsheetml chính thay vì để mặc định không-prefix. `package:excel`
  /// 4.x tra phần tử bằng `findAllElements('sheet'|'row'|'c'|...)` không xét
  /// namespace, nên gặp file dạng này sẽ không tìm thấy sheet/row/cell nào
  /// (báo "Corrupted Excel file."). Bỏ prefix đó trong bản sao RAM (không
  /// đổi giá trị ô) để `package:excel` đọc được đúng cấu trúc.
  static String _stripMainNamespacePrefix(String xml) {
    if (!xml.contains(_mainNs)) return xml;
    final doc = XmlDocument.parse(xml);
    String? prefix;
    for (final element in doc.descendants.whereType<XmlElement>()) {
      for (final attribute in element.attributes) {
        if (attribute.name.prefix == 'xmlns' && attribute.value == _mainNs) {
          prefix = attribute.name.local;
        }
      }
    }
    if (prefix == null) return xml;
    return xml
        .replaceAll('<$prefix:', '<')
        .replaceAll('</$prefix:', '</')
        .replaceAll(' xmlns:$prefix="$_mainNs"', ' xmlns="$_mainNs"');
  }

  /// excel 4.x ghép 'xl/' vào Target ngay cả khi Target đã là '/xl/...'.
  static String _fixAbsoluteRelationshipTargets(String xml) {
    final doc = XmlDocument.parse(xml);
    for (final relation in doc.descendants.whereType<XmlElement>()) {
      if (relation.name.local != 'Relationship') continue;
      final target = relation.getAttribute('Target');
      if (target != null && target.startsWith('/xl/')) {
        relation.setAttribute('Target', target.substring(4));
      }
    }
    return doc.toXmlString();
  }

  static final _worksheetFile = RegExp(r'^xl/worksheets/sheet\d+\.xml$');

  /// `t="str"` đúng nghĩa OOXML là kết quả (dạng text) của một công thức,
  /// nhưng một số công cụ xuất workbook lại gắn nó cho text thường — kể cả ô
  /// rỗng hợp lệ (đúng rule "không suy đoán dữ liệu" của module này). Do
  /// `package:excel` 4.x luôn coi `t="str"` là công thức và đọc `<v>` bằng
  /// `.first` không kiểm tra rỗng, một ô `t="str"` không có `<v>` (ô rỗng)
  /// làm nó crash cứng thay vì trả về giá trị null. Viết lại các cell này
  /// trực tiếp trên XML — có `<v>` thì chuyển thành `inlineStr` (giữ nguyên
  /// text gốc), không có `<v>` thì bỏ hẳn `t` để `package:excel` đọc thành ô
  /// rỗng — trước khi đưa cho `package:excel`, không đụng ô nào khác.
  static String _normalizeStrCells(String xml) {
    if (!xml.contains('t="str"')) return xml;
    final doc = XmlDocument.parse(xml);
    final cells = doc.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'c' && e.getAttribute('t') == 'str')
        .toList();
    for (final cell in cells) {
      final values = cell.children
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'v')
          .toList();
      if (values.isEmpty) {
        cell.removeAttribute('t');
        continue;
      }
      final text = values.first.innerText;
      for (final v in values) {
        v.remove();
      }
      cell.setAttribute('t', 'inlineStr');
      cell.children.add(
        XmlElement(XmlName('is'), [], [
          XmlElement(XmlName('t'), [], [XmlText(text)]),
        ]),
      );
    }
    return doc.toXmlString();
  }

  /// Chỉ chuẩn hóa cấu trúc XML trong bản sao RAM, giữ nguyên mọi giá trị ô.
  static Excel decodeWorkbook(List<int> bytes) {
    final source = ZipDecoder().decodeBytes(bytes);
    final normalized = Archive();
    for (final file in source.files) {
      if (!file.name.endsWith('.xml') && !file.name.endsWith('.rels')) {
        normalized.addFile(file);
        continue;
      }
      var content = _stripMainNamespacePrefix(
        utf8.decode(file.content as List<int>),
      );
      if (file.name == 'xl/_rels/workbook.xml.rels') {
        content = _fixAbsoluteRelationshipTargets(content);
      } else if (_worksheetFile.hasMatch(file.name)) {
        content = _normalizeStrCells(content);
      }
      final encoded = utf8.encode(content);
      normalized.addFile(ArchiveFile(file.name, encoded.length, encoded));
    }
    return Excel.decodeBytes(ZipEncoder().encode(normalized)!);
  }

  static GrindingImportReport _parse(Excel book) {
    final issues = <GrindingImportIssue>[];
    Object? read(Data? cell, String at, {bool text = false}) {
      final value = cell?.value;
      final Object? raw = switch (value) {
        null => null,
        TextCellValue() => value.value.toString().trim(),
        IntCellValue() => value.value,
        DoubleCellValue() => value.value,
        BoolCellValue() => value.value,
        _ => null,
      };
      if (value != null && raw == null) {
        issues.add(
          GrindingImportIssue(
            at,
            'Ô phải chứa giá trị trực tiếp; hãy chuyển công thức/ngày giờ thành giá trị trước khi import.',
          ),
        );
      }
      if (raw == null || raw == '') return null;
      return text ? raw.toString() : raw;
    }

    // README là nguồn version chính thức. Update_Log chỉ là lịch sử.
    final root = <String, dynamic>{};
    final readme = book.tables['README'];
    if (readme == null) {
      issues.add(
        const GrindingImportIssue(
          'README',
          'Thiếu sheet chứa Database version.',
        ),
      );
    } else {
      for (final row in readme.rows) {
        if (row.length < 2) continue;
        final label = row[0]?.value?.toString().trim().toLowerCase();
        if (label == 'database version') {
          if (root.containsKey('databaseVersion')) {
            issues.add(
              const GrindingImportIssue(
                'README',
                'Database version xuất hiện nhiều lần.',
              ),
            );
          }
          root['databaseVersion'] = read(
            row[1],
            'README · Database version',
            text: true,
          );
        }
        if (label == 'nguồn dữ liệu' || label == 'source document') {
          root['sourceDocument'] = read(
            row[1],
            'README · Nguồn dữ liệu',
            text: true,
          );
        }
      }
    }
    final rowNumbers = <String, List<int>>{};
    for (final entry in GrindingImportSchema.sheets.entries) {
      final sheet = book.tables[entry.value];
      if (sheet == null || sheet.rows.isEmpty) {
        issues.add(
          GrindingImportIssue(entry.value, 'Thiếu sheet dữ liệu bắt buộc.'),
        );
        continue;
      }
      final rows = sheet.rows;
      final headerIndex = rows.indexWhere(
        (r) => r.any((c) => c?.value != null),
      );
      if (headerIndex < 0) {
        issues.add(GrindingImportIssue(entry.value, 'Thiếu dòng tiêu đề.'));
        continue;
      }
      final headers = <String, int>{};
      for (var c = 0; c < rows[headerIndex].length; c++) {
        final header = rows[headerIndex][c]?.value
            ?.toString()
            .trim()
            .toLowerCase();
        if (header == null || header.isEmpty) continue;
        if (headers.containsKey(header)) {
          issues.add(GrindingImportIssue(entry.value, 'Cột $header bị trùng.'));
        }
        headers[header] = c;
      }
      final fields = GrindingImportSchema.fields[entry.key]!;
      for (final field in fields.entries) {
        if (field.key == 'id') continue;
        final header = GrindingImportSchema.header(field.key);
        if (!headers.containsKey(header)) {
          issues.add(GrindingImportIssue(entry.value, 'Thiếu cột $header.'));
        }
      }
      final records = <Map<String, dynamic>>[];
      final indexes = <int>[];
      for (var r = headerIndex + 1; r < rows.length; r++) {
        final cells = rows[r];
        if (!cells.any(
          (c) => c?.value != null && c!.value.toString().trim().isNotEmpty,
        )) {
          continue;
        }
        final row = <String, dynamic>{};
        for (final field in fields.entries) {
          if (field.key == 'id') continue;
          final c = headers[GrindingImportSchema.header(field.key)];
          if (c == null || c >= cells.length) continue;
          var value = read(
            cells[c],
            '${entry.value} · dòng ${r + 1} · ${field.key}',
            text: field.value == 'text' || field.value == 'id',
          );
          if ((field.value == 'bool' || field.value == 'requiredBool') &&
              value is String) {
            value = switch (value.toLowerCase()) {
              'true' || '1' => true,
              'false' || '0' => false,
              _ => value,
            };
          }
          row[field.key] = value;
        }
        records.add(row);
        indexes.add(r + 1);
      }
      root[entry.key] = records;
      rowNumbers[entry.key] = indexes;
    }
    if (issues.isNotEmpty) return GrindingImportReport(issues: issues);
    return GrindingDatabaseValidator.validate(root, rowNumbers: rowNumbers);
  }
}
