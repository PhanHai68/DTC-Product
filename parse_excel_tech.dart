import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var bytes = File('D:/Flutter_Project/DTCproduct/docs/1 Máy tách màu/1.1 Thong_So_MayTachMauSC.xlsx').readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);
  for (var table in excel.tables.keys) {
    print('--- Sheet: $table ---');
    for (var row in excel.tables[table]!.rows) {
      var rowStr = row.map((e) => e?.value?.toString() ?? 'null').join(' | ');
      print(rowStr);
    }
  }
}
