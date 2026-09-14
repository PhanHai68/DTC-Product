import 'dart:io';
import 'package:excel/excel.dart';

void main() async {
  final filePath =
      r'D:\Flutter_Project\DTCproduct\docs\3 Cân đóng gói\DTC_Database_Can_Dong_Goi_Chuan_Hoa_HinhAnh (1).xlsx';

  final bytes = File(filePath).readAsBytesSync();
  final excel = Excel.decodeBytes(bytes);

  print('=== SHEETS ===');
  for (final sheet in excel.sheets.keys) {
    print('Sheet: "$sheet"');
  }

  for (final sheetName in excel.sheets.keys) {
    final sheet = excel.sheets[sheetName]!;
    print('\n=== SHEET: $sheetName ===');
    print('Max rows: ${sheet.maxRows}, Max cols: ${sheet.maxColumns}');

    // Print row 1 (headers)
    if (sheet.rows.isNotEmpty) {
      print('\n--- ROW 1 (Headers) ---');
      final row1 = sheet.rows[0];
      for (int i = 0; i < row1.length; i++) {
        final cell = row1[i];
        if (cell != null && cell.value != null) {
          print('  Col $i: "${cell.value}"');
        }
      }
    }

    // Print first 3 data rows
    print('\n--- SAMPLE DATA (rows 2-4) ---');
    for (int rowIdx = 1; rowIdx < sheet.rows.length && rowIdx < 4; rowIdx++) {
      print('Row ${rowIdx + 1}:');
      final row = sheet.rows[rowIdx];
      for (int i = 0; i < row.length; i++) {
        final cell = row[i];
        if (cell != null && cell.value != null) {
          print('  Col $i: ${cell.value} (type: ${cell.value.runtimeType})');
        }
      }
    }

    // Count non-empty rows
    int nonEmptyRows = 0;
    for (final row in sheet.rows) {
      if (row.any((cell) => cell != null && cell.value != null)) {
        nonEmptyRows++;
      }
    }
    print('\nNon-empty rows: $nonEmptyRows');
  }
}
