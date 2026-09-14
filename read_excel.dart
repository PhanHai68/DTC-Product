import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var file = r"D:\Flutter_Project\DTCproduct\docs\2 Máy nén khí\2.4 Chon_MCCB_Va_Cap_Dien.xlsx";
  var bytes = File(file).readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);

  var sheetName = '1 chọn mccb và tiết diện dây';
  var sheet = excel.tables[sheetName];
  if (sheet == null) {
    print('Sheet not found');
    return;
  }

  int maxRows = sheet.maxRows;
  List<String> entries = [];
  
  for (int r = 1; r < maxRows; r++) { // Skip header row
    var row = sheet.row(r);
    if (row.isEmpty || row[0]?.value == null) continue;
    
    String model = row[0]?.value.toString() ?? '';
    String type = row[1]?.value.toString() ?? '';
    String power = row[2]?.value.toString() ?? '';
    String ratedCurrent = row[3]?.value.toString() ?? '';
    String startingCurrent = row[4]?.value.toString() ?? '';
    String startingNote = row[5]?.value.toString() ?? '';
    String mccbComp = row[6]?.value.toString() ?? '';
    String cableComp = row.length > 7 ? (row[7]?.value.toString() ?? '') : '';
    String mcbDryer = row.length > 8 ? (row[8]?.value.toString() ?? '') : '';
    String cableDryer = row.length > 9 ? (row[9]?.value.toString() ?? '') : '';

    // Some cleanups
    if (mccbComp == 'null') mccbComp = '';
    if (cableComp == 'null') cableComp = '';
    if (mcbDryer == 'null') mcbDryer = '';
    if (cableDryer == 'null') cableDryer = '';

    entries.add('''
  {
    'model': '${model.trim()}',
    'type': '${type.trim()}',
    'power': '${power.trim()}',
    'ratedCurrent': '${ratedCurrent.trim()}',
    'startingCurrent': '${startingCurrent.trim()}',
    'startingNote': '${startingNote.trim()}',
    'mccbComp': '${mccbComp.trim()}',
    'cableComp': '${cableComp.trim()}',
    'mcbDryer': '${mcbDryer.trim()}',
    'cableDryer': '${cableDryer.trim()}'
  }''');
  }

  String fileContent = '''
// This file is auto-generated. Do not edit manually.

const List<Map<String, String>> acompMccbData = [
${entries.join(',\n')}
];
''';

  File(r'D:\Flutter_Project\DTCproduct\lib\data\acomp_mccb_data.dart').writeAsStringSync(fileContent);
  print('Data generated successfully.');
}
