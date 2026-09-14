import 'dart:io';
import 'package:excel/excel.dart';

void main(List<String> args) {
  if (args.isEmpty) return;
  var file = args[0];
  var bytes = File(file).readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);

  for (var table in excel.tables.keys) {
    print('Sheet: $table');
    var sheet = excel.tables[table]!;
    var maxRows = sheet.maxRows;
    for (int i = 0; i < (maxRows < 100 ? maxRows : 100); i++) {
      var row = sheet.rows[i];
      print(' Row $i: ${row.map((e) => e?.value).toList()}');
    }
    print("---");
  }
}
