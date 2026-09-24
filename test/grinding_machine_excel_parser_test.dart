import 'dart:io';

import 'package:dtc_product/features/grinding_machine/services/grinding_excel_parser.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_machine_importer.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

const fixture = 'test/fixtures/grinding_machine/ai_ready.xlsx';

void main() {
  test('Workbook thật khớp toàn bộ snapshot JSON; lấy version từ README', () {
    final report = GrindingExcelParser.parse(File(fixture).readAsBytesSync());
    expect(report.canImport, isTrue, reason: report.issues.join('\n'));
    final expected = GrindingMachineImporter.parse(File('assets/database/grinding_machine_seed.json').readAsStringSync());
    expect(report.snapshot!.toJson(), expected.toJson());
    expect(report.snapshot!.databaseVersion, '1.1'); // Update_Log có 2.0.
  });

  test('Workbook hỏng và thiếu sheet bị chặn', () {
    expect(GrindingExcelParser.parse([1, 2, 3]).canImport, isFalse);
    final book = Excel.createExcel();
    final report = GrindingExcelParser.parse(book.encode()!);
    expect(report.canImport, isFalse);
    expect(report.issues.any((i) => i.location == 'README'), isTrue);
  });

  test('Sai số và đơn vị báo đúng dòng/cột Excel', () {
    final book = GrindingExcelParser.decodeWorkbook(File(fixture).readAsBytesSync());
    book['Models'].updateCell(CellIndex.indexByString('G2'), TextCellValue('không phải số'));
    final report = GrindingExcelParser.parse(book.encode()!);
    expect(report.canImport, isFalse);
    expect(report.issues.any((i) => i.location.contains('dòng 2') && i.location.contains('capacityMinKgH')), isTrue);
  });

  test('Công thức trong cột thông số bị chặn, không biến thành null', () {
    final book = GrindingExcelParser.decodeWorkbook(File(fixture).readAsBytesSync());
    book['Models'].updateCell(CellIndex.indexByString('G2'), const FormulaCellValue('40+40'));
    final report = GrindingExcelParser.parse(book.encode()!);
    expect(report.canImport, isFalse);
    expect(report.issues.any((i) => i.message.contains('công thức')), isTrue);
  });
}
