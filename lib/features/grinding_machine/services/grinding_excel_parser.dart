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

  /// excel 4.x ghép 'xl/' vào Target ngay cả khi Target đã là '/xl/...'.
  /// Chỉ chuẩn hóa relationship trong bản sao RAM, giữ nguyên mọi giá trị ô.
  static Excel decodeWorkbook(List<int> bytes) {
    final source = ZipDecoder().decodeBytes(bytes);
    final normalized = Archive();
    for (final file in source.files) {
      if (file.name == 'xl/_rels/workbook.xml.rels') {
        final xml = XmlDocument.parse(utf8.decode(file.content as List<int>));
        for (final relation in xml.descendants.whereType<XmlElement>()) {
          if (relation.name.local != 'Relationship') continue;
          final target = relation.getAttribute('Target');
          if (target != null && target.startsWith('/xl/')) {
            relation.setAttribute('Target', target.substring(4));
          }
        }
        final content = utf8.encode(xml.toXmlString());
        normalized.addFile(ArchiveFile(file.name, content.length, content));
      } else {
        normalized.addFile(file);
      }
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
