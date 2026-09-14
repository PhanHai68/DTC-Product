import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var file21 = r"D:\Flutter_Project\DTCproduct\docs\2 Máy nén khí\2.1 Thong_So_Ky_Thuat_May_Nen_Khi.xlsx";
  var file25 = r"D:\Flutter_Project\DTCproduct\docs\2 Máy nén khí\2.5 Tinh_Toan_Ong_Khi_Nen.xlsx";
  
  // Extract models from 2.1
  var bytes21 = File(file21).readAsBytesSync();
  var excel21 = Excel.decodeBytes(bytes21);
  var sheet21 = excel21.tables['Datasheet AC Series'] ?? excel21.tables.values.first;
  
  List<String> modelEntries = [];
  for (int r = 1; r < sheet21.maxRows; r++) {
    var row = sheet21.row(r);
    if (row.isEmpty || row[0]?.value == null) continue;
    String model = row[0]?.value.toString() ?? '';
    String flow7bar = row[4]?.value.toString() ?? '';
    String flow8bar = row[5]?.value.toString() ?? '';
    if (model.isNotEmpty && (flow7bar.isNotEmpty || flow8bar.isNotEmpty)) {
      modelEntries.add("    {'model': '$model', 'flow7bar': '$flow7bar', 'flow8bar': '$flow8bar'}");
    }
  }

  // Extract pipe standards from 2.5
  var bytes25 = File(file25).readAsBytesSync();
  var excel25 = Excel.decodeBytes(bytes25);
  var sheet25 = excel25.tables.values.first; // First sheet
  
  List<String> pipeEntries = [];
  for (int r = 5; r <= 24; r++) {
    var row = sheet25.row(r);
    if (row.length > 9) {
      String dn = row[6]?.value.toString() ?? '';
      String mm = row[8]?.value.toString() ?? '';
      String phi = row[9]?.value.toString() ?? '';
      if (dn.isNotEmpty && mm.isNotEmpty) {
        pipeEntries.add("    {'dn': '$dn', 'mm': $mm, 'phi': '$phi'}");
      }
    }
  }

  String fileContent = '''
// This file is auto-generated. Do not edit manually.

const List<Map<String, dynamic>> acompModelsFlowData = [
${modelEntries.join(',\n')}
];

const List<Map<String, dynamic>> pipeStandardData = [
${pipeEntries.join(',\n')}
];
''';

  File(r'D:\Flutter_Project\DTCproduct\lib\data\acomp_pipe_data.dart').writeAsStringSync(fileContent);
  print('Data generated successfully.');
}
