import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var file = r"D:\Flutter_Project\DTCproduct\docs\2 Máy nén khí\CAC_LOI_THUONG_GAP_CUA_MNK.xlsx";
  var bytes = File(file).readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);

  for (var table in excel.tables.keys) {
    print('\n--- Sheet: $table ---');
    var sheet = excel.tables[table];
    if (sheet == null) continue;
    for (int r = 0; r < 5; r++) { // print first 5 rows
      if (r < sheet.maxRows) {
        var row = sheet.row(r);
        print('Row $r: ${row.map((cell) => cell?.value?.toString()).toList()}');
      }
    }
  }
}
