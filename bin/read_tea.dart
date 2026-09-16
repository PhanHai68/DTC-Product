import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  final file = "D:\\Flutter_Project\\DTCproduct\\docs\\1 Máy tách màu\\BANG KE CHI TIET DAY CHUYEN  - DF53 PRO.xlsx";
  var bytes = File(file).readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);

  for (var table in excel.tables.keys) {
    print('Sheet: $table');
    for (var row in excel.tables[table]!.rows) {
      if (row.every((element) => element == null)) continue;
      
      final rowData = row.map((cell) => cell?.value?.toString() ?? '').toList();
      print(rowData);
    }
  }
}
