import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var file = r"D:\Flutter_Project\DTCproduct\docs\1 Máy tách màu\DTCProduct_Database_May_Tach_Mau_Tra_DF.xlsx";
  var bytes = File(file).readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);
  for (var table in excel.tables.keys) {
    print('Sheet: $table');
    var sheet = excel.tables[table];
    if (sheet == null) continue;
    var rows = sheet.rows;
    if (rows.isEmpty) continue;
    
    // assuming first row is header
    var headers = rows[0].map((cell) => cell?.value?.toString().trim() ?? '').toList();
    
    print('const List<Map<String, String>> teaColorSorterSpecs = [');
    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.isEmpty || row[0]?.value == null) continue;
      print('  {');
      for (int j = 0; j < headers.length; j++) {
        if (j < row.length && headers[j].isNotEmpty) {
          var val = row[j]?.value?.toString().trim() ?? '';
          print('    "${headers[j]}": "$val",');
        }
      }
      print('  },');
    }
    print('];');
  }
}
