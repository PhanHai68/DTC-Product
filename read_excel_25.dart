import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var file21 = r"D:\Flutter_Project\DTCproduct\docs\2 Máy nén khí\2.1 Thong_So_Ky_Thuat_May_Nen_Khi.xlsx";
  var file25 = r"D:\Flutter_Project\DTCproduct\docs\2 Máy nén khí\2.5 Tinh_Toan_Ong_Khi_Nen.xlsx";
  
  print('--- File 2.1 ---');
  var bytes21 = File(file21).readAsBytesSync();
  var excel21 = Excel.decodeBytes(bytes21);
  for (var table in excel21.tables.keys) {
    print('Sheet: $table');
    var sheet = excel21.tables[table];
    if (sheet == null) continue;
    for (int r = 0; r < 5; r++) {
      var row = sheet.row(r);
      print('Row $r: ${row.map((cell) => cell?.value?.toString()).toList()}');
    }
  }

  print('\n--- File 2.5 ---');
  var bytes25 = File(file25).readAsBytesSync();
  var excel25 = Excel.decodeBytes(bytes25);
  for (var table in excel25.tables.keys) {
    print('Sheet: $table');
    var sheet = excel25.tables[table];
    if (sheet == null) continue;
    for (int r = 0; r < 25; r++) { // Print more rows to see formulas or constants
      var row = sheet.row(r);
      print('Row $r: ${row.map((cell) => cell?.value?.toString()).toList()}');
    }
  }
}
