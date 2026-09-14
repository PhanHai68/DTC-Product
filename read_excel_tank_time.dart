import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var file = r"D:\Flutter_Project\DTCproduct\docs\2 Máy nén khí\Tính thời gian nạp đầy bình.xlsx";
  var bytes = File(file).readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);

  for (var table in excel.tables.keys) {
    print('Sheet: $table');
    var sheet = excel.tables[table];
    if (sheet == null) continue;
    for (int r = 0; r < 20; r++) {
      var row = sheet.row(r);
      print('Row $r: ${row.map((cell) => cell?.value?.toString()).toList()}');
    }
  }
}
