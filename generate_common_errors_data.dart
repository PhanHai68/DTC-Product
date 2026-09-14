import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var file = r"D:\Flutter_Project\DTCproduct\docs\2 Máy nén khí\CAC_LOI_THUONG_GAP_CUA_MNK.xlsx";
  var bytes = File(file).readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);

  // 1. Lỗi_MNK_Thường_gặp
  var sheet1 = excel.tables['Lỗi_MNK_Thường_gặp'];
  List<String> entries1 = [];
  if (sheet1 != null) {
    for (int r = 3; r < sheet1.maxRows; r++) {
      var row = sheet1.row(r);
      if (row.length > 2 && row[1]?.value != null) {
        String error = row[1]?.value.toString().replaceAll('\n', '\\n').replaceAll("'", "\\'") ?? '';
        String solution = row[2]?.value.toString().replaceAll('\n', '\\n').replaceAll("'", "\\'") ?? '';
        if (error.isNotEmpty) {
          entries1.add("    {'error': '$error', 'solution': '$solution'}");
        }
      }
    }
  }

  // 2. Lỗi_MNK_HDSD_BĐK
  var sheet2 = excel.tables['Lỗi_MNK_HDSD_BĐK'];
  List<String> entries2 = [];
  if (sheet2 != null) {
    String currentMainError = '';
    for (int r = 3; r < sheet2.maxRows; r++) {
      var row = sheet2.row(r);
      if (row.length > 3) {
        String mainError = row[1]?.value?.toString().replaceAll('\n', '\\n').replaceAll("'", "\\'") ?? '';
        if (mainError.isNotEmpty) {
          currentMainError = mainError;
        }
        String description = row[2]?.value?.toString().replaceAll('\n', '\\n').replaceAll("'", "\\'") ?? '';
        String solution = row[3]?.value?.toString().replaceAll('\n', '\\n').replaceAll("'", "\\'") ?? '';
        
        if (description.isNotEmpty || solution.isNotEmpty) {
          entries2.add("    {'mainError': '$currentMainError', 'description': '$description', 'solution': '$solution'}");
        }
      }
    }
  }

  // 3. Lỗi_MNK_Hao_Dầu
  var sheet3 = excel.tables['Lỗi_MNK_Hao_Dầu'];
  List<String> entries3 = [];
  if (sheet3 != null) {
    for (int r = 1; r < sheet3.maxRows; r++) {
      var row = sheet3.row(r);
      if (row.length > 3 && row[1]?.value != null) {
        String cause = row[1]?.value.toString().replaceAll('\n', '\\n').replaceAll("'", "\\'") ?? '';
        String explanation = row[2]?.value.toString().replaceAll('\n', '\\n').replaceAll("'", "\\'") ?? '';
        String solution = row[3]?.value.toString().replaceAll('\n', '\\n').replaceAll("'", "\\'") ?? '';
        if (cause.isNotEmpty) {
          entries3.add("    {'cause': '$cause', 'explanation': '$explanation', 'solution': '$solution'}");
        }
      }
    }
  }

  String fileContent = '''
// This file is auto-generated. Do not edit manually.

const List<Map<String, String>> commonErrorsGeneral = [
${entries1.join(',\n')}
];

const List<Map<String, String>> commonErrorsController = [
${entries2.join(',\n')}
];

const List<Map<String, String>> commonErrorsOilLoss = [
${entries3.join(',\n')}
];
''';

  File(r'D:\Flutter_Project\DTCproduct\lib\data\acomp_common_errors_data.dart').writeAsStringSync(fileContent);
  print('Data generated successfully.');
}
