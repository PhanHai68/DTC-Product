import 'dart:io';
import 'dart:convert';
import 'package:excel/excel.dart';

void main() {
  var file = "D:/Flutter_Project/DTCproduct/docs/1 Máy tách màu/1.2 Thiet_Bi_Phu_Tro_MTM.xlsx";
  var bytes = File(file).readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);

  Map<String, List<Map<String, String>>> auxEquipSpecsByModel = {};

  for (var table in excel.tables.keys) {
    var sheet = excel.tables[table]!;
    List<Map<String, String>> dataList = [];
    List<String> headers = [];
    
    for (int i = 0; i < sheet.maxRows; i++) {
      var row = sheet.row(i);
      if (i == 0) {
        for (var cell in row) {
          headers.add(cell?.value?.toString().trim() ?? "");
        }
      } else {
        Map<String, String> rowData = {};
        bool hasData = false;
        for (int j = 0; j < headers.length; j++) {
          var header = headers[j];
          if (header.isEmpty) continue;
          var val = (j < row.length ? row[j]?.value?.toString().trim() : "") ?? "";
          rowData[header] = val;
          if (val.isNotEmpty) hasData = true;
        }
        if (hasData) {
          // Bỏ qua dòng nếu Tên thiết bị rỗng
          if (rowData['Tên thiết bị']?.trim().isNotEmpty == true) {
            dataList.add(rowData);
          }
        }
      }
    }
    auxEquipSpecsByModel[table] = dataList;
  }

  String jsonStr = jsonEncode(auxEquipSpecsByModel);
  String dartCode = '''// GENERATED FILE - DO NOT EDIT MANUALLY
// Dữ liệu được trích xuất từ file Excel

const Map<String, List<Map<String, String>>> auxEquipSpecsByModel = $jsonStr;
''';

  File("D:/Flutter_Project/DTCproduct/lib/data/aux_equip_data.dart").writeAsStringSync(dartCode);
  print("Done! Generated lib/data/aux_equip_data.dart");
}
